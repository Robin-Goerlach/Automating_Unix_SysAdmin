#!/usr/bin/python3 -I
"""Reference-bound two-file login banner transaction, exclusively in a private fixture."""
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
NAMES = ('issue', 'issue.net')
FORMAT = 'SASD-BANNER-FIXTURE-1'
PREFIX = 'sasd-banner-lab'
MARKER = '.sasd-banner-fixture'
LABEL = 'BANNER'
DIRECTORIES = ()
PROFILES = ()

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('fixture_config', HERE / 'fixture-config.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


def transaction():
    return engine.transaction(NAMES)


def render(host, tx):
    result = tx.command('/bin/sh', str(HERE / 'tasks/0460_Login_Banner'), '--hostname=' + host, '--render')
    if result != b'Unauthorized access is prohibited.\n':
        raise ValueError('unexpected banner renderer output')
    return dict.fromkeys(NAMES, result)


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
