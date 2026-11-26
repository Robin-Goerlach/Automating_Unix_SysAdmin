#!/usr/bin/python3 -I
"""Stage offline hardware previews for the existing SASD monitoring contract."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import tempfile

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-MONITORING-FIXTURE-1'
PREFIX = 'sasd-monitoring-lab'
MARKER = '.sasd-monitoring-fixture'
LABEL = 'MONITORING'
DIRECTORIES = ('sasd-monitoring',)
PROFILES = ('baseline', 'workstation', 'laptop', 'server')
NAMES = ('sasd-monitoring/status-preview.tsv', 'sasd-monitoring/handoff.json')
# Use the existing canonical parser and applicability rules, not a second
# implementation of the monitoring protocol or an additional inventory.
VALIDATE = r'''
use strict;
use SASD::Monitor qw(read_checks applicable_checks validate_status);
my ($catalog, $role, $host, $preview) = @ARGV;
my $checks = read_checks($catalog);
my %allowed = map { $_ => 1 } applicable_checks({role=>$role}, $checks);
open(my $fh, '<', $preview) or die "cannot read preview\n";
my %seen;
while (<$fh>) {
    chomp;
    my @v = split /\t/, $_, -1;
    @v == 4 && $v[0] eq $host && $allowed{$v[1]} && !$seen{$v[1]}++
        or die "preview check not applicable\n";
    validate_status(@v);
}
close $fh;
scalar(keys %seen) or die "empty preview\n";
'''

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
        raise ValueError('final newline required')
    return value


def canonical_validate(catalog, preview, host, role, tx):
    # In extracted archives use the same bundled module as plan-client.pl.
    library = HERE / 'lib' if (HERE / 'lib/SASD/Monitor.pm').is_file() else HERE / '../../lib'
    with tempfile.TemporaryDirectory(prefix='sasd-monitoring-check.') as name:
        path = Path(name)
        checks, status = path / 'checks.tsv', path / 'preview.tsv'
        checks.write_text(catalog, encoding='ascii')
        status.write_text(preview, encoding='ascii')
        tx.command('/usr/bin/perl', '-I', str(library), '-MSASD::Monitor',
                   '-e', VALIDATE, str(checks), role, host, str(status))


def hardware_review(value):
    """Bounded nonidentifying operator capture, not a hardware inventory database."""
    if value is None:
        return None
    keys = {'kernel', 'architecture', 'logical_cpus', 'mount_count'}
    if not isinstance(value, dict) or set(value) != keys:
        raise ValueError('invalid hardware capture')
    for name in ('kernel', 'architecture'):
        if not isinstance(value[name], str) or not re.fullmatch(r'[A-Za-z0-9_.+-]{1,96}', value[name]):
            raise ValueError('invalid hardware label')
    for name in ('logical_cpus', 'mount_count'):
        if type(value[name]) is not int or not 1 <= value[name] <= 65536:
            raise ValueError('invalid hardware count')
    return value


def model(request, host, profile, stages, context, monitor, tx):
    keys = {'original', 'checks', 'select', 'smart', 'sensors', 'hardware'}
    if not isinstance(request, dict) or set(request) != keys:
        raise ValueError('invalid monitoring request')
    original = request['original']
    if not isinstance(original, dict) or set(original) != set(NAMES):
        raise ValueError('invalid monitoring targets')
    original = {name: text(value) for name, value in original.items()}
    catalog = text(request['checks'])
    select = request['select']
    if (not isinstance(select, list) or not select or
            any(not isinstance(v, str) or v not in monitor.CHECKS for v in select) or
            len(set(select)) != len(select)):
        raise ValueError('explicit unique check selection required')
    packages = {name for names in stages.values() for name in names}
    inputs = {'client-smart': ('smartmontools', request['smart'], monitor.smart_result),
              'client-temp': ('lm-sensors', request['sensors'], monitor.sensor_result)}
    rows = []
    for check in monitor.CHECKS:
        package, capture, parser = inputs[check]
        if check not in select:
            if capture is not None:
                raise ValueError('capture provided for unselected check')
            continue
        if package not in packages:
            raise ValueError('monitoring prerequisite not selected in R2 profile')
        color, message = (parser(capture) if capture is not None else
                          ('purple', 'offline hardware capture not supplied'))
        rows.append('\t'.join((host, check, color, message + '; preview not authenticated')))
    preview = '\n'.join(rows) + '\n'
    role = context['host'][4]
    canonical_validate(catalog, preview, host, role, tx)
    handoff = {'format': 'SASD-MONITORING-HANDOFF-1', 'host': host,
               'role': role, 'profile': profile, 'inventory-plan': context['client-plan'],
               'checks-sha256': hashlib.sha256(catalog.encode('ascii')).hexdigest(),
               'preview-sha256': hashlib.sha256(preview.encode('ascii')).hexdigest(),
               'selected-checks': [check for check in monitor.CHECKS if check in select],
               'hardware-review': hardware_review(request['hardware']),
               'scope': 'SYNTHETIC_PREVIEW_ONLY', 'enrollment': 'NOT_REQUESTED',
               'authentication': 'NOT_VERIFIED', 'transport': 'NOT_RUN'}
    output = {NAMES[0]: preview, NAMES[1]: tx.encoded(handoff).decode('ascii')}
    # Never overwrite a different preview or silently replace a reviewed handoff.
    if any(original[n] not in ('', output[n]) for n in NAMES):
        raise ValueError('existing monitoring handoff differs; new private fixture required')
    return {name: text(value).encode('ascii') for name, value in output.items()}


def prepare(root, host, profile, stages, tx, context):
    data, mode = tx.read_file(root / 'request.json', os.geteuid(), 65536, target=True)
    if mode != 0o600:
        raise ValueError('monitoring request must be private')
    monitor = engine.load('plan-monitoring')
    request = json.loads(data, object_pairs_hook=tx.unique_pairs, parse_constant=monitor.reject_constant)
    result = model(request, host, profile, stages, context, monitor, tx)
    original = {name: {'data': value.encode('ascii').hex(), 'mode': 0o644}
                for name, value in request['original'].items()}
    return {'request-sha256': hashlib.sha256(data).hexdigest()}, original, result


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
