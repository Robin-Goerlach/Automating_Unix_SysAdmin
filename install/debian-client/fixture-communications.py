#!/usr/bin/python3 -I
"""Review and apply bounded SSH client and mail configuration in a private fixture."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-COMMUNICATIONS-FIXTURE-1'
PREFIX = 'sasd-communications-lab'
MARKER = '.sasd-communications-fixture'
LABEL = 'COMMUNICATIONS'
DIRECTORIES = ('ssh', 'ssh/ssh_config.d', 'postfix')
PROFILES = ('baseline', 'workstation', 'laptop', 'server')
NAMES = ('ssh/ssh_known_hosts', 'ssh/ssh_config.d/60-sasd-x11.conf',
         'aliases', 'postfix/main.cf')
X11 = (b'# Client candidate; evaluate effective Host/Match precedence first.\n'
       b'Host *\n    ForwardX11 no\n    ForwardX11Trusted no\n')
MAIL_KEYS = ('relayhost', 'inet_interfaces', 'mydestination', 'smtp_tls_security_level',
             'smtp_tls_CAfile', 'smtpd_banner')
# A narrow synthetic main.cf contract, not a general Postfix editor.
PRESERVED = {'myhostname', 'message_size_limit', 'mailbox_size_limit'}

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


def pins(original, requested, fingerprints, planner):
    """Append literal pins only; refuse key rotation and unmodeled host patterns."""
    original = text(original)
    requested = text(requested)
    if not isinstance(fingerprints, dict):
        raise ValueError('invalid independent fingerprint list')
    if not requested:
        if fingerprints:
            raise ValueError('unexpected fingerprint list')
        return original
    old = dict(planner.public_pins(original)) if any(
        line and not line.startswith('#') for line in original.splitlines()) else {}
    new = dict(planner.public_pins(requested))
    if new != fingerprints:
        raise ValueError('public pin fingerprint mismatch')
    for name, fp in new.items():
        if name in old and old[name] != fp:
            raise ValueError('existing host pin differs; separate rotation review')
    lines = []
    for line in requested.splitlines():
        if line and not line.startswith('#'):
            name, kind, key = line.split()
            if name not in old:
                lines.append(' '.join((name, kind, key)) + '\n')
    return original + ''.join(lines)


def aliases(original, recipient):
    """Preserve simple unrelated aliases; do not interpret pipes or includes."""
    result = []
    seen = set()
    for line in original.splitlines(keepends=True):
        if not line.strip() or line.lstrip().startswith('#'):
            result.append(line)
            continue
        match = re.fullmatch(r'([a-zA-Z0-9][a-zA-Z0-9_.-]*):[ \t]*([a-zA-Z0-9][a-zA-Z0-9_.+@-]*)[ \t]*\n', line)
        if not match or match[1].lower() in seen:
            raise ValueError('unsupported or duplicate alias')
        name = match[1].lower()
        seen.add(name)
        result.append('root: ' + recipient + '\n' if name == 'root' else line)
    if 'root' not in seen:
        result.append('root: ' + recipient + '\n')
    return ''.join(result)


def main_cf(original, values, planner):
    """Accept only explicit simple settings; refuse unknown or continuation syntax."""
    result = []
    seen = set()
    for line in original.splitlines(keepends=True):
        if not line.strip() or line.lstrip().startswith('#'):
            result.append(line)
            continue
        match = re.fullmatch(r'([a-zA-Z][a-zA-Z0-9_]*)[ \t]*=[ \t]*([^\n]*)\n', line)
        if not match or match[1] in seen:
            raise ValueError('unsupported or duplicate Postfix setting')
        key, value = match.groups()
        seen.add(key)
        if key in values:
            result.append(key + ' = ' + values[key] + '\n')
        elif key in PRESERVED:
            if key == 'myhostname':
                planner.fqdn(value.strip())
            elif not re.fullmatch(r'[0-9]{1,12}', value.strip()):
                raise ValueError('unsupported size setting')
            result.append(line)
        else:
            raise ValueError('unreviewed Postfix setting')
    for key in MAIL_KEYS:
        if key not in seen:
            result.append(key + ' = ' + values[key] + '\n')
    return ''.join(result)


def model(request, host, profile, stages, planner, x11=X11):
    fields = {'original', 'pins', 'fingerprints', 'x11', 'sshd_effective', 'mail'}
    if not isinstance(request, dict) or set(request) != fields:
        raise ValueError('invalid communications request')
    original = request['original']
    if not isinstance(original, dict) or set(original) != set(NAMES):
        raise ValueError('invalid original target set')
    original = {name: text(value) for name, value in original.items()}
    result = dict(original)
    packages = {name for names in stages.values() for name in names}
    if request['pins'] and 'openssh-client' not in packages:
        raise ValueError('SSH client not selected')
    result[NAMES[0]] = pins(original[NAMES[0]], request['pins'], request['fingerprints'], planner)
    if type(request['x11']) is not bool:
        raise ValueError('invalid X11 choice')
    if request['x11']:
        if 'openssh-client' not in packages or original[NAMES[1]].encode('ascii') not in (b'', x11):
            raise ValueError('unreviewed X11 drop-in or missing client profile')
        result[NAMES[1]] = x11.decode('ascii')
    effective = request['sshd_effective']
    if effective is not None:
        if (profile != 'server' or not {'openssh-server', 'openssh-sftp-server'} <= packages or
                planner.sftp_result(text(effective)) != 'RECOGNIZED_STATIC'):
            raise ValueError('SFTP effective configuration needs separate review')
    mail = request['mail']
    if mail is not None:
        if (not isinstance(mail, dict) or set(mail) != {'relay', 'recipient', 'postfix_installed'} or
                mail['postfix_installed'] is not True or
                not isinstance(mail['relay'], str) or not isinstance(mail['recipient'], str)):
            raise ValueError('explicit modeled Postfix installation and mail policy required')
        values = dict(planner.mail_values(mail['relay'], mail['recipient']))
        if mail['relay'] == host or mail['recipient'].rsplit('@', 1)[1] == host:
            raise ValueError('local relay or alias loop')
        result[NAMES[2]] = aliases(original[NAMES[2]], values.pop('root-alias'))
        result[NAMES[3]] = main_cf(original[NAMES[3]], values, planner)
    return {name: text(value).encode('ascii') for name, value in result.items()}


def prepare(root, host, profile, stages, tx, context):
    data, mode = tx.read_file(root / 'request.json', os.geteuid(), 65536, target=True)
    if mode != 0o600:
        raise ValueError('communications request must be private')
    request = json.loads(data, object_pairs_hook=tx.unique_pairs)
    x11 = tx.command('/bin/sh', str(HERE / 'tasks/0450_SSH_X11_Configure'),
                     '--hostname=' + host, '--render')
    if x11 != X11:
        raise ValueError('unexpected X11 renderer')
    result = model(request, host, profile, stages, engine.load('plan-communications'), x11)
    original = {name: {'data': value.encode('ascii').hex(), 'mode': 0o644}
                for name, value in request['original'].items()}
    binding = {'request-sha256': hashlib.sha256(data).hexdigest(),
               'sftp-static-reviewed': request['sshd_effective'] is not None,
               'mail-selected': request['mail'] is not None}
    return binding, original, result


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
