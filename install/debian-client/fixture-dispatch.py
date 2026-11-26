#!/usr/bin/python3 -I
"""Inventory of capability coverage and explicit single-group fixture dispatch."""
import argparse
import csv
from pathlib import Path
import os
import re
import sys

HERE = Path(__file__).resolve().parent
GROUPS = {
    'baseline': ('BASELINE_FIXTURE_AND_EXPERIMENTAL_VM',),
    'banner': ('BANNER_FIXTURE',),
    'logging': ('LOGGING_FIXTURE',),
    'packages': ('PACKAGE_STATE_FIXTURE',),
    'services': ('SERVICE_STATE_FIXTURE',),
    'storage': ('FSTAB_CONFIG_FIXTURE',),
    'communications': ('COMMUNICATIONS_CONFIG_FIXTURE',),
    'shell': ('SHELL_FRAGMENT_FIXTURE',),
    'security': ('SECURITY_CONFIG_FIXTURE',),
    'network': ('NETWORK_CONFIG_FIXTURE', 'FIREWALL_POLICY_FIXTURE'),
    'monitoring': ('MONITORING_HANDOFF_FIXTURE',),
}
# These are records, not actual firewall rules or active monitoring.
RECORDS = {'0250', '0400', '0890', '0900'}
MODELS = {'0200', '0300', '0710', '0730'}
IDS = tuple('%04d' % n for n in range(10, 1161, 10))


def table(path, fields):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 1024 * 1024:
        raise ValueError('unsafe catalog')
    with path.open(encoding='ascii', newline='') as stream:
        reader = csv.reader(stream, delimiter='\t', quoting=csv.QUOTE_NONE)
        if tuple(next(reader, [])) != fields:
            raise ValueError('unexpected catalog header')
        result = list(reader)
    if any(len(row) != len(fields) or any(not value or any(ord(c) < 32 or ord(c) == 127 for c in value)
                                         for value in row) for row in result):
        raise ValueError('invalid catalog row')
    return result


def coverage(directory=HERE):
    checklist = table(directory / 'checklist.tsv', ('id','original_line','task','state','handler'))
    capabilities = table(directory / 'capabilities.tsv', ('id','task','artifact','apply','verify','rollback'))
    dependencies = table(directory / 'dependencies.tsv', ('task','prerequisite','evidence'))
    if tuple(r[0] for r in checklist) != IDS or tuple(r[0] for r in capabilities) != IDS:
        raise ValueError('missing, duplicate or reordered task')
    if len({r[1] for r in checklist}) != len(IDS) or any(not r[1].isdigit() for r in checklist):
        raise ValueError('invalid source-line coverage')
    edges = {task: [] for task in IDS}
    for task, before, kind in dependencies:
        if task not in edges or before not in edges or before >= task or kind not in ('candidate','verified'):
            raise ValueError('unsupported dependency')
        edge = before + ':' + kind
        if any(v.split(':')[0] == before for v in edges[task]):
            raise ValueError('duplicate dependency')
        edges[task].append(edge)
    mapping = {cap: group for group, caps in GROUPS.items() for cap in caps}
    rows = []
    for c, m in zip(checklist, capabilities):
        task, line, name, state, handler = c
        _, other, artifact, apply, verify, rollback = m
        if name != other or not re.fullmatch(r'[A-Za-z0-9_]+', name):
            raise ValueError('catalog identity mismatch')
        if state in ('manual', 'central'):
            if artifact != state.upper() or (apply,verify,rollback) != ('OPERATOR_REQUIRED',)*3:
                raise ValueError('invalid operator boundary')
            scope, group = state.upper(), '-'
        elif state == 'render' and artifact in ('CONFIG_TEXT','PACKAGE_LIST','REVIEW_TSV'):
            if apply in mapping:
                group = mapping[apply]
                if rollback != 'OPEN_JOURNAL_RECOVERY' or verify in ('NOT_IMPLEMENTED','OPERATOR_REQUIRED'):
                    raise ValueError('incomplete apply contract')
                scope = ('EXPERIMENTAL_BASELINE' if group == 'baseline' else
                         'POLICY_RECORD' if task in RECORDS else
                         'STATE_MODEL' if task in MODELS else 'CONFIG_FIXTURE')
            elif apply == rollback == 'NOT_IMPLEMENTED' and verify != 'OPERATOR_REQUIRED':
                group = '-'
                scope = 'CANDIDATE_ONLY' if verify == 'NOT_IMPLEMENTED' else 'VERIFY_ONLY'
            else:
                raise ValueError('unmapped capability')
        else:
            raise ValueError('unexpected checklist state')
        if group not in ('-', 'baseline'):
            backend = directory / ('fixture-' + group + '.py')
            if backend.is_symlink() or not backend.is_file():
                raise ValueError('missing fixture backend')
        rows.append((task, line, name, artifact, scope, group, apply, verify, rollback,
                     ','.join(edges[task]) or '-', 'NOT_CERTIFIED'))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--coverage', action='store_true')
    modes.add_argument('--fixture-group', choices=tuple(g for g in GROUPS if g != 'baseline'))
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--review', action='store_true')
    action.add_argument('--apply-fixture', action='store_true')
    action.add_argument('--verify', action='store_true')
    action.add_argument('--recover')
    for name in ('root','hostname','inventory','roles','reference'):
        parser.add_argument('--' + name)
    # Reject repeated options, including repeated mode switches.
    keys = [arg.split('=', 1)[0] for arg in sys.argv[1:] if arg.startswith('--')]
    if len(keys) != len(set(keys)):
        parser.error('duplicate option')
    a = parser.parse_args()
    try:
        rows = coverage()
        args = ('root','hostname','inventory','roles')
        if a.coverage:
            if any(getattr(a,k) is not None for k in (*args,'reference','recover')) or a.review or a.apply_fixture or a.verify:
                parser.error('coverage takes no execution arguments')
            print('id\toriginal_line\ttask\tartifact\tscope\tgroup\tapply\tverify\trollback\tdependencies\tinstalled')
            for row in rows:
                print('\t'.join(row))
            return 0
        if (os.geteuid() == 0 or not all(getattr(a,k) for k in args) or
                not (a.review or a.apply_fixture or a.verify or a.recover is not None) or
                bool(a.reference) == a.review):
            parser.error('explicit unprivileged group operation and matching reference required')
        # No automatic ordering, dependency promotion, shared root or bulk apply.
        # The selected backend remains the sole authority for review and writes.
        command = [str(HERE / ('fixture-' + a.fixture_group + '.py'))]
        command += ['--' + k + '=' + getattr(a,k) for k in args]
        if a.reference:
            command.append('--reference=' + a.reference)
        command.append('--review' if a.review else '--apply-fixture' if a.apply_fixture else
                       '--verify' if a.verify else '--recover=' + a.recover)
        os.execv('/usr/bin/python3', ['/usr/bin/python3','-I',*command])
    except (OSError, ValueError):
        print('fixture-dispatch: invalid catalog or execution context', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
