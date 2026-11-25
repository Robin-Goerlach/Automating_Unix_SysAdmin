#!/bin/sh
# Candidate and inventory-bound observation tests; never start or stop a service.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Core service test SKIPPED: python3 unavailable'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, pathlib, subprocess, sys, tempfile
from types import SimpleNamespace
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('services',here/'plan-services.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def render(task):
    p=next((here/'tasks').glob(task+'_*'))
    return subprocess.check_output([str(p),'--hostname=node.lab.invalid','--render'],text=True)
def reject(fn):
    try: fn()
    except ValueError: return
    raise AssertionError('unexpected success')
assert 'REVIEW_DISABLE' in render('0300') and 'KEEP_UNCHANGED' in render('0300')
assert 'local5' in render('0410') and 'createDirs="off"' in render('0410')
assert '/var/log/sasd/client.log' in render('0410') and '/var/log/sasd/client.log' in render('0420')
assert 'create 0640 root adm' in render('0420') and 'copytruncate' not in render('0420')
assert '/etc/cron.allow\tKEEP_UNCHANGED' in render('0510')
assert 'REUSE_DISTRIBUTION_SCHEDULE' in render('0960') and '/usr/sbin/logwatch' not in render('0960')
assert 'ENABLED="true"' in render('0790') and 'MailTo = root@localhost' in render('0800')
rows=render('0710'); allowed={'REVIEW_ENABLE'}
assert len(m.service_rows(rows,'baseline',allowed))==1
assert len(m.service_rows(rows,'workstation',allowed))==4
assert len(m.service_rows(rows,'server',allowed))==4
reject(lambda:m.service_rows(rows+'server\tcron\tcron.service\tREVIEW_ENABLE\n','server',allowed))
reject(lambda:m.service_rows(rows.replace('cron.service','--bad.service'),'server',allowed))
assert m.unit_state('LoadState=loaded\nActiveState=active\nUnitFileState=enabled\n')==('loaded','active','enabled')
reject(lambda:m.unit_state('LoadState=loaded\nActiveState=active\n'))
reject(lambda:m.unit_state('LoadState=loaded\nActiveState=active\nUnitFileState=enabled\nActiveState=inactive\n'))
module=m.package_planner(); calls=[]
def fake(*args):
    calls.append(args)
    return SimpleNamespace(returncode=0,stderr='',stdout='ii \t1\n' if args[0].endswith('dpkg-query') else 'LoadState=loaded\nActiveState=active\nUnitFileState=enabled\n')
module.command=fake
assert m.observe(module,'cron','cron.service')==('INSTALLED','loaded','active','enabled')
assert calls[1][1]=='show' and calls[1][-1]=='cron.service'
module.command=lambda *args:SimpleNamespace(returncode=1,stderr='unavailable',stdout='')
assert m.observe(module,'cron','cron.service')==('UNKNOWN',)*4
with tempfile.TemporaryDirectory() as tmp:
    inv=pathlib.Path(tmp)/'hosts'; roles=pathlib.Path(tmp)/'roles'
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\nlaptop\tsite_laptop\tmodern\troles/laptop.tsv\nserver\tsite_server\tmodern\troles/server.tsv\n')
    def run(profile,role):
        inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\t'+role+'\t\t'+profile+'\n')
        return subprocess.run([str(here/'plan-services.py'),'--list','--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)],capture_output=True,text=True)
    r=run('baseline','workstation'); assert r.returncode==0 and 'cron.service\tREVIEW_ENABLE\tNOT_SELECTED' in r.stdout and 'rsyslog.service' not in r.stdout
    r=run('laptop','laptop'); assert r.returncode==0 and 'ModemManager.service\tKEEP_UNCHANGED' in r.stdout and 'cups.service\tREVIEW_ENABLE\tSELECTED' in r.stdout and 'ssh.service' not in r.stdout
    r=run('server','server'); assert r.returncode==0 and 'ssh.service\tREVIEW_ENABLE\tSELECTED' in r.stdout and 'cups.service' not in r.stdout
    assert 'service-apply\tNOT_AUTHORIZED' in r.stdout and 'runtime-identity\tNOT_VERIFIED' in r.stdout
    assert run('unknown','server').returncode==2
print('Core service policy and observation tests passed')
PY
