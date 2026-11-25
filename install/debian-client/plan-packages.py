#!/usr/bin/python3 -I
"""Inspect local APT package candidates and optionally simulate both checklist stages."""
import argparse
from pathlib import Path
import os
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ENV = {'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'LC_ALL': 'C'}
APT = ('-o', 'Dir::Cache::pkgcache=', '-o', 'Dir::Cache::srcpkgcache=')
PACKAGE = re.compile(r'[a-z0-9][a-z0-9+.-]+')
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
    p.add_argument('--live', action='store_true', required=True)
    p.add_argument('--stage', choices=('1', '2', 'both'), default='both')
    p.add_argument('--simulate', action='store_true')
    a = p.parse_args()
    if os.geteuid() == 0:
        p.error('run as an ordinary user; never install packages')
    try:
        stages = candidates(HERE / 'package-policy.tsv')
    except (OSError, ValueError) as exc:
        print('plan-packages: ' + str(exc), file=sys.stderr)
        return 2
    print('SASD-PACKAGE-PLAN-1\nscope\tLOCAL_APT_READ_ONLY')
    print('task\tpackage\tstatus\tinstalled\tcandidate')
    blocked = False
    selected = []
    for stage in ('1', '2'):
        if a.stage not in (stage, 'both'):
            continue
        for name in stages[stage]:
            selected.append(name)
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
    if not a.simulate:
        print('simulation\tNOT_RUN')
    elif blocked:
        print('simulation\tBLOCKED\tpackage-candidate-review')
    else:
        try:
            r = command('/usr/bin/apt-get', *APT, '--simulate', '--no-install-recommends',
                        '--no-remove', 'install', *selected)
            if r.returncode or r.stderr.strip():
                raise ValueError('APT simulation failed or warned')
            status, upgraded, new, removed, held = simulation_result(r.stdout)
            print('simulation\t%s\tupgraded=%d,new=%d,removed=%d,not-upgraded=%d' %
                  (status, upgraded, new, removed, held))
            blocked = status != 'SIMULATED'
        except (OSError, ValueError, subprocess.SubprocessError):
            print('simulation\tUNKNOWN\tAPT-error-or-unrecognized-output')
            blocked = True
    print('package-apply\tNOT_AUTHORIZED')
    return 3 if blocked else 0


if __name__ == '__main__':
    sys.exit(main())
