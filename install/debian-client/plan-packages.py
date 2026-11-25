#!/usr/bin/python3 -I
"""Inspect local APT package candidates and optionally simulate both checklist stages."""
import argparse
import hashlib
import json
from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ENV = {'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'LC_ALL': 'C'}
APT = ('-o', 'Dir::Cache::pkgcache=', '-o', 'Dir::Cache::srcpkgcache=')
PACKAGE = re.compile(r'[a-z0-9][a-z0-9+.-]+')
PROFILES = ('all-candidates', 'baseline', 'workstation', 'laptop', 'server')
VERSION = re.compile(r'[0-9][A-Za-z0-9.+:~\-]*')


def candidates(path):
    """Read only explicit candidate rows, rejecting duplicates across stages."""
    lines = path.read_text(encoding='ascii').splitlines()
    if not lines or lines[0] != 'stage\tpolicy\tpackages_as_in_checklist_or_corrected_candidate\tcomment':
        raise ValueError('invalid package policy header')
    stages = {'1': [], '2': []}
    seen = set()
    for line in lines[1:]:
        fields = line.split('\t')
        if len(fields) != 4 or fields[0] not in stages:
            raise ValueError('invalid policy row')
        if fields[1] != 'candidate':
            continue
        for name in fields[2].split():
            if not PACKAGE.fullmatch(name) or name in seen:
                raise ValueError('invalid or duplicate candidate package')
            stages[fields[0]].append(name)
            seen.add(name)
    if not all(stages.values()):
        raise ValueError('missing candidate stage')
    return stages


def select_profile(stages, path, profile):
    """Every candidate must have exactly one explicit classification."""
    lines = path.read_text(encoding='ascii').splitlines()
    if not lines or lines[0] != 'stage\tprofiles\tpackages':
        raise ValueError('invalid profile header')
    selected = {'1': [], '2': []}
    assigned = {}
    for line in lines[1:]:
        fields = line.split('\t')
        if len(fields) != 3 or fields[0] not in stages:
            raise ValueError('invalid profile row')
        stage, labels, names = fields
        labels = labels.split(',')
        if len(set(labels)) != len(labels) or not (labels == ['review'] or set(labels) <= set(PROFILES[1:])):
            raise ValueError('invalid profile labels')
        if not names.split():
            raise ValueError('empty profile row')
        for name in names.split():
            if name not in stages[stage] or name in assigned:
                raise ValueError('unclassified or duplicate package reference')
            assigned[name] = labels
    if set(assigned) != {name for names in stages.values() for name in names}:
        raise ValueError('incomplete profile classification')
    for stage, names in stages.items():
        selected[stage] = [n for n in names if profile == 'all-candidates' or profile in assigned[n]]
    return selected


def inventory_selection(hostname, inventory, roles):
    """Reuse the complete R2 planner; bind exact input bytes and selected profile."""
    with tempfile.TemporaryDirectory(prefix='sasd-package-input.') as tmp:
        copies = {}
        hashes = {}
        for label, source in (('inventory', inventory), ('roles', roles),
                              ('policy', HERE / 'package-policy.tsv'),
                              ('profiles', HERE / 'package-profiles.tsv')):
            source = Path(source)
            if source.is_symlink() or not source.is_file() or source.stat().st_size > 4 * 1024 * 1024:
                raise ValueError('unsafe or oversized package planning input')
            data = source.read_bytes()
            if len(data) > 4 * 1024 * 1024:
                raise ValueError('oversized package planning input')
            copies[label] = Path(tmp) / label
            copies[label].write_bytes(data)
            hashes[label] = hashlib.sha256(data).hexdigest()
        result = command('/usr/bin/perl', str(HERE / 'plan-client.pl'), '--hostname=' + hostname,
                         '--inventory=' + str(copies['inventory']), '--roles=' + str(copies['roles']))
        lines = result.stdout.splitlines()
        if result.returncode or result.stderr.strip() or len(lines) < 4 or lines[0] != 'SASD-CLIENT-PLAN-1':
            raise ValueError('R2 inventory plan rejected')
        row = lines[1].split('\t')
        if len(row) != 7 or row[:2] != ['host', hostname] or row[3] != 'debian' or row[6] not in PROFILES[1:]:
            raise ValueError('no supported Debian package profile for selected host')
        profile = row[6]
        stages = select_profile(candidates(copies['policy']), copies['profiles'], profile)
        context = {'host': row, 'inputs': hashes,
                   'client-plan': hashlib.sha256(result.stdout.encode('utf-8')).hexdigest()}
        return profile, stages, context


def installed_result(output):
    match = re.fullmatch(r'ii \t([^\n]+)\n', output)
    if match and VERSION.fullmatch(match[1]):
        return 'INSTALLED', match[1]
    return 'NOT_HEALTHY_OR_UNKNOWN', '-'


def simulation_actions(output):
    """Extract action names and versions, never source descriptions or raw output."""
    actions = []
    seen = set()
    name = r'[a-z0-9][a-z0-9+.-]+(?::[a-z0-9][a-z0-9-]*)?'
    for line in output.splitlines():
        if not line.startswith(('Inst ', 'Conf ', 'Remv ', 'Purg ')):
            continue
        match = re.fullmatch(r'(Inst|Conf) (' + name + r')(?: \[([^\]]+)\])? \(([^ )]+)(?: [^\n]*)?\)(?: \[\])?', line)
        if match:
            action, package, old, new = match.groups()
        else:
            match = re.fullmatch(r'(Remv|Purg) (' + name + r')(?: \[([^\]]+)\])?', line)
            if not match:
                raise ValueError('unrecognized APT action')
            action, package, old = match.groups()
            new = None
        if any(v is not None and not VERSION.fullmatch(v) for v in (old, new)) or (action, package) in seen:
            raise ValueError('invalid or duplicate APT action')
        seen.add((action, package))
        actions.append((action, package, old or '-', new or '-'))
    return actions


def command(*args):
    return subprocess.run(args, env=ENV, capture_output=True, text=True,
                          encoding='utf-8', errors='replace', timeout=60)


def policy_result(name, output):
    """Parse only the installed/candidate fields; never expose repository URLs."""
    lines = output.splitlines()
    if not lines:
        return 'NO_LOCAL_RECORD', '-', '-'
    if lines[0] != name + ':':
        raise ValueError('unexpected apt-cache package heading')
    values = []
    for field in ('Installed', 'Candidate'):
        hits = [line.strip().split(': ', 1)[1] for line in lines[1:]
                if line.strip().startswith(field + ': ')]
        if len(hits) != 1 or (hits[0] != '(none)' and not VERSION.fullmatch(hits[0])):
            raise ValueError('invalid apt-cache version field')
        values.append('-' if hits[0] == '(none)' else hits[0])
    installed, candidate = values
    if candidate == '-':
        status = 'NO_LOCAL_CANDIDATE'
    elif installed == '-':
        status = 'CANDIDATE'
    elif installed == candidate:
        status = 'INSTALLED_SAME'
    else:
        status = 'VERSION_REVIEW'
    return status, installed, candidate


def simulation_result(output):
    """Check APT summary and explicit actions; upgrades/removals need review."""
    lines = output.splitlines()
    summaries = [re.fullmatch(r'(\d+) upgraded, (\d+) newly installed, (\d+) to remove and (\d+) not upgraded\.', line)
                 for line in lines]
    summaries = [m for m in summaries if m]
    if len(summaries) != 1:
        raise ValueError('missing or ambiguous APT summary')
    upgrades, new, removals, held = map(int, summaries[0].groups())
    installs = sum(line.startswith('Inst ') for line in lines)
    removed = sum(line.startswith(('Remv ', 'Purg ')) for line in lines)
    if installs != upgrades + new or removed != removals:
        raise ValueError('APT actions differ from summary')
    # Inst with an existing version also covers possible downgrade/reinstall.
    changed = any(re.match(r'Inst \S+ \[', line) for line in lines)
    status = 'REVIEW_REQUIRED' if upgrades or removals or changed else 'SIMULATED'
    return status, upgrades, new, removals, held


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--list', action='store_true')
    p.add_argument('--profile', choices=PROFILES)
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key)
    p.add_argument('--expect-plan', help='compare a previously reviewed bound simulation digest')
    p.add_argument('--stage', choices=('1', '2', 'both'), default='both')
    operation = p.add_mutually_exclusive_group()
    operation.add_argument('--simulate', action='store_true')
    operation.add_argument('--verify-installed', action='store_true')
    a = p.parse_args()
    if a.list and (a.simulate or a.verify_installed):
        p.error('list cannot run live checks')
    if a.live and os.geteuid() == 0:
        p.error('run as an ordinary user; never install packages')
    bound = any(v is not None for v in (a.hostname, a.inventory, a.roles))
    if bound and (not all((a.hostname, a.inventory, a.roles)) or a.profile is not None):
        p.error('provide hostname, inventory and roles together, without profile override')
    if a.expect_plan is not None and (not bound or not a.simulate or
                                     not re.fullmatch(r'[0-9a-f]{64}', a.expect_plan)):
        p.error('expected plan requires an inventory-bound simulation and SHA-256 digest')
    context = None
    try:
        if bound:
            a.profile, stages, context = inventory_selection(a.hostname, a.inventory, a.roles)
        else:
            a.profile = a.profile or 'all-candidates'
            stages = select_profile(candidates(HERE / 'package-policy.tsv'), HERE / 'package-profiles.tsv', a.profile)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print('plan-packages: ' + str(exc), file=sys.stderr)
        return 2
    print('SASD-PACKAGE-PLAN-1\nscope\t' + ('PROFILE_ONLY' if a.list else 'LOCAL_APT_READ_ONLY'))
    print('profile\t' + a.profile)
    if context is not None:
        print('inventory-host\t' + a.hostname)
        print('inventory-plan-sha256\t' + context['client-plan'])
        for label, value in sorted(context['inputs'].items()):
            print('input-sha256\t' + label + '\t' + value)
        print('runtime-identity\tNOT_VERIFIED')
    print('task\tpackage\tstatus\tinstalled\tcandidate')
    blocked = False
    pinned = []
    expected_new = set()
    for stage in ('1', '2'):
        if a.stage not in (stage, 'both'):
            continue
        for name in stages[stage]:
            if a.list:
                print('\t'.join(('0200' if stage == '1' else '0730', name, 'SELECTED', '-', '-')))
                continue
            if a.verify_installed:
                try:
                    r = command('/usr/bin/dpkg-query', '-W', '-f=${db:Status-Abbrev}\\t${Version}\\n', name)
                    status, version = installed_result(r.stdout) if not r.returncode and not r.stderr.strip() else ('NOT_HEALTHY_OR_UNKNOWN', '-')
                except (OSError, ValueError, subprocess.SubprocessError):
                    status, version = 'NOT_HEALTHY_OR_UNKNOWN', '-'
                blocked |= status != 'INSTALLED'
                print('\t'.join(('0200' if stage == '1' else '0730', name, status, version, '-')))
                continue
            try:
                r = command('/usr/bin/apt-cache', *APT, 'policy', name)
                if r.returncode or r.stderr.strip():
                    raise ValueError('apt-cache error or warning')
                row = policy_result(name, r.stdout)
            except (OSError, ValueError, subprocess.SubprocessError):
                row = ('UNKNOWN', '-', '-')
            if row[0] not in ('CANDIDATE', 'INSTALLED_SAME'):
                blocked = True
            print('\t'.join(('0200' if stage == '1' else '0730', name, *row)))
            if row[0] in ('CANDIDATE', 'INSTALLED_SAME'):
                pinned.append(name + '=' + row[2])
                if row[0] == 'CANDIDATE':
                    expected_new.add(name)
    if not a.simulate:
        print('simulation\tNOT_RUN')
    elif blocked:
        print('simulation\tBLOCKED\tpackage-candidate-review')
        if a.expect_plan is not None:
            print('plan-reference\tNOT_COMPARED')
    else:
        try:
            r = command('/usr/bin/apt-get', *APT, '--simulate', '--no-install-recommends',
                        '--no-remove', 'install', *pinned)
            if r.returncode or r.stderr.strip():
                raise ValueError('APT simulation failed or warned')
            status, upgraded, new, removed, held = simulation_result(r.stdout)
            actions = simulation_actions(r.stdout)
            # Configuring a package without an accompanying install is not a clean new-install plan.
            versions = dict(item.split('=', 1) for item in pinned)
            requested_actions = [row for row in actions if row[0] == 'Inst' and row[1].split(':')[0] in versions]
            if (not expected_new <= {row[1].split(':')[0] for row in requested_actions} or
                    any(row[3] != versions[row[1].split(':')[0]] for row in requested_actions)):
                raise ValueError('requested packages differ from simulated actions')
            configurations = {row[1]: row[3] for row in actions if row[0] == 'Conf'}
            install_versions = {row[1]: row[3] for row in actions if row[0] == 'Inst'}
            if configurations != install_versions:
                status = 'REVIEW_REQUIRED'
                print('simulation-review\tinstall-configuration-mismatch')
            print('simulation\t%s\tupgraded=%d,new=%d,removed=%d,not-upgraded=%d' %
                  (status, upgraded, new, removed, held))
            for row in actions:
                print('action\t' + '\t'.join(row))
            record = {'profile': a.profile, 'stage': a.stage, 'requested': pinned, 'actions': actions,
                      'summary': [upgraded, new, removed, held], 'status': status}
            if context is not None:
                record.update(format='SASD-BOUND-PACKAGE-PLAN-1', inventory=context)
            plan_digest = hashlib.sha256(json.dumps(record, sort_keys=True, separators=(',', ':')).encode('ascii')).hexdigest()
            print('plan-sha256\t' + plan_digest)
            blocked = status != 'SIMULATED'
            if a.expect_plan is not None:
                matches = not blocked and plan_digest == a.expect_plan
                print('plan-reference\t' + ('MATCH' if matches else 'MISMATCH'))
                blocked |= not matches
        except (OSError, ValueError, subprocess.SubprocessError):
            print('simulation\tUNKNOWN\tAPT-error-or-unrecognized-output')
            if a.expect_plan is not None:
                print('plan-reference\tNOT_COMPARED')
            blocked = True
    print('package-apply\tNOT_AUTHORIZED')
    return 3 if blocked else 0


if __name__ == '__main__':
    sys.exit(main())
