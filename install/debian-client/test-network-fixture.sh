#!/bin/sh
# Private synthetic network configuration; no network, apt or firewall commands.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Network fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Network fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, json, os, pathlib, subprocess, sys, tempfile
from copy import deepcopy
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('network_fixture',here/'fixture-network.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tx=m.engine.transaction(m.NAMES); network=m.engine.load('plan-network')
comms=m.engine.load('plan-communications'); pkg=m.engine.load('plan-packages')
host='node.lab.invalid'
old={m.NAMES[0]:'# distribution\n127.0.0.1 localhost\n127.0.1.1 node.lab.invalid node\n::1 ip6-localhost\n',
     m.NAMES[1]:'',m.NAMES[2]:'',m.NAMES[3]:''}
value={'original':old,'hosts':[['files.lab.invalid','192.0.2.50']],
       'apt':{'release':'12','keyring_present':True,'other_sources':{'sources.list':'# disabled fixture\n'}},
       'proxy':{'host':'proxy.lab.invalid','port':3128},
       'firewall':{'phase':'stage1','owners':['nftables'],'addresses':[{'ifname':'eth0','flags':['UP'],
       'addr_info':[{'family':'inet','local':'192.0.2.40','prefixlen':24,'scope':'global'}]}],
       'routes':[{'dst':'default','gateway':'192.0.2.1','dev':'eth0'}],
       'gateway':'192.0.2.1','management_cidr':'192.0.2.10/32'}}
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
    for folder in m.DIRECTORIES: (etc/folder).mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    for n,data in old.items():
        (etc/n).write_text(data); (etc/n).chmod(0o644)
    keep={'resolv.conf':'nameserver 192.0.2.53\n','nftables.conf':'# existing firewall\n',
          'apt/sources.list':'# disabled fixture\n'}
    for n,data in keep.items(): (etc/n).write_text(data)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text(host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    profile,stages,context=pkg.inventory_selection(host,str(inv),str(roles))
    def model(v, role=profile):
        return m.model(v,host,role,stages,context,network,comms,tx)
    desired=model(value)
    assert desired[m.NAMES[0]]==old[m.NAMES[0]].encode()+b'192.0.2.50\tfiles.lab.invalid\n'
    assert desired[m.NAMES[1]]==network.apt_candidate('12').encode()
    assert b'Acquire::https::Proxy "http://proxy.lab.invalid:3128/";' in desired[m.NAMES[2]]
    policy=json.loads(desired[m.NAMES[3]])
    assert policy['activation']=='NOT_AUTHORIZED' and policy['ipv6']=='KEEP_AND_REVIEW'
    assert policy['management_cidr']=='192.0.2.10/32'
    def reject(change, role=profile):
        v=deepcopy(value); change(v)
        try: model(v,role)
        except ValueError: return
        raise AssertionError('unsafe network request accepted')
    reject(lambda v:v['hosts'].append([host,'192.0.2.60']))
    reject(lambda v:v['hosts'].append(['other.lab.invalid','192.0.2.40']))
    reject(lambda v:v['hosts'].append(v['hosts'][0]))
    reject(lambda v:v['original'].update({m.NAMES[0]:old[m.NAMES[0]]+'192.0.2.99 files.lab.invalid\n'}))
    reject(lambda v:v['apt'].update(release='stable'))
    reject(lambda v:v['apt'].update(keyring_present=False))
    reject(lambda v:v['apt']['other_sources'].update({'sources.list':'deb https://example.invalid stable main\n'}))
    reject(lambda v:v['proxy'].update(host='user:secret@proxy.lab.invalid'))
    reject(lambda v:v['proxy'].update(port=True))
    reject(lambda v:v['firewall'].update(owners=['nftables','iptables']))
    reject(lambda v:v['firewall'].update(management_cidr='0.0.0.0/0'))
    reject(lambda v:v['firewall'].update(gateway='192.0.2.2'))
    reject(lambda v:v['firewall']['routes'].append(v['firewall']['routes'][0]))
    reject(lambda v:None,'workstation')
    reject(lambda v:v['original'].update({m.NAMES[3]:'foreign policy\n'}))
    reject(lambda v:v['firewall'].update(phase='stage2'))
    repeat=dict(value,original={n:data.decode('ascii') for n,data in desired.items()})
    assert model(repeat)==desired
    stage2=deepcopy(repeat); stage2['firewall']['phase']='stage2'
    assert json.loads(model(stage2)[m.NAMES[3]])['phase']=='stage2'
    stage2['firewall']['management_cidr']='192.0.2.11/32'
    try: model(stage2)
    except ValueError: pass
    else: raise AssertionError('changed management policy accepted')
    request=root/'request.json'; request.write_bytes(tx.encoded(value)); request.chmod(0o600)
    cmd=[str(here/'fixture-network.py'),'--root='+name,'--hostname='+host,
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
    (etc/m.NAMES[0]).write_text(old[m.NAMES[0]]+'# drift\n')
    assert run('--apply-fixture',opt).returncode==2
    (etc/m.NAMES[0]).write_text(old[m.NAMES[0]])
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,
                             'original':original,'desired':target},'APPLYING',owner)
    for n in m.NAMES[:2]: tx.atomic_write(etc/n,desired[n],0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==original
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_NETWORK_FIXTURE' in r.stdout
    assert tx.snapshot(etc,owner)==target and run('--verify',opt).returncode==0
    assert run('--apply-fixture',opt).returncode==2
    request.write_bytes(tx.encoded(repeat)); review()
    before=[(etc/n).stat().st_ino for n in m.NAMES]
    assert run('--apply-fixture',opt).returncode==0
    assert before==[(etc/n).stat().st_ino for n in m.NAMES]
    assert all((etc/n).read_text()==data for n,data in keep.items())
    assert run('--verify',opt).returncode==0
    request.unlink(); request.symlink_to(etc/'hosts')
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Network configuration and firewall policy fixture tests passed')
PY
