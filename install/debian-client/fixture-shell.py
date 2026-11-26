#!/usr/bin/python3 -I
"""Install opt-in shell fragments in a private fixture; never source startup files."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-SHELL-FIXTURE-1'
PREFIX = 'sasd-shell-lab'
MARKER = '.sasd-shell-fixture'
LABEL = 'SHELL'
DIRECTORIES = ('sasd-shell',)
PROFILES = ('baseline', 'workstation', 'laptop', 'server')
TASKS = {
    '0190': ('Root_Profile_Stage_1', 'root-interactive.sh'),
    '0580': ('Shell_Default_Access', 'interactive.sh'),
    '0590': ('Shell_Global_Csh', 'interactive.csh'),
    '0630': ('Compatibility_BSD', 'compat-bsd.sh'),
    '0670': ('Compatibility_More_Less', 'pager.sh'),
}
NAMES = tuple('sasd-shell/' + name for _, name in TASKS.values())
EXPECTED = {
    '0190': b"""# Optional root interactive profile fragment; preserve existing startup files.
case $- in
    *i*) umask 077; alias ll='ls -l'; alias la='ls -A' ;;
esac
""",
    '0580': b"""# Optional interactive POSIX-shell fragment; timeout only for Bash.
case $- in
    *i*)
        umask 027
        if [ -n "\x24{BASH_VERSION-}" ] && [ "\x24{TMOUT+x}" != x ]; then
            TMOUT=600
            readonly TMOUT
            export TMOUT
        fi
        ;;
esac
""",
    '0590': b"""# Optional C-shell fragment; do not replace distribution startup files.
if ( $?prompt ) then
    umask 027
    alias ll 'ls -l'
endif
""",
    '0630': b"""# Optional interactive convenience alias, not BSD emulation.
case $- in
    *i*) alias bsdps='ps aux' ;;
esac
""",
    '0670': b"""# Optional interactive preference; never replace the more executable.
case $- in
    *i*)
        if [ -z "\x24{PAGER-}" ] && command -v less >/dev/null 2>&1; then
            PAGER=less
            export PAGER
        fi
        ;;
esac
""",
}

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('fixture_config', HERE / 'fixture-config.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


def model(request, rendered):
    """Only empty or identical managed slots can be written; no arbitrary code input."""
    if not isinstance(request, dict) or set(request) != {'original', 'select'}:
        raise ValueError('invalid shell fixture request')
    original, selected = request['original'], request['select']
    if not isinstance(original, dict) or set(original) != set(NAMES):
        raise ValueError('invalid shell fixture target set')
    if (not isinstance(selected, list) or not selected or
            any(not isinstance(task, str) or task not in TASKS for task in selected) or
            len(set(selected)) != len(selected)):
        raise ValueError('invalid or duplicate shell selection')
    if rendered != EXPECTED:
        raise ValueError('unexpected shell renderer content')
    desired = {}
    for name, value in original.items():
        if not isinstance(value, str) or len(value) > 65536:
            raise ValueError('invalid original shell text')
        data = value.encode('ascii')
        if any(c < 32 and c not in (9, 10) or c == 127 for c in data):
            raise ValueError('invalid shell text bytes')
        desired[name] = data
    for task in selected:
        name = 'sasd-shell/' + TASKS[task][1]
        if desired[name] not in (b'', rendered[task]):
            raise ValueError('existing managed shell fragment needs review')
        desired[name] = rendered[task]
    return desired


def prepare(root, host, profile, stages, tx, context):
    data, mode = tx.read_file(root / 'request.json', os.geteuid(), 65536, target=True)
    if mode != 0o600:
        raise ValueError('shell request must be private')
    request = json.loads(data, object_pairs_hook=tx.unique_pairs)
    rendered = {}
    for task, (script, _) in TASKS.items():
        rendered[task] = tx.command('/bin/sh', str(HERE / 'tasks' / (task + '_' + script)),
                                    '--hostname=' + host, '--render')
    desired = model(request, rendered)
    original = {name: {'data': value.encode('ascii').hex(), 'mode': 0o644}
                for name, value in request['original'].items()}
    binding = {'request-sha256': hashlib.sha256(data).hexdigest(),
               'selected-tasks': request['select']}
    return binding, original, desired


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
