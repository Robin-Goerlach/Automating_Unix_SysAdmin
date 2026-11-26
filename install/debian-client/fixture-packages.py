#!/usr/bin/python3 -I
"""Exercise reviewed package install actions against a synthetic package database only."""
from pathlib import Path
import hashlib
import importlib.util
import json
import os
import re
import sys

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-PACKAGE-FIXTURE-1'
PREFIX = 'sasd-package-lab'
MARKER = '.sasd-package-fixture'
LABEL = 'PACKAGE'
DIRECTORIES = ()
PROFILES = ('baseline', 'workstation', 'laptop', 'server')
NAMES = ('package-state.json',)

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('fixture_config', HERE / 'fixture-config.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


def package_map(value, planner):
    """Bound the single-architecture test model; never accept option-like names."""
    if not isinstance(value, dict) or len(value) > 256:
        raise ValueError('invalid package map')
    for name, version in value.items():
        if (not planner.PACKAGE.fullmatch(name) or len(name) > 128 or
                not isinstance(version, str) or len(version) > 128 or
                not planner.VERSION.fullmatch(version)):
            raise ValueError('invalid package name or version')
    return value


def model(value, stages, planner):
    """Validate a synthetic APT action transcript and derive the exact new state.

    The transcript is not trusted APT evidence or a resolver. Only new installs
    with paired configuration actions are modeled; dependencies are explicit.
    """
    if not isinstance(value, dict) or set(value) != {'stage', 'installed', 'candidates', 'simulation'}:
        raise ValueError('invalid fixture simulation fields')
    stage = value['stage']
    if stage not in ('1', '2', 'both'):
        raise ValueError('unsupported stage')
    installed = package_map(value['installed'], planner)
    candidates = package_map(value['candidates'], planner)
    selected = [name for key in ('1', '2') if stage in (key, 'both') for name in stages[key]]
    if not selected or set(candidates) != set(selected):
        raise ValueError('candidate set differs from selected profile')
    if any(name in installed and installed[name] != candidates[name] for name in selected):
        raise ValueError('selected package version change requires separate review')
    output = value['simulation']
    if not isinstance(output, str) or len(output) > 32768:
        raise ValueError('invalid simulation transcript')
    for line in output.splitlines():
        if not (line.startswith(('Inst ', 'Conf ', 'Remv ', 'Purg ')) or
                re.fullmatch(r'\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded\.', line)):
            raise ValueError('unsupported synthetic transcript line')
    status, upgrades, new, removals, held = planner.simulation_result(output)
    actions = planner.simulation_actions(output)
    if status != 'SIMULATED' or upgrades or removals:
        raise ValueError('only new installations supported')
    additions = {}
    configured = set()
    for action, name, old, version in actions:
        if (not planner.PACKAGE.fullmatch(name) or len(name) > 128 or
                old != '-' or len(version) > 128 or name in installed):
            raise ValueError('unsupported architecture, existing package or version')
        if action == 'Inst':
            additions[name] = version
        elif action == 'Conf' and additions.get(name) == version:
            configured.add(name)
        else:
            raise ValueError('unpaired configuration action')
    missing = set(selected) - set(installed)
    if (set(additions) != configured or len(additions) != new or
            not missing <= set(additions) or (not missing and additions) or
            any(additions[name] != candidates[name] for name in missing)):
        raise ValueError('simulation differs from selected candidates')
    desired = dict(installed, **additions)
    package_map(desired, planner)
    return desired, actions, held


def prepare(root, host, profile, stages, tx):
    """Bind exact private synthetic input, original state and desired state."""
    data, mode = tx.read_file(root / 'simulation.json', os.geteuid(), 65536, target=True)
    if mode != 0o600:
        raise ValueError('simulation must be private')
    value = json.loads(data, object_pairs_hook=tx.unique_pairs)
    desired, actions, held = model(value, stages, engine.load('plan-packages'))
    original = {NAMES[0]: {'data': tx.encoded(value['installed']).hex(), 'mode': 0o644}}
    binding = {'simulation-sha256': hashlib.sha256(data).hexdigest(),
               'stage': value['stage'], 'action-count': len(actions), 'not-upgraded': held}
    return binding, original, {NAMES[0]: tx.encoded(desired)}


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
