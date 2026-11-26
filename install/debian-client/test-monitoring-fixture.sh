#!/bin/sh
# Synthetic hardware only; never probe devices, enroll, sign or send previews.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Monitoring fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Monitoring fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, json, os, pathlib, subprocess, sys, tempfile
from copy import deepcopy
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('monitoring_fixture',here/'fixture-monitoring.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tx=m.engine.transaction(m.NAMES); monitor=m.engine.load('plan-monitoring')
pkg=m.engine.load('plan-packages'); host='node.lab.invalid'
old=dict.fromkeys(m.NAMES,'')
value={'original':old,'checks':'client-smart\t*\tSMART review\nclient-temp\tworkstation\tTemperature review\n',
       'select':['client-smart','client-temp'],
       'smart':{'device':{'protocol':'ATA'},'smartctl':{'exit_status':8},
                'smart_status':{'passed':False},'serial_number':'private-fixture'},
       'sensors':{'chip-private':{'sensor':{'temp1_input':75,'temp1_max':70,'temp1_crit':90}}},
       'hardware':{'kernel':'6.1.0-fixture','architecture':'x86_64','logical_cpus':4,'mount_count':3}}
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700); (etc/'sasd-monitoring').mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    for n,data in old.items():
        (etc/n).write_text(data); (etc/n).chmod(0o644)
    keep=etc/'snmpd.conf'; keep.write_text('# existing synthetic config\n')
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text(host+'\t192.0.2.40\tdebian\tworkstation\t\tworkstation\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    profile,stages,context=pkg.inventory_selection(host,str(inv),str(roles))
    def model(v,s=stages):
        return m.model(v,host,profile,s,context,monitor,tx)
    desired=model(value)
    rows=desired[m.NAMES[0]].decode().splitlines()
    assert [r.split('\t')[2] for r in rows]==['red','yellow']
    assert all(len(r.split('\t'))==4 and r.startswith(host+'\t') and
               'preview not authenticated' in r for r in rows)
    handoff=json.loads(desired[m.NAMES[1]])
    assert handoff['role']=='workstation' and handoff['enrollment']=='NOT_REQUESTED'
    assert handoff['authentication']=='NOT_VERIFIED' and handoff['transport']=='NOT_RUN'
    assert handoff['hardware-review']['logical_cpus']==4
    assert all(x not in b''.join(desired.values()) for x in (b'private-fixture',b'chip-private'))
    def reject(change,s=stages):
        v=deepcopy(value); change(v)
        try: model(v,s)
        except (ValueError,RuntimeError): return
        raise AssertionError('unsafe monitoring request accepted')
    reject(lambda v:v['select'].append('client-smart'))
    reject(lambda v:v['select'].append('unknown'))
    reject(lambda v:v.update(select=['client-smart']))
    reject(lambda v:v.update(checks='disk\t*\tDisk\n'))
    reject(lambda v:v.update(checks=v['checks'].replace('workstation','server')))
    reject(lambda v:v.update(checks=v['checks']+v['checks']))
    reject(lambda v:None,{'1':[],'2':[]})
    reject(lambda v:v['hardware'].update(serial='never'))
    reject(lambda v:v['hardware'].update(logical_cpus=True))
    reject(lambda v:v['smart']['smartctl'].update(exit_status=True))
    reject(lambda v:v['original'].update({m.NAMES[0]:'different preview\n'}))
    absent=deepcopy(value); absent['smart']=None; absent['sensors']=None
    assert model(absent)[m.NAMES[0]].count(b'\tpurple\t')==2
    repeat=dict(value,original={n:data.decode('ascii') for n,data in desired.items()})
    assert model(repeat)==desired
    request=root/'request.json'; request.write_bytes(tx.encoded(value)); request.chmod(0o600)
    cmd=[str(here/'fixture-monitoring.py'),'--root='+name,'--hostname='+host,
         '--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    def review():
        r=run('--review'); assert r.returncode==0,r.stderr
        ref.write_text(r.stdout); ref.chmod(0o600)
        return json.loads(r.stdout)
    approved=review(); opt='--reference='+str(ref); owner=os.geteuid()
    original=tx.snapshot(etc,owner)
    target={n:{'data':data.hex(),'mode':0o644} for n,data in desired.items()}
    assert run('--verify',opt).returncode==1
    request.write_bytes(tx.encoded(value)+b' ')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    request.write_bytes(tx.encoded(value))
    (etc/m.NAMES[0]).write_text('drift\n')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    (etc/m.NAMES[0]).write_text('')
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,
                             'original':original,'desired':target},'APPLYING',owner)
    tx.atomic_write(etc/m.NAMES[0],desired[m.NAMES[0]],0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==original
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_MONITORING_FIXTURE' in r.stdout
    assert tx.snapshot(etc,owner)==target and run('--verify',opt).returncode==0
    assert run('--apply-fixture',opt).returncode==2
    request.write_bytes(tx.encoded(repeat)); review()
    before=[(etc/n).stat().st_ino for n in m.NAMES]
    assert run('--apply-fixture',opt).returncode==0
    assert before==[(etc/n).stat().st_ino for n in m.NAMES]
    assert keep.read_text()=='# existing synthetic config\n'
    assert run('--verify',opt).returncode==0
    request.unlink(); request.symlink_to(keep)
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Monitoring fixture and canonical SASD status compatibility tests passed')
PY
