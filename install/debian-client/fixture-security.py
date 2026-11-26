#!/usr/bin/python3 -I
"""Apply narrow security settings and an approved synthetic integrity record."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-SECURITY-FIXTURE-1'
PREFIX = 'sasd-security-lab'
MARKER = '.sasd-security-fixture'
LABEL = 'SECURITY'
DIRECTORIES = ('security', 'security/limits.d', 'sasd-security', 'sasd-security/audit-source')
PROFILES = ('baseline', 'workstation', 'laptop', 'server')
NAMES = ('login.defs', 'security/limits.d/60-sasd-workload.conf',
         'sasd-security/audit-baseline.tsv')

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('fixture_config', HERE / 'fixture-config.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


def text(value):
    if not isinstance(value, str) or len(value) > 65536:
        raise ValueError('invalid fixture text')
    data = value.encode('ascii')
    if any(c < 32 and c not in (9, 10) or c == 127 for c in data):
        raise ValueError('invalid fixture bytes')
    if value and not value.endswith('\n'):
        raise ValueError('fixture text requires final newline')
    return value


def hash_setting(original, choice, planner):
    if choice is None:
        return original
    if (not isinstance(choice, dict) or set(choice) != {'method', 'yescrypt_supported'} or
            choice['method'] != 'YESCRYPT' or choice['yescrypt_supported'] is not True):
        raise ValueError('explicit modeled YESCRYPT support required')
    old = planner.hash_policy(original)
    if old not in ('NOT_EXPLICIT', 'SHA512', 'SHA256', 'YESCRYPT'):
        raise ValueError('existing hash setting requires manual review')
    if old == 'YESCRYPT':
        return original
    if old == 'NOT_EXPLICIT':
        return original + 'ENCRYPT_METHOD YESCRYPT\n'
    return re.sub(r'^([ \t]*ENCRYPT_METHOD[ \t]+)(?:SHA512|SHA256)([ \t]*\n)',
                  r'\g<1>YESCRYPT\g<2>', original, flags=re.M)


def limit_setting(original, choice, passwd, group, planner):
    if choice is None:
        return original
    if not isinstance(choice, dict) or set(choice) != {'user', 'soft_nofile', 'hard_nofile'}:
        raise ValueError('invalid limit selection')
    user, soft, hard = (choice[k] for k in ('user', 'soft_nofile', 'hard_nofile'))
    if (not isinstance(user, str) or not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', user) or
            type(soft) is not int or type(hard) is not int or not 1024 <= soft <= hard <= 65536):
        raise ValueError('unsupported workload or bounds')
    users, groups = planner.accounts(passwd), planner.groups(group)
    summary = planner.summarize(users, groups)
    checks = ('duplicate-user-names', 'duplicate-uids', 'unexpected-uid-zero',
              'passwd-field-review', 'home-path-review', 'shell-path-review',
              'duplicate-group-names', 'duplicate-gids', 'primary-gid-not-local',
              'group-member-not-local')
    if summary['root-uid-zero-count'] != 1 or any(summary[k] for k in checks):
        raise ValueError('account capture requires review')
    matches = [row for row in users if row[0] == user and 1000 <= row[1] < 65534]
    if len(matches) != 1:
        raise ValueError('explicit ordinary local account required')
    # Never infer a global default, group grant or effective PAM/systemd limit.
    desired = ('# SASD reviewed workload candidate; fixture only\n'
               '%s soft nofile %d\n%s hard nofile %d\n' % (user, soft, user, hard))
    if original not in ('', desired):
        raise ValueError('existing managed limit fragment requires review')
    return desired


def model(request, planner, manifest):
    """All inputs are synthetic. A SASD hash manifest is not an AIDE database."""
    fields = {'original', 'passwd', 'group', 'hash', 'limits', 'audit_approval'}
    if not isinstance(request, dict) or set(request) != fields:
        raise ValueError('invalid security request')
    original = request['original']
    if not isinstance(original, dict) or set(original) != set(NAMES):
        raise ValueError('invalid security target set')
    original = {name: text(value) for name, value in original.items()}
    passwd, group = text(request['passwd']), text(request['group'])
    result = dict(original)
    result[NAMES[0]] = hash_setting(original[NAMES[0]], request['hash'], planner)
    result[NAMES[1]] = limit_setting(original[NAMES[1]], request['limits'], passwd, group, planner)
    approved = request['audit_approval']
    if approved is not None:
        if (not isinstance(approved, str) or not re.fullmatch(r'[0-9a-f]{64}', approved) or
                not isinstance(manifest, str) or hashlib.sha256(manifest.encode('ascii')).hexdigest() != approved):
            raise ValueError('independently approved integrity capture digest required')
        if original[NAMES[2]] not in ('', manifest):
            raise ValueError('existing integrity record cannot be replaced')
        result[NAMES[2]] = manifest
    elif manifest is not None:
        raise ValueError('unexpected integrity capture')
    if request['hash'] is None and request['limits'] is None and approved is None:
        raise ValueError('no explicit security operation')
    return {name: text(value).encode('ascii') for name, value in result.items()}


def prepare(root, host, profile, stages, tx, context):
    data, mode = tx.read_file(root / 'request.json', os.geteuid(), 65536, target=True)
    if mode != 0o600:
        raise ValueError('security request must be private')
    request = json.loads(data, object_pairs_hook=tx.unique_pairs)
    if not isinstance(request, dict):
        raise ValueError('invalid security request')
    manifest = None
    if request.get('audit_approval') is not None:
        audits = engine.load('plan-audits')
        manifest = audits.snapshot(root / 'etc/sasd-security/audit-source', host, context['client-plan'])
    result = model(request, engine.load('plan-security'), manifest)
    original = {name: {'data': value.encode('ascii').hex(), 'mode': 0o644}
                for name, value in request['original'].items()}
    binding = {'request-sha256': hashlib.sha256(data).hexdigest(),
               'audit-approved-digest': request['audit_approval']}
    return binding, original, result


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
