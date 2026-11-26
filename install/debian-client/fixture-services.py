#!/usr/bin/python3 -I
"""Exercise reviewed service transitions and reuse of schedules in a private model."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-SERVICE-FIXTURE-1'
PREFIX = 'sasd-service-lab'
MARKER = '.sasd-service-fixture'
LABEL = 'SERVICE'
DIRECTORIES = ()
PROFILES = ('baseline', 'workstation', 'laptop', 'server')
NAMES = ('service-state.json', 'schedule-selection.json')
REUSE = {'aide': 'aide', 'rkhunter': 'rkhunter', 'chkrootkit': 'chkrootkit',
         'logwatch': 'logwatch', 'cups-cleanup': 'cups'}
UNIT = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,120}\.service')
JOB = re.compile(r'[a-z][a-z0-9-]{0,63}')
SOURCE = re.compile(r'(?:cron|timer):[A-Za-z0-9][A-Za-z0-9_.-]{0,120}')
STATE = re.compile(r'[a-z][a-z0-9-]{0,39}')

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('fixture_config', HERE / 'fixture-config.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


def policies(host, profile, tx):
    """Consume the existing profile-specific renderer contract, not a second policy."""
    planner = engine.load('plan-services')
    rows = {}
    for task, allowed in (
        ('0300_Services_Disable_Unneeded', {'REVIEW_DISABLE', 'KEEP_UNCHANGED'}),
        ('0710_Services_Activate_Required', {'REVIEW_ENABLE'}),
    ):
        data = tx.command('/bin/sh', str(HERE / 'tasks' / task),
                          '--hostname=' + host, '--render')
        for package, unit, policy in planner.service_rows(data.decode('ascii'), profile, allowed):
            if unit in rows:
                raise ValueError('conflicting service policy')
            rows[unit] = (package, policy)
    return rows


def checked_list(value, pattern, limit=128):
    if (not isinstance(value, list) or len(value) > limit or
            any(not isinstance(item, str) or not pattern.fullmatch(item) for item in value) or
            len(set(value)) != len(value)):
        raise ValueError('invalid or duplicate list entry')
    return set(value)


def model(value, profile, policy):
    """Apply only explicit synthetic transitions; adopt only existing active schedules."""
    keys = {'installed', 'units', 'actions', 'schedules', 'selection', 'adopt'}
    if not isinstance(value, dict) or set(value) not in (keys, keys | {'cups_maintenance'}):
        raise ValueError('invalid service fixture fields')
    installed = checked_list(value['installed'], re.compile(r'[a-z0-9][a-z0-9+.-]{1,127}'), 256)
    units = value['units']
    actions = value['actions']
    if (not isinstance(units, dict) or len(units) > 128 or
            not isinstance(actions, dict) or len(actions) > 16):
        raise ValueError('invalid service maps')
    for unit, state in units.items():
        if (not UNIT.fullmatch(unit) or not isinstance(state, list) or len(state) != 3 or
                any(not isinstance(item, str) or not STATE.fullmatch(item) for item in state)):
            raise ValueError('invalid modeled unit state')
    desired = dict(units)
    for unit, action in actions.items():
        if unit not in policy or unit not in units:
            raise ValueError('unit outside selected service policy')
        package, rule = policy[unit]
        if (package not in installed or
                (action, rule) not in (('enable', 'REVIEW_ENABLE'), ('disable', 'REVIEW_DISABLE'))):
            raise ValueError('missing package or unauthorized service action')
        load, active, unit_file = units[unit]
        if load != 'loaded' or active not in ('active', 'inactive') or unit_file not in ('enabled', 'disabled'):
            raise ValueError('unsupported or transitional unit state')
        desired[unit] = ['loaded', 'active', 'enabled'] if action == 'enable' else ['loaded', 'inactive', 'disabled']

    schedules = value['schedules']
    if not isinstance(schedules, list) or len(schedules) > 128:
        raise ValueError('invalid schedule list')
    active_sources = {}
    seen = set()
    for row in schedules:
        if (not isinstance(row, list) or len(row) != 3 or
                not isinstance(row[0], str) or not JOB.fullmatch(row[0]) or
                not isinstance(row[1], str) or not SOURCE.fullmatch(row[1]) or type(row[2]) is not bool):
            raise ValueError('invalid schedule row')
        job, source, active = row
        if (job, source) in seen:
            raise ValueError('duplicate schedule record')
        seen.add((job, source))
        if active:
            if job in active_sources:
                raise ValueError('multiple active schedules for one modeled job')
            active_sources[job] = source

    previous = value['selection']
    adopt = checked_list(value['adopt'], JOB, 16)
    if not isinstance(previous, dict) or len(previous) > len(REUSE):
        raise ValueError('invalid previous selection')
    selected = dict(previous)
    cups = value.get('cups_maintenance')
    if ('cups-cleanup' in set(previous) | adopt) != (cups is not None):
        raise ValueError('explicit CUPS maintenance review required')
    if cups is not None:
        if (not isinstance(cups, dict) or set(cups) != {'source','distribution_reviewed','pending_jobs_preserved','retention_reviewed'} or
                not isinstance(cups['source'], str) or not SOURCE.fullmatch(cups['source']) or
                any(cups[k] is not True for k in ('distribution_reviewed','pending_jobs_preserved','retention_reviewed')) or
                profile not in ('workstation','laptop') or desired.get('cups.service') != ['loaded','active','enabled'] or
                active_sources.get('cups-cleanup') != cups['source']):
            raise ValueError('unsupported CUPS maintenance observation')
    for job in set(previous) | adopt:
        if (job not in REUSE or REUSE[job] not in installed or
                (job == 'logwatch' and profile != 'server') or job not in active_sources):
            raise ValueError('schedule not eligible for reuse')
        source = active_sources[job]
        if job in previous and previous[job] != source:
            raise ValueError('previous schedule selection no longer matches')
        if source.startswith('cron:') and ('cron' not in installed or
                desired.get('cron.service') != ['loaded', 'active', 'enabled']):
            raise ValueError('cron service must be modeled active and enabled for reuse')
        selected[job] = source
    # A selection is a record, not a crontab, timer unit or executable command.
    return desired, selected


def prepare(root, host, profile, stages, tx, context):
    data, mode = tx.read_file(root / 'request.json', os.geteuid(), 65536, target=True)
    if mode != 0o600:
        raise ValueError('service request must be private')
    value = json.loads(data, object_pairs_hook=tx.unique_pairs)
    desired, selected = model(value, profile, policies(host, profile, tx))
    original = {name: {'data': tx.encoded(state).hex(), 'mode': 0o644}
                for name, state in zip(NAMES, (value['units'], value['selection']))}
    binding = {'request-sha256': hashlib.sha256(data).hexdigest(),
               'action-count': len(value['actions']), 'adopt-count': len(value['adopt'])}
    return binding, original, dict(zip(NAMES, (tx.encoded(desired), tx.encoded(selected))))


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
