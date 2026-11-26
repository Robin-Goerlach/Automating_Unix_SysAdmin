#!/bin/sh
# Offline operations policy and parser checks; no jobs or daemons are activated.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Operations test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Operations test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('ops',here/'plan-operations.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
assert dict(m.periodic('APT::Periodic::Enable "1";\nAPT::Periodic::Unattended-Upgrade "0";\n'))['Enable']=='1'
assert dict(m.periodic('APT::Periodic::Enable "1";\napt::periodic::enable "0";'))['Enable']=='REVIEW_REQUIRED'
assert dict(m.periodic('APT::Periodic::Enable "2";'))['Enable']=='REVIEW_REQUIRED'
assert dict(m.periodic('APT::Periodic::Update-Package-Lists "always";'))['Update-Package-Lists']=='REVIEW_REQUIRED'
assert dict(m.periodic('APT::Periodic::Update-Package-Lists "366";'))['Update-Package-Lists']=='REVIEW_REQUIRED'
assert dict(m.periodic('APT::Periodic::Update-Package-Lists "7";'))['Update-Package-Lists']=='7'
assert dict(m.periodic('APT::Periodic::Enable::Other "1";'))['Enable']=='REVIEW_REQUIRED'
assert dict(m.periodic('Acquire::http::Proxy "fixture-private";'))['Enable']=='NOT_EXPLICIT'
for a,b,w in [('active','active','BOTH_ACTIVE_REVIEW'),('active','inactive','RSYSLOG_ACTIVE_OBSERVED'),('inactive','active','SYSLOG_NG_ACTIVE_REVIEW'),('inactive','inactive','NEITHER_ACTIVE_OBSERVED'),('active','UNKNOWN','UNKNOWN_OR_TRANSITIONAL')]:
    assert m.log_state({'rsyslog.service':a,'syslog-ng.service':b})==w
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); inv=p/'hosts'; roles=p/'roles'; capture=p/'apt'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tworkstation\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    data='APT::Periodic::Enable "1";\nAPT::Periodic::Update-Package-Lists "7";\nAcquire::http::Proxy "fixture-private";\n'
    capture.write_text(data)
    cmd=[str(here/'plan-operations.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    q=run('--list'); assert q.returncode==0 and 'package\tcups\tSELECTED\tNOT_RUN' in q.stdout
    q=run('--apt-capture='+str(capture)); assert q.returncode==3
    assert 'apt-periodic\tUpdate-Package-Lists\t7' in q.stdout and 'apt-periodic\tUnattended-Upgrade\tNOT_EXPLICIT' in q.stdout
    assert 'operations-apply\tNOT_AUTHORIZED' in q.stdout and 'fixture-private' not in q.stdout+q.stderr
    assert capture.read_text()==data
    capture.unlink(); capture.symlink_to(inv); assert run('--apt-capture='+str(capture)).returncode==2
    q=run('--live'); assert q.returncode==3 and 'update-schedule\tNOT_VERIFIED' in q.stdout
for task in ('0380','0470','0830','0900','0910','1020'):
    f=next((here/'tasks').glob(task+'_*'))
    q=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True)
    assert q.returncode==0 and q.stdout and not q.stderr
print('Operations policy and periodic configuration tests passed')
PY
