#!/usr/bin/python3 -I
"""Produce a read-only orchestration plan from R2, catalog and current fixture evidence."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def task_plan(raw, context, coverage, only):
    """Validate the canonical Perl plan against the existing coverage contract."""
    lines = raw.decode('ascii').splitlines()
    if (len(lines) < 4 or lines[0] != 'SASD-CLIENT-PLAN-1' or
            lines[1].split('\t') != context['host'] or
            lines[2] != 'id\ttask\tcategory\tplan_status\tprerequisites'):
        raise ValueError('unexpected R2 plan header')
    catalog = {row[0]: row for row in coverage}
    expected = set(catalog) if only is None else {only}
    if only is not None:
        if only not in catalog:
            raise ValueError('unknown selected task')
        # Independently check only the closure, not the planner's scheduling rules.
        pending = [only]
        while pending:
            row = catalog[pending.pop()]
            for edge in row[-2].split(',') if row[-2] != '-' else ():
                before = edge.split(':')[0]
                if before not in expected:
                    expected.add(before)
                    pending.append(before)
    result = []
    previous = set()
    for line in lines[3:]:
        fields = line.split('\t')
        if len(fields) != 5:
            raise ValueError('invalid plan row')
        task, name, category, status, prereqs = fields
        if task not in expected or task in previous or (result and task <= result[-1]['id']):
            raise ValueError('unexpected task order or identity')
        row = catalog[task]
        edges = prereqs.split(',') if prereqs != '-' else []
        canonical = row[-2].split(',') if row[-2] != '-' else []
        if (row[2] != name or sorted(edges) != sorted(canonical) or
                category != ('manual' if row[4] == 'MANUAL' else 'central' if row[4] == 'CENTRAL' else 'render')):
            raise ValueError('plan and capability matrix disagree')
        if status not in ('PLAN_CANDIDATE','WAIT_VERIFIED','WAIT_CANDIDATE','MANUAL','CENTRAL'):
            raise ValueError('unexpected canonical plan status')
        blockers = []
        for edge in edges:
            before, kind = edge.split(':')
            if before not in previous:
                raise ValueError('prerequisite missing or out of order')
            blockers.append({'prerequisite':before,'required':kind,
                             'status':'WAIT_VERIFIED' if kind == 'verified' else 'WAIT_CANDIDATE'})
        # Planning never generates a candidate or grants execution permission.
        # A group observation cannot prove a particular selected task succeeded.
        if any(e['required'] == 'verified' for e in blockers):
            action = 'WAIT_VERIFIED'
        elif blockers:
            action = 'WAIT_CANDIDATE'
        elif category in ('manual','central'):
            action = 'OPERATOR_REVIEW'
        else:
            action = 'REVIEW_CANDIDATE'
        result.append({'id':task,'task':name,'category':category,'canonical-status':status,
                       'scope':row[4],'group':row[5],'next-action':action,
                       'prerequisites':blockers,'installed':'NOT_CERTIFIED',
                       'native-execution':'NOT_AUTHORIZED'})
        previous.add(task)
    if previous != expected:
        raise ValueError('incomplete selected plan')
    return result


def build(host, inventory, roles, only=None, manifest=None):
    tx = load('native-install')
    lab = load('lab-install')
    pkg = load('plan-packages')
    dispatch = load('fixture-dispatch')
    collector = load('fixture-evidence')
    release = lab.release_digest()
    paths = {'inventory':Path(inventory),'roles':Path(roles)}
    inputs = {k:lab.read_file(v) for k,v in paths.items()}
    with tempfile.TemporaryDirectory(prefix='sasd-orchestration.') as tmp:
        root = Path(tmp)
        for k,data in inputs.items():
            (root/k).write_bytes(data)
        profile, _, context = pkg.inventory_selection(host,str(root/'inventory'),str(root/'roles'))
        command = ['/usr/bin/perl',str(HERE/'plan-client.pl'),'--hostname='+host,
                   '--inventory='+str(root/'inventory'),'--roles='+str(root/'roles')]
        full = tx.command(*command)
        if hashlib.sha256(full).hexdigest() != context['client-plan']:
            raise ValueError('canonical plan context changed')
        selected = full if only is None else tx.command(*command,'--only='+only)
        tasks = task_plan(selected,context,dispatch.coverage(),only)
        evidence = None
        if manifest is not None:
            evidence = collector.collect(host,str(root/'inventory'),str(root/'roles'),manifest)
            if (evidence['release'] != release or evidence['inventory-plan'] != context['client-plan'] or
                    evidence['inventory-inputs'] != context['inputs'] or evidence['scope'] != 'FIXTURE_STATIC_ONLY' or
                    evidence['native-verification'] != 'NOT_VERIFIED' or
                    evidence['dependency-promotion'] != 'NOT_AUTHORIZED'):
                raise ValueError('evidence context mismatch')
        if (lab.release_digest() != release or
                any(lab.read_file(v) != inputs[k] for k,v in paths.items())):
            raise ValueError('planning context changed')
    observations = evidence['groups'] if evidence is not None else {}
    groups = {}
    for task in tasks:
        group = task['group']
        if group != '-':
            groups.setdefault(group,{'tasks':[],'waiting':[],'dispatch':'EXPLICIT_GROUP_REVIEW_ONLY',
                                     'observation':observations.get(group,{}).get('status','NOT_COLLECTED')})
            groups[group]['tasks'].append(task['id'])
            if task['prerequisites']:
                groups[group]['waiting'].append(task['id'])
    for group,entry in groups.items():
        if group == 'baseline':
            entry['dispatch'] = 'LEGACY_BASELINE_REVIEW_ONLY'
    return {'format':'SASD-ORCHESTRATION-PLAN-1','scope':'READ_ONLY_PLANNING',
            'host':host,'profile':profile,'release':release,'inventory-plan':context['client-plan'],
            'inventory-inputs':context['inputs'],'selection':only or 'ALL',
            'selected-plan-sha256':hashlib.sha256(selected).hexdigest(),
            'evidence-report-sha256':tx.digest(tx.encoded(evidence)) if evidence is not None else None,
            'evidence-groups':{k:v['status'] for k,v in observations.items()},
            'native-verification':'NOT_VERIFIED','execution':'NOT_AUTHORIZED',
            'dependency-promotion':'NOT_AUTHORIZED',
            'tasks':tasks,'groups':groups,
            'next-review':[t['id'] for t in tasks if t['next-action']=='REVIEW_CANDIDATE'],
            'operator-review':[t['id'] for t in tasks if t['next-action']=='OPERATOR_REVIEW']}


def main():
    p = argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    p.add_argument('--orchestration-plan',action='store_true',required=True)
    for name in ('hostname','inventory','roles'):
        p.add_argument('--'+name,required=True)
    p.add_argument('--only')
    p.add_argument('--manifest')
    keys = [arg.split('=',1)[0] for arg in sys.argv[1:] if arg.startswith('--')]
    if len(keys)!=len(set(keys)):
        p.error('duplicate option')
    a = p.parse_args()
    if os.geteuid()==0 or os.getuid()!=os.geteuid() or os.getgid()!=os.geteuid():
        p.error('ordinary user required')
    if a.only is not None and not re.fullmatch(r'[0-9]{4}',a.only):
        p.error('invalid task selection')
    os.umask(0o077)
    try:
        result = build(a.hostname,a.inventory,a.roles,a.only,a.manifest)
        sys.stdout.write(json.dumps(result,sort_keys=True,indent=2)+'\n')
        return 3 if 'NOT_VERIFIED' in result['evidence-groups'].values() else 0
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError,RecursionError):
        print('orchestration-plan: invalid or changed planning context',file=sys.stderr)
        return 2


if __name__=='__main__':
    sys.exit(main())
