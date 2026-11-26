#!/bin/sh
# Service/schedule model and private transactions only, no systemctl or cron writes.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Service fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Service fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, json, os, pathlib, subprocess, sys, tempfile
from copy import deepcopy
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('service_fixture',here/'fixture-services.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tx=m.engine.transaction(m.NAMES); owner=os.geteuid()
host='node.lab.invalid'
policy=m.policies(host,'server',tx)
on=['loaded','active','enabled']; off=['loaded','inactive','disabled']
value={'installed':['cron','modemmanager','logwatch','aide','openssh-server'],
       'units':{'cron.service':off,'ModemManager.service':on,'ssh.service':off,'other.service':on},
       'actions':{'cron.service':'enable','ModemManager.service':'disable'},
       'schedules':[['logwatch','cron:daily-logwatch',True],['aide','timer:aide.timer',True],
                    ['aide','cron:old-aide',False],['unrelated','cron:other',True]],
       'selection':{},'adopt':['logwatch','aide']}
desired, selected=m.model(value,'server',policy)
assert desired['cron.service']==on and desired['ModemManager.service']==off
assert desired['ssh.service']==off and desired['other.service']==on
assert selected=={'logwatch':'cron:daily-logwatch','aide':'timer:aide.timer'}
def reject(change, profile='server', p=policy):
    candidate=deepcopy(value); change(candidate)
    try: m.model(candidate,profile,p)
    except ValueError: return
    raise AssertionError('invalid service request accepted')
reject(lambda v:v['installed'].remove('cron'))
reject(lambda v:v['actions'].update({'other.service':'disable'}))
reject(lambda v:v['actions'].update({'ssh.service':'disable'}))
reject(lambda v:v['units'].update({'cron.service':['loaded','inactive','masked']}))
reject(lambda v:v['units'].update({'cron.service':['loaded','activating','enabled']}))
reject(lambda v:v['schedules'].append(['logwatch','timer:logwatch.timer',True]))
reject(lambda v:v['schedules'].append(v['schedules'][0]))
reject(lambda v:v['selection'].update({'aide':'cron:old-aide'}))
reject(lambda v:v['adopt'].append('unrelated'))
reject(lambda v:v['adopt'].append('aide'))
reject(lambda v:v['actions'].pop('cron.service'))
def missing_cron(v):
    v['actions'].pop('cron.service')
    v['units']['cron.service']=on
    v['installed'].remove('cron')
reject(missing_cron)
reject(lambda v:None,'laptop',m.policies(host,'laptop',tx))
reject(lambda v:None,'workstation',m.policies(host,'workstation',tx))
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    for n,state in zip(m.NAMES,(value['units'],value['selection'])):
        (etc/n).write_bytes(tx.encoded(state)); (etc/n).chmod(0o644)
    keep=etc/'cron.allow'; keep.write_text('synthetic-admin\n')
    request=root/'request.json'; request.write_bytes(tx.encoded(value)); request.chmod(0o600)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text(host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    cmd=[str(here/'fixture-services.py'),'--root='+name,'--hostname='+host,
         '--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    def review():
        r=run('--review'); assert r.returncode==0,r.stderr
        ref.write_text(r.stdout); ref.chmod(0o600)
        return json.loads(r.stdout)
    approved=review(); opt='--reference='+str(ref)
    original=tx.snapshot(etc,owner)
    target={n:{'data':tx.encoded(state).hex(),'mode':0o644}
            for n,state in zip(m.NAMES,(desired,selected))}
    assert run('--verify',opt).returncode==1
    request.write_bytes(tx.encoded(value)+b' ')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    request.write_bytes(tx.encoded(value))
    (etc/m.NAMES[1]).write_text('{"foreign":"timer:foreign"}\n')
    assert run('--apply-fixture',opt).returncode==2
    (etc/m.NAMES[1]).write_bytes(tx.encoded(value['selection']))
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,
                             'original':original,'desired':target},'APPLYING',owner)
    tx.atomic_write(etc/m.NAMES[0],tx.encoded(desired),0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==original
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_SERVICE_FIXTURE' in r.stdout
    assert tx.snapshot(etc,owner)==target and run('--verify',opt).returncode==0
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==2
    # Re-review after commit, all already-correct files retain inode on repeat.
    value['units']=desired; value['selection']=selected
    request.write_bytes(tx.encoded(value)); review()
    before=[(etc/n).stat().st_ino for n in m.NAMES]
    assert run('--apply-fixture',opt).returncode==0
    assert before==[(etc/n).stat().st_ino for n in m.NAMES]
    assert keep.read_text()=='synthetic-admin\n'
    assert run('--verify',opt).returncode==0
    request.unlink(); request.symlink_to(keep)
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Service fixture transitions, schedule reuse and recovery tests passed')
PY
