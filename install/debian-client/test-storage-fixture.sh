#!/bin/sh
# Static configuration fixture only; no mount, unmount, AutoFS or systemd command.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Storage fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Storage fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, json, os, pathlib, subprocess, sys, tempfile
from copy import deepcopy
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('storage_fixture',here/'fixture-storage.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
planner=m.engine.load('plan-storage'); tx=m.engine.transaction(m.NAMES)
pkg=m.engine.load('plan-packages')
stages=pkg.select_profile(pkg.candidates(here/'package-policy.tsv'),here/'package-profiles.tsv','server')
base='# distribution comment\nUUID=root / ext4 defaults 0 1\nUUID=home\t/home ext4 defaults  0 2\nUUID=var /var ext4 defaults 0 2\n/swap none swap sw 0 0\n'
shares='name\tserver\texport\tmode\nprojects\tfiles.lab.invalid\t/export/projects\tmanual\ninstall\tfiles.lab.invalid\t/export/install\ton-demand\n'
value={'fstab':base,'mountinfo':'1 0 8:1 / / rw - ext4 /dev/fake rw\n',
       'autofs_targets':['/net'],'harden':['/home','/var'],'shares':shares}
desired=m.model(value,stages,planner)
assert b'UUID=home\t/home ext4 defaults,nodev,nosuid,noexec  0 2\n' in desired
assert b'UUID=var /var ext4 defaults,nodev,nosuid 0 2\n' in desired
assert desired.startswith(b'# distribution comment\nUUID=root / ext4 defaults 0 1\n')
assert b'/swap none swap sw 0 0\n' in desired
assert b'ro,nosuid,nodev,noexec,hard,_netdev,vers=4,noauto' in desired
assert b'x-systemd.automount' in desired
def reject(change, s=stages):
    candidate=deepcopy(value); change(candidate)
    try: m.model(candidate,s,planner)
    except ValueError: return
    raise AssertionError('unsafe storage request accepted')
reject(lambda v:v['harden'].append('/tmp'))
reject(lambda v:v['harden'].append('/'))
reject(lambda v:v['harden'].append('/home'))
reject(lambda v:v.update(fstab=base+'UUID=other /home ext4 defaults 0 2\n'))
reject(lambda v:v.update(fstab=base.replace('ext4 defaults  0','ext4 defaults,exec  0')))
reject(lambda v:v.update(fstab=base.replace('ext4 defaults  0','ext4 defaults,unknown  0')))
reject(lambda v:v.update(fstab=base.replace('ext4 defaults  0','ext4 defaults,ro,rw  0')))
reject(lambda v:v.update(fstab=base.replace('ext4 defaults  0','nfs defaults  0')))
reject(lambda v:v.update(fstab=base.replace('/home ext4','/home/../home ext4')))
reject(lambda v:v.update(fstab=base+'UUID=other /mnt/sasd ext4 defaults 0 2\n'))
reject(lambda v:v.update(fstab=base+'foreign:/export /mnt/sasd/projects nfs defaults 0 0\n'))
reject(lambda v:v.update(mountinfo=v['mountinfo']+'2 1 8:2 / /mnt/sasd rw - ext4 /dev/fake2 rw\n'))
reject(lambda v:v.update(mountinfo='invalid'))
reject(lambda v:v['autofs_targets'].append('/mnt/sasd'))
reject(lambda v:v['autofs_targets'].append('/home/child'))
reject(lambda v:v.update(shares=shares.replace('manual','rw')))
reject(lambda v:None,{'1':[],'2':[]})
repeat=dict(value,fstab=desired.decode('ascii'))
assert m.model(repeat,stages,planner)==desired
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    fstab=etc/'fstab'; fstab.write_text(base); fstab.chmod(0o644)
    keep=etc/'auto.master'; keep.write_text('/net /etc/auto.net\n')
    request=root/'request.json'; request.write_bytes(tx.encoded(value)); request.chmod(0o600)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    cmd=[str(here/'fixture-storage.py'),'--root='+name,'--hostname=node.lab.invalid',
         '--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    def review():
        r=run('--review'); assert r.returncode==0,r.stderr
        ref.write_text(r.stdout); ref.chmod(0o600)
        return json.loads(r.stdout)
    approved=review(); opt='--reference='+str(ref); owner=os.geteuid()
    original=tx.snapshot(etc,owner)
    target={'fstab':{'data':desired.hex(),'mode':0o644}}
    assert run('--verify',opt).returncode==1
    request.write_bytes(tx.encoded(value)+b' ')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    request.write_bytes(tx.encoded(value))
    fstab.write_text(base+'# changed\n')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    fstab.write_text(base)
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,
                             'original':original,'desired':target},'APPLYING',owner)
    tx.atomic_write(fstab,desired,0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==original
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_STORAGE_FIXTURE' in r.stdout
    assert fstab.read_bytes()==desired and run('--verify',opt).returncode==0
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==2
    request.write_bytes(tx.encoded(repeat)); review()
    inode=fstab.stat().st_ino
    assert run('--apply-fixture',opt).returncode==0 and fstab.stat().st_ino==inode
    assert keep.read_text()=='/net /etc/auto.net\n'
    assert run('--verify',opt).returncode==0
    request.unlink(); request.symlink_to(keep)
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Storage fstab fixture, conflict and recovery tests passed')
PY
