#!/bin/sh
# Test only captured data and local read-only inventory; never mount a share.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Storage test SKIPPED: python3 unavailable'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('storage',here/'plan-storage.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def reject(fn):
    try: fn()
    except ValueError: return
    raise AssertionError('unexpected success')
base='UUID=fixture / ext4 defaults 0 1\nUUID=home /home ext4 defaults,nodev,nosuid,noexec 0 2\n'
mount='1 0 8:1 / / rw - ext4 /dev/fake rw\n'
shares='name\tserver\texport\tmode\nprojects\tfiles.lab.invalid\t/export/projects\tmanual\ninstall\tfiles.lab.invalid\t/export/install\ton-demand\n'
assert m.fstab_rows(base)[1][0]=='/home'
assert m.fstab_rows(r'UUID=x /mnt/a\040b ext4 defaults 0 0')[0][0]=='/mnt/a b'
reject(lambda:m.fstab_rows('not a record'))
reject(lambda:m.fstab_rows(r'UUID=x /mnt/a\999 ext4 defaults 0 0'))
assert m.mount_rows(mount)[0][0]=='/'
reject(lambda:m.mount_rows('invalid'))
for bad in (shares+shares.splitlines()[1]+'\n',shares.replace('/export/projects','/export/../projects'),shares.replace('projects\t','../projects\t',1),shares.replace('files.lab.invalid','bad;host'),shares.replace('manual','rw')):
    reject(lambda:m.share_rows(bad))
rows=m.share_rows(shares)
assert 'hard,_netdev,vers=4,noauto' in m.candidate(rows[0]) and 'ro,nosuid,nodev,noexec' in m.candidate(rows[0])
assert 'x-systemd.automount' in m.candidate(rows[1]) and 'soft' not in m.candidate(rows[1])
assert m.overlap('/mnt/sasd/projects','/mnt/sasd') and m.overlap('/mnt/sasd/projects','/mnt/sasd/projects/child')
assert not m.overlap('/mnt/sasd/projects','/') and not m.overlap('/mnt/sasd/projects','/mnt/sasd/projects2')
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); inv=p/'hosts'; roles=p/'roles'; fs=p/'fstab'; mi=p/'mountinfo'; sh=p/'shares'
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    host='node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tworkstation\n'
    inv.write_text(host); fs.write_text(base); mi.write_text(mount); sh.write_text(shares)
    def run(*args):
        return subprocess.run([str(here/'plan-storage.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles),*args],capture_output=True,text=True)
    opts=['--fstab='+str(fs),'--mountinfo='+str(mi),'--shares='+str(sh)]
    r=run(*opts); assert r.returncode==3 and r.stdout.count('fstab-candidate\t')==2 and '/home\tOPTIONS_PRESENT' in r.stdout
    assert 'storage-apply\tNOT_AUTHORIZED' in r.stdout and 'mountpoint-directory-state\tNOT_CHECKED' in r.stdout
    assert '/dev/fake' not in r.stdout and 'UUID=' not in r.stdout
    r=run(opts[0],opts[2]); assert r.returncode==3 and 'MOUNT_STATE_UNKNOWN' in r.stdout and 'fstab-candidate\t' not in r.stdout
    fs.write_text(base+'server:/export /mnt/sasd/projects nfs defaults 0 0\n'); r=run(*opts); assert 'projects\tCONFLICT' in r.stdout and r.stdout.count('fstab-candidate\t')==1
    fs.write_text(base); mi.write_text(mount+'2 1 8:2 / /mnt/sasd rw - ext4 /dev/fake2 rw\n'); r=run(*opts); assert r.stdout.count('\tCONFLICT')==2 and 'fstab-candidate\t' not in r.stdout
    mi.write_text(mount); inv.write_text(host.replace('\tworkstation\n','\tbaseline\n')); r=run(*opts); assert 'PACKAGE_NOT_SELECTED' in r.stdout and 'fstab-candidate\t' not in r.stdout
    inv.write_text(host); (p/'link').symlink_to(sh); assert run(opts[0],opts[1],'--shares='+str(p/'link')).returncode==2
    assert fs.read_text()==base and mi.read_text()==mount and sh.read_text()==shares
for task in ('0320','0330','0340','0350','0360','0970','1010'):
    f=next((here/'tasks').glob(task+'_*'))
    r=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True)
    assert r.returncode==0 and r.stdout
print('Storage policy, mount capture and inventory tests passed')
PY
