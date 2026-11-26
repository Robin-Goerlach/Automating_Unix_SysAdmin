#!/usr/bin/python3 -I
"""Collect current, committed fixture evidence without promoting native dependencies."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
FORMATS = {name: 'SASD-' + name.upper() + '-FIXTURE-1' for name in
           ('banner', 'logging', 'storage', 'communications', 'shell', 'security', 'network', 'monitoring')}
FORMATS.update(packages='SASD-PACKAGE-FIXTURE-1', services='SASD-SERVICE-FIXTURE-1')
HEX = re.compile(r'[0-9a-f]{64}')
JOURNAL = re.compile(r'native\.[0-9a-f]{32}\.json')


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def private(path, tx, owner):
    if not isinstance(path, str) or not path.startswith('/') or str(Path(path).resolve()) != path:
        raise ValueError('canonical private input path required')
    data, mode = tx.read_file(Path(path), owner, 65536, target=True)
    if mode != 0o600:
        raise ValueError('private evidence input required')
    return data


def selection(data, tx):
    value = json.loads(data, object_pairs_hook=tx.unique_pairs)
    if not isinstance(value, dict) or set(value) != {'groups'} or not isinstance(value['groups'], dict):
        raise ValueError('invalid evidence selection')
    groups = value['groups']
    if not groups or not set(groups) <= set(FORMATS):
        raise ValueError('unknown or empty group selection')
    roots = set()
    for entry in groups.values():
        if (not isinstance(entry, dict) or set(entry) != {'root','reference','journal'} or
                any(not isinstance(v,str) for v in entry.values()) or not JOURNAL.fullmatch(entry['journal']) or
                not entry['root'].startswith('/tmp/') or str(Path(entry['root']).resolve()) != entry['root'] or
                entry['root'] in roots):
            raise ValueError('invalid or repeated group root')
        roots.add(entry['root'])
    return groups


def collect(host, inventory, roles, manifest):
    tx = load('native-install')
    dispatch = load('fixture-dispatch')
    lab = load('lab-install')
    pkg = load('plan-packages')
    owner = os.geteuid()
    raw = private(manifest, tx, owner)
    groups = selection(raw, tx)
    release = lab.release_digest()
    rows = dispatch.coverage()
    input_paths = {'inventory': Path(inventory), 'roles': Path(roles)}
    captured = {k: lab.read_file(path) for k,path in input_paths.items()}
    report = {}
    with tempfile.TemporaryDirectory(prefix='sasd-evidence-input.') as name:
        base = Path(name)
        for k,data in captured.items():
            (base/k).write_bytes(data)
        profile, _, context = pkg.inventory_selection(host, str(base/'inventory'), str(base/'roles'))
        for group in sorted(groups):
            entry = groups[group]
            raw_ref = private(entry['reference'], tx, owner)
            ref = json.loads(raw_ref, object_pairs_hook=tx.unique_pairs)
            if not isinstance(ref, dict) or ref.get('format') != FORMATS[group]:
                raise ValueError('reference does not belong to selected group')
            if (ref.get('host') != host or ref.get('root') != entry['root'] or
                    ref.get('inventory') != context or ref.get('release') != release):
                raise ValueError('reference context mismatch')
            frozen = base/(group+'.reference')
            frozen.write_bytes(raw_ref)
            frozen.chmod(0o600)
            command = ['/usr/bin/python3','-I',str(HERE/('fixture-'+group+'.py')),
                       '--hostname='+host,'--inventory='+str(base/'inventory'),'--roles='+str(base/'roles'),
                       '--root='+entry['root'],'--reference='+str(frozen),'--evidence='+entry['journal']]
            r = subprocess.run(command, env=tx.ENV, capture_output=True, timeout=180)
            if r.returncode != 0:
                report[group] = {'status':'NOT_VERIFIED','evidence':None}
            else:
                evidence = json.loads(r.stdout, object_pairs_hook=tx.unique_pairs)
                expected = {'format':'SASD-GROUP-EVIDENCE-1','scope':'FIXTURE_STATIC_ONLY',
                            'group-format':FORMATS[group],'host':host,'inventory':context,'release':release,
                            'reference-sha256':tx.digest(tx.encoded(ref)), 'journal':entry['journal'],
                            'desired-sha256':ref.get('desired'),'native-verification':'NOT_VERIFIED'}
                if (not isinstance(evidence,dict) or set(evidence) != set(expected)|{'journal-sha256'} or
                        any(evidence[k] != v for k,v in expected.items()) or
                        any(not isinstance(evidence[k],str) or not HEX.fullmatch(evidence[k])
                            for k in ('journal-sha256','desired-sha256','reference-sha256'))):
                    raise ValueError('invalid backend evidence')
                # No raw reference, target content, request, inventory rows or private paths in group output.
                report[group] = {'status':'STATIC_COMMITTED_MATCH',
                                 'evidence':{k:evidence[k] for k in ('reference-sha256','journal','journal-sha256','desired-sha256')}}
            if private(entry['reference'],tx,owner) != raw_ref:
                raise ValueError('reference changed during collection')
        if (lab.release_digest() != release or private(manifest,tx,owner) != raw or
                any(lab.read_file(path) != captured[k] for k,path in input_paths.items())):
            raise ValueError('collection context changed')
    # Group snapshots are sequential, not a shared transaction; never claim
    # per-task success even when a group matches (requests may select a subset).
    tasks = []
    edges = []
    for row in rows:
        task, _, _, _, _, group = row[:6]
        state = report[group]['status'] if group in report else 'NOT_COLLECTED'
        tasks.append({'id':task,'group':group,'group-observation':state,'installed':'NOT_CERTIFIED'})
        if row[-2] != '-':
            for edge in row[-2].split(','):
                before,kind = edge.split(':')
                edges.append({'task':task,'prerequisite':before,'required':kind,
                              'status':'WAIT_VERIFIED' if kind=='verified' else 'WAIT_CANDIDATE'})
    return {'format':'SASD-EVIDENCE-REPORT-1','scope':'FIXTURE_STATIC_ONLY',
            'host':host,'profile':profile,'inventory-plan':context['client-plan'],
            'inventory-inputs':context['inputs'],'release':release,'selection-sha256':tx.digest(raw),
            'consistency':'SEQUENTIAL_NOT_ATOMIC','native-verification':'NOT_VERIFIED',
            'dependency-promotion':'NOT_AUTHORIZED','groups':report,'tasks':tasks,'dependencies':edges}


def main():
    p = argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    p.add_argument('--evidence-report',action='store_true',required=True)
    for name in ('hostname','inventory','roles','manifest'):
        p.add_argument('--'+name,required=True)
    keys = [arg.split('=',1)[0] for arg in sys.argv[1:] if arg.startswith('--')]
    if len(keys)!=len(set(keys)):
        p.error('duplicate option')
    a=p.parse_args()
    if os.geteuid()==0 or os.getuid()!=os.geteuid() or os.getgid()!=os.geteuid():
        p.error('ordinary user required')
    os.umask(0o077)
    try:
        result=collect(a.hostname,a.inventory,a.roles,a.manifest)
        sys.stdout.write(json.dumps(result,sort_keys=True,indent=2)+'\n')
        return 0 if all(v['status']=='STATIC_COMMITTED_MATCH' for v in result['groups'].values()) else 3
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError,RecursionError):
        print('fixture-evidence: invalid or changed collection context',file=sys.stderr)
        return 2


if __name__=='__main__':
    sys.exit(main())
