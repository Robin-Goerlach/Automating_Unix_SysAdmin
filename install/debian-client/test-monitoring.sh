#!/bin/sh
# Offline hardware captures, no device scans or service activation.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Monitoring test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Monitoring test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, json, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('monitoring',here/'plan-monitoring.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def smart(rc, passed, protocol='ATA'):
    return {'device':{'protocol':protocol},'smartctl':{'exit_status':rc},'smart_status':{'passed':passed},'serial_number':'fixture-private'}
for rc,passed,color in [(0,True,'green'),(0,False,'red'),(2,True,'purple'),(8,True,'red'),(10,True,'red'),(64,True,'yellow')]:
    assert m.smart_result(smart(rc,passed))[0]==color
assert m.smart_result(smart(0,True,'NVMe'))[0]=='purple'
assert m.smart_result({'device':{'protocol':'ATA'},'smartctl':{'exit_status':0}})[0]=='purple'
def sensor(temp):
    return {'fixture-chip':{'Adapter':'fixture','sensor':{'temp1_input':temp,'temp1_max':70,'temp1_crit':90}}}
for temp,color in [(40,'green'),(75,'yellow'),(90,'red')]:
    assert m.sensor_result(sensor(temp))[0]==color
assert m.sensor_result({'chip':{'sensor':{'temp1_input':40}}})[0]=='purple'
assert m.sensor_result({})[0]=='purple'
def reject(fn):
    try: fn()
    except (ValueError,OSError): return
    raise AssertionError('unexpected success')
reject(lambda:m.smart_result(smart(True,True)))
reject(lambda:m.smart_result(smart(0,'true')))
reject(lambda:m.sensor_result({'chip':{'sensor':{'temp1_input':40,'temp1_max':90,'temp1_crit':80}}}))
reject(lambda:m.sensor_result({'chip':{'sensor':{'temp1_input':True}}}))
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); inv=p/'hosts'; roles=p/'roles'; disk=p/'smart'; temps=p/'sensors'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tworkstation\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    cmd=[str(here/'plan-monitoring.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args):
        return subprocess.run([*cmd,*args],capture_output=True,text=True)
    disk.write_text(json.dumps(smart(8,False))); temps.write_text(json.dumps(sensor(75)))
    opts=['--capture','--smart-json='+str(disk),'--sensors-json='+str(temps)]
    r=run('--list'); assert r.returncode==0 and 'smartmontools\tSELECTED\tNOT_RUN' in r.stdout
    r=run(*opts); assert r.returncode==3 and 'capture\tclient-smart\tred' in r.stdout and 'capture\tclient-temp\tyellow' in r.stdout
    assert 'monitoring-apply\tNOT_AUTHORIZED' in r.stdout and 'fixture-private' not in r.stdout and 'fixture-chip' not in r.stdout
    r=run(*opts,'--status-preview'); assert r.returncode==3
    rows=[l.split('\t') for l in r.stdout.splitlines()]
    assert len(rows)==2 and all(len(row)==4 and row[0]=='node.lab.invalid' and 'preview not authenticated' in row[3] and len(row[3])<=240 for row in rows)
    assert [row[2] for row in rows]==['red','yellow']
    r=run('--capture','--status-preview'); assert r.returncode==3 and r.stdout.count('\tpurple\t')==2
    assert run('--list','--status-preview').returncode==2
    disk.write_text('{"a":1,"a":2}'); assert run(*opts).returncode==2
    disk.write_text('{"a":NaN}'); assert run(*opts).returncode==2
    disk.unlink(); disk.symlink_to(temps); assert run(*opts).returncode==2
    r=run('--live'); assert r.returncode==3 and 'rng-health\tNOT_VERIFIED' in r.stdout
for task in ('0530','0540','0740','0820','0840','0890'):
    f=next((here/'tasks').glob(task+'_*'))
    r=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True)
    assert r.returncode==0 and r.stdout and not r.stderr
print('Monitoring policy and hardware capture tests passed')
PY
