#!/bin/sh
# Verify all task mappings and journal bounds without applying to a live host.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
[ -x /usr/bin/python3 ] || { echo 'Consolidation test SKIPPED: python3 unavailable'; exit 0; }
/usr/bin/python3 -B - "$here" <<'PY'
import collections, importlib.util, os, pathlib, shutil, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('dispatch',here/'fixture-dispatch.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
rows=m.coverage()
assert len(rows)==116
assert collections.Counter(r[4] for r in rows)=={
    'EXPERIMENTAL_BASELINE':3,'CONFIG_FIXTURE':23,'STATE_MODEL':4,'POLICY_RECORD':4,
    'VERIFY_ONLY':16,'CANDIDATE_ONLY':39,'CENTRAL':11,'MANUAL':16}
assert all(r[-1]=='NOT_CERTIFIED' for r in rows)
assert sum(e.endswith(':verified') for r in rows for e in r[-2].split(','))==54
assert sum(e.endswith(':candidate') for r in rows for e in r[-2].split(','))==3
cmd=['/bin/sh',str(here/'install-client.sh')]
r=subprocess.run([*cmd,'--coverage'],capture_output=True,text=True)
assert r.returncode==0,r.stderr
assert r.stdout.splitlines()[1:]==['\t'.join(row) for row in rows]
for args in (['--coverage','--review'],['--coverage','--coverage'],
             ['--fixture-group=baseline','--review'],['--fixture-group=../shell','--review'],
             ['--fixture-group=banner','--fixture-group=network','--review'],
             ['--fixture-group=banner','--review','--verify'],
             ['--fixture-group=banner','--review','--only=0460']):
    assert subprocess.run([*cmd,*args],capture_output=True).returncode==2
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp)
    for n in ('checklist.tsv','capabilities.tsv','dependencies.tsv'):
        shutil.copyfile(here/n,p/n)
    for group in m.GROUPS:
        if group!='baseline': (p/('fixture-'+group+'.py')).touch()
    assert m.coverage(p)==rows
    def reject(name, content):
        target=p/name; original=target.read_text(); target.write_text(content)
        try:
            try: m.coverage(p)
            except ValueError: return
            raise AssertionError('invalid catalog accepted')
        finally: target.write_text(original)
    reject('capabilities.tsv',(p/'capabilities.tsv').read_text().replace('BANNER_FIXTURE','UNKNOWN_BACKEND'))
    reject('dependencies.tsv',(p/'dependencies.tsv').read_text()+'0020\t0030\tverified\n')
    reject('checklist.tsv',(p/'checklist.tsv').read_text().replace('0010\t','0020\t',1))
    (p/'fixture-banner.py').unlink()
    try: m.coverage(p)
    except ValueError: pass
    else: raise AssertionError('missing backend accepted')
if os.geteuid()!=0:
    spec=importlib.util.spec_from_file_location('native',here/'native-install.py')
    tx=importlib.util.module_from_spec(spec); spec.loader.exec_module(tx)
    tx.NAMES=tuple('file'+str(i) for i in range(5))
    with tempfile.TemporaryDirectory() as tmp:
        p=pathlib.Path(tmp); etc=p/'etc'; store=p/'transactions'
        etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
        for n in tx.NAMES:
            (etc/n).write_bytes(b'a'*65536); (etc/n).chmod(0o644)
        owner=os.geteuid(); old=tx.snapshot(etc,owner)
        desired={n:{'data':(b'b'*65536).hex(),'mode':0o644} for n in tx.NAMES}
        ref={'original':tx.digest(tx.encoded(old)), 'desired':tx.digest(tx.encoded(desired))}
        try: tx.transition(etc,store,owner,ref,old,desired,lambda: True)
        except ValueError: pass
        else: raise AssertionError('oversized journal accepted')
        assert not list(store.iterdir()) and tx.snapshot(etc,owner)==old
else:
    print('Oversized journal test SKIPPED: root')
print('All-task coverage, dispatcher and journal bound tests passed')
PY
