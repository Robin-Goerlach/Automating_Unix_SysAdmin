#!/bin/sh
# Offline baseline comparison and policy review; no security scanners are executed.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Audit planning test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Audit planning test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, pathlib, subprocess, sys, tempfile
from types import SimpleNamespace
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('audits',here/'plan-audits.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); root=p/'snapshot'; root.mkdir(mode=0o700)
    for name in m.NAMES:
        (root/name).write_text('synthetic '+name+'\n'); (root/name).chmod(0o640)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    cmd=[str(here/'plan-audits.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args):
        return subprocess.run([*cmd,*args],capture_output=True,text=True)
    snap='--snapshot='+str(root); compare='--reference='+str(ref)
    r=run('--list'); assert r.returncode==0 and 'package\taide\tNOT_SELECTED\tNOT_RUN' in r.stdout
    assert 'scanner-execution\tNOT_RUN' in r.stdout and 'aide-baseline\tNOT_APPROVED' in r.stdout
    r=run(snap); assert r.returncode==0 and r.stdout.startswith(m.HEADER+'\n')
    assert 'synthetic' not in r.stdout
    ref.write_text(r.stdout); ref.chmod(0o600); original=r.stdout
    r=run(snap,compare); assert r.returncode==0 and r.stdout.count('\tMATCH')==4
    (root/'hostname').write_text('changed\n'); (root/'hosts').chmod(0o600)
    r=run(snap,compare); assert r.returncode==1 and 'hostname\tDRIFT' in r.stdout and 'hosts\tDRIFT' in r.stdout
    assert 'rsyslog.conf\tMATCH' in r.stdout and 'integrity-apply\tNOT_AUTHORIZED' in r.stdout
    for bad in (original.replace('node.lab.invalid','other.lab.invalid'),original.replace('hosts\t640','hostname\t640'),original+'extra\n'):
        ref.write_text(bad); assert run(snap,compare).returncode==2
    ref.write_text(original)
    (root/'hostname').unlink(); (root/'hostname').symlink_to(root/'hosts')
    assert run(snap).returncode==2
    (root/'hostname').unlink(); (root/'hostname').hardlink_to(root/'hosts')
    assert run(snap).returncode==2
    (root/'hostname').unlink(); assert run(snap).returncode==2
    assert run('--list',compare).returncode==2
    assert ref.read_text()==original
    r=run('--live'); assert r.returncode==3 and 'audit-apply\tNOT_AUTHORIZED' in r.stdout
module=m.load('plan-packages')
module.command=lambda *args:SimpleNamespace(returncode=0,stderr='',stdout='ii \t1\n')
assert m.package_state(module,'aide')=='INSTALLED'
module.command=lambda *args:SimpleNamespace(returncode=1,stderr='unavailable',stdout='')
assert m.package_state(module,'aide')=='UNKNOWN'
for task in ('0750','0760','0770','0780','0920','0930','0940','0950','1000','1040'):
    f=next((here/'tasks').glob(task+'_*'))
    r=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True)
    assert r.returncode==0 and r.stdout and not r.stderr
print('Security audit planning and offline baseline tests passed')
PY
