#!/bin/sh
# Capability coverage and real private two-file banner transactions; no live writes.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
[ -x /usr/bin/python3 ] || { echo 'Banner test SKIPPED: python3 unavailable'; exit 0; }
/usr/bin/python3 -B - "$here" <<'PY'
import csv, importlib.util, json, os, pathlib, subprocess, sys, tempfile
from collections import Counter
here=pathlib.Path(sys.argv[1])
def rows(name):
    with (here/name).open() as f:
        return list(csv.DictReader(f,delimiter='\t'))
catalog=rows('checklist.tsv'); matrix=rows('capabilities.tsv')
assert len(matrix)==len(catalog)==116
assert [(r['id'],r['task']) for r in matrix]==[(r['id'],r['task']) for r in catalog]
assert Counter(r['artifact'] for r in matrix)=={'CONFIG_TEXT':16,'PACKAGE_LIST':2,'REVIEW_TSV':71,'CENTRAL':11,'MANUAL':16}
assert [r['id'] for r in matrix if r['apply'] not in ('NOT_IMPLEMENTED','OPERATOR_REQUIRED')]==['0010','0030','0040','0050','0190','0200','0210','0250','0270','0300','0330','0360','0400','0410','0420','0430','0450','0460','0480','0490','0500','0550','0570','0580','0590','0630','0670','0710','0730','0790','0800']
if os.geteuid()==0:
    print('Capability coverage passed; fixture transaction SKIPPED: root')
    sys.exit(0)
spec=importlib.util.spec_from_file_location('banner',here/'fixture-banner.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
with tempfile.TemporaryDirectory(prefix='sasd-banner-lab.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux)
    etc=root/'etc'; store=root/'transactions'; etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
    marker=root/'.sasd-banner-fixture'; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    for n in m.NAMES:
        (etc/n).write_text('old '+n+'\n'); (etc/n).chmod(0o644)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    cmd=[str(here/'fixture-banner.py'),'--root='+name,'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    r=run('--review'); assert r.returncode==0,r.stderr
    ref.write_text(r.stdout); ref.chmod(0o600)
    opt='--reference='+str(ref)
    assert run('--verify',opt).returncode==1
    tx=m.transaction(); owner=os.geteuid()
    old=tx.snapshot(etc,owner)
    approved=json.loads(ref.read_text())
    (etc/'issue').write_text('changed\n')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    (etc/'issue').write_bytes(bytes.fromhex(old['issue']['data']))
    # Exercise open-journal recovery after a real first-file mutation.
    desired={n:{'data':b'Unauthorized access is prohibited.\n'.hex(),'mode':0o644} for n in m.NAMES}
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,'original':old,'desired':desired},'APPLYING',owner)
    tx.atomic_write(etc/'issue',bytes.fromhex(desired['issue']['data']),0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==old
    assert tx.load_journal(journal,owner)['state']=='ROLLED_BACK'
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert tx.snapshot(etc,owner)==desired and run('--verify',opt).returncode==0
    assert len(list(store.iterdir()))==2
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==2
    assert run('--review').returncode==0
    (etc/'issue.net').chmod(0o600)
    assert run('--review').returncode==2
    (etc/'issue.net').chmod(0o644)
    inv.write_text('node.lab.invalid\t192.0.2.41\tdebian\tworkstation\t\tbaseline\n')
    assert run('--verify',opt).returncode==2
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    (etc/'issue.net').unlink(); (etc/'issue.net').symlink_to(etc/'issue')
    assert run('--review').returncode==2
    (etc/'issue.net').unlink(); (etc/'issue.net').hardlink_to(etc/'issue')
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Capability coverage and banner fixture transaction tests passed')
PY
