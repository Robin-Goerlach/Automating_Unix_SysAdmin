#!/usr/bin/python3 -I
"""Immutable fixture checkpoints and read-only restart assessment."""
import argparse
import fcntl
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
FORMAT = 'SASD-CHECKPOINT-1'
LIMIT = 65536


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def inspect_groups(groups, owner, engine):
    """Inspect only named private fixture roots using the existing transaction lock."""
    result = {}
    for name, entry in sorted(groups.items()):
        group = load('fixture-' + name)
        tx = engine.transaction(group.NAMES)
        root = Path(entry['root'])
        try:
            identities = engine.fixture(root, owner, tx, group)
            store = root / 'transactions'
            fd = os.open(store, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                if (engine.fixture(root, owner, tx, group) != identities or
                        [os.fstat(fd).st_dev, os.fstat(fd).st_ino] != identities[2][:2]):
                    raise ValueError('fixture identity changed')
                pending = tx.pending(store, owner)
                records = {}
                for path in sorted(store.iterdir()):
                    journal = tx.load_journal(path, owner)
                    records[path.name] = tx.digest(tx.encoded(journal))
                result[name] = {'status':'OPEN_JOURNAL' if pending else 'NO_OPEN_JOURNAL',
                                'open-journal':pending[0].name if pending else None,
                                'directory-sha256':tx.digest(tx.encoded(identities)),
                                'journal-set-sha256':tx.digest(tx.encoded(records))}
            finally:
                os.close(fd)
        except (OSError, ValueError, RuntimeError, RecursionError):
            # Unknown entries, corrupt journals, lock contention or missing roots
            # are not evidence of an empty transaction store.
            result[name] = {'status':'INSPECTION_BLOCKED','open-journal':None,
                            'directory-sha256':None,'journal-set-sha256':None}
    return result


def context(plan):
    keys = ('host','profile','release','inventory-plan','inventory-inputs',
            'selection','selected-plan-sha256')
    return {key:plan[key] for key in keys}


def assess(host, inventory, roles, manifest, only):
    tx = load('native-install')
    engine = load('fixture-config')
    collector = load('fixture-evidence')
    planner = load('orchestration-plan')
    owner = os.geteuid()
    raw = collector.private(manifest, tx, owner)
    groups = collector.selection(raw, tx)
    plan = planner.build(host, inventory, roles, only)
    before = inspect_groups(groups, owner, engine)
    report = {'context':context(plan),'manifest-sha256':tx.digest(raw),
              'groups':before,'evidence-report-sha256':None}
    if all(v['status']=='NO_OPEN_JOURNAL' for v in before.values()):
        # The planner invokes the real evidence collector, not a saved report.
        with_evidence = planner.build(host, inventory, roles, only, manifest)
        if context(with_evidence) != report['context']:
            raise ValueError('planning context changed')
        report['evidence-report-sha256'] = with_evidence['evidence-report-sha256']
        for name, state in with_evidence['evidence-groups'].items():
            before[name]['evidence'] = state
        after = inspect_groups(groups, owner, engine)
        for name in before:
            if {k:v for k,v in before[name].items() if k!='evidence'} != after[name]:
                raise ValueError('journal inspection changed during collection')
    if collector.private(manifest, tx, owner) != raw:
        raise ValueError('manifest changed during assessment')
    if context(planner.build(host, inventory, roles, only)) != report['context']:
        raise ValueError('context changed during assessment')
    return report, groups


def clean(report):
    return all(v['status']=='NO_OPEN_JOURNAL' and v.get('evidence')=='STATIC_COMMITTED_MATCH'
               for v in report['groups'].values())


def checkpoint_path(value, owner, engine, groups, inputs):
    path = Path(value)
    if (not path.is_absolute() or str(path) != value or path.parent.resolve() != path.parent or
            not re.fullmatch(r'[A-Za-z0-9_-]{1,80}\.json', path.name)):
        raise ValueError('canonical checkpoint path required')
    engine.directory(path.parent, owner)
    if any(path == Path(v).resolve() for v in inputs):
        raise ValueError('checkpoint cannot be an input file')
    if any(path == Path(v['root']) or Path(v['root']) in path.parents for v in groups.values()):
        raise ValueError('checkpoint must be outside fixture roots')
    return path


def save_new(path, data, tx):
    """Publish an immutable private file without replacing any existing name."""
    if len(data)>LIMIT:
        raise ValueError('checkpoint too large')
    fd, tmp = tempfile.mkstemp(prefix='.sasd-checkpoint.', dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fchmod(stream.fileno(),0o600)
            os.fsync(stream.fileno())
        # Atomic create-if-absent; never replace even a dangling symlink.
        os.link(tmp,path,follow_symlinks=False)
        os.unlink(tmp)
        tx.sync_dir(path.parent)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def result(status, report, digest):
    return {'format':'SASD-RESTART-REVIEW-1','status':status,
            'checkpoint-sha256':digest,'current':report,
            'scope':'FIXTURE_STATIC_ONLY','consistency':'SEQUENTIAL_NOT_ATOMIC',
            'execution':'NOT_AUTHORIZED','recovery':'EXPLICIT_BACKEND_REVIEW_REQUIRED',
            'native-verification':'NOT_VERIFIED','dependency-promotion':'NOT_AUTHORIZED'}


def main():
    p=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    mode=p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--checkpoint-save',action='store_true')
    mode.add_argument('--checkpoint-resume',action='store_true')
    for name in ('hostname','inventory','roles','manifest','checkpoint'):
        p.add_argument('--'+name,required=True)
    p.add_argument('--only')
    p.add_argument('--expect-checkpoint')
    keys=[arg.split('=',1)[0] for arg in sys.argv[1:] if arg.startswith('--')]
    if len(keys)!=len(set(keys)):
        p.error('duplicate option')
    a=p.parse_args()
    if (os.geteuid()==0 or os.getuid()!=os.geteuid() or os.getgid()!=os.geteuid() or
            (a.only is not None and not re.fullmatch(r'[0-9]{4}',a.only)) or
            (a.checkpoint_save and a.expect_checkpoint is not None) or
            (a.checkpoint_resume and not re.fullmatch(r'[0-9a-f]{64}',a.expect_checkpoint or ''))):
        p.error('ordinary user and explicit checkpoint digest for resume required')
    os.umask(0o077)
    try:
        tx=load('native-install')
        engine=load('fixture-config')
        collector=load('fixture-evidence')
        owner=os.geteuid()
        raw_manifest=collector.private(a.manifest,tx,owner)
        groups=collector.selection(raw_manifest,tx)
        path=checkpoint_path(a.checkpoint,owner,engine,groups,
                             [a.inventory,a.roles,a.manifest]+[v['reference'] for v in groups.values()])
        saved=None
        if a.checkpoint_resume:
            data=collector.private(str(path),tx,owner)
            if hashlib.sha256(data).hexdigest()!=a.expect_checkpoint:
                raise ValueError('checkpoint digest mismatch')
            saved=json.loads(data,object_pairs_hook=tx.unique_pairs)
            if (not isinstance(saved,dict) or set(saved)!= {'format','scope','report'} or
                    saved['format']!=FORMAT or saved['scope']!='FIXTURE_STATIC_ONLY' or
                    not isinstance(saved['report'],dict) or set(saved['report'])!=
                    {'context','manifest-sha256','groups','evidence-report-sha256'}):
                raise ValueError('invalid checkpoint')
            # Check context before attempting fresh evidence with stale references.
            plan=load('orchestration-plan').build(a.hostname,a.inventory,a.roles,a.only)
            if (saved['report']['context']!=context(plan) or
                    saved['report']['manifest-sha256']!=tx.digest(raw_manifest)):
                print(json.dumps(result('CONTEXT_CHANGED',None,a.expect_checkpoint),sort_keys=True,indent=2))
                return 3
        report, selected=assess(a.hostname,a.inventory,a.roles,a.manifest,a.only)
        if selected!=groups or report['manifest-sha256']!=tx.digest(raw_manifest):
            raise ValueError('selection changed')
        if a.checkpoint_save:
            if not clean(report):
                print(json.dumps(result('CHECKPOINT_REFUSED',report,None),sort_keys=True,indent=2))
                return 3
            data=tx.encoded({'format':FORMAT,'scope':'FIXTURE_STATIC_ONLY','report':report})
            save_new(path,data,tx)
            digest=tx.digest(data)
            status='CHECKPOINT_SAVED'
        else:
            if collector.private(str(path),tx,owner)!=data:
                raise ValueError('checkpoint changed during assessment')
            digest=a.expect_checkpoint
            if saved['report']['context']!=report['context']:
                status='CONTEXT_CHANGED'
            elif any(v['status']=='INSPECTION_BLOCKED' for v in report['groups'].values()):
                status='INSPECTION_BLOCKED'
            elif any(v['status']=='OPEN_JOURNAL' for v in report['groups'].values()):
                status='RECOVERY_REVIEW_REQUIRED'
            elif not clean(report) or saved['report']!=report:
                status='EVIDENCE_CHANGED'
            else:
                status='CHECKPOINT_MATCH_REVIEW_ONLY'
        print(json.dumps(result(status,report,digest),sort_keys=True,indent=2))
        return 0 if status in ('CHECKPOINT_SAVED','CHECKPOINT_MATCH_REVIEW_ONLY') else 3
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError,RecursionError):
        print('checkpoint: invalid, changed or unavailable context; no execution authorized',file=sys.stderr)
        return 2


if __name__=='__main__':
    sys.exit(main())
