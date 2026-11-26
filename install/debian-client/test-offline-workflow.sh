#!/bin/sh
# One inventory, real fixture APIs, synthetic inputs only. No native operations.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Offline workflow SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Offline workflow SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -I -B - "$here" <<'PY'
import base64
from contextlib import ExitStack
from copy import deepcopy
import csv
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile

here = Path(sys.argv[1])
host = 'node.lab.invalid'
owner = os.geteuid()


def load(name):
    spec = importlib.util.spec_from_file_location(name, here / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def put(path, data, mode=0o600):
    path.write_bytes(data.encode('ascii') if isinstance(data, str) else data)
    path.chmod(mode)


def hash_bytes(data):
    return hashlib.sha256(data).hexdigest()


def artifact(output, label, prefix, stack):
    # Only remove precisely named private directories created by our own CLI.
    lines = [line[len(label):] for line in output.splitlines() if line.startswith(label)]
    assert len(lines) == 1, output
    path = Path(lines[0])
    assert re.fullmatch('/tmp/' + re.escape(prefix) + r'\.[A-Za-z0-9_]+', str(path))
    assert path.resolve() == path and path.is_dir() and path.stat().st_uid == owner
    stack.callback(shutil.rmtree, path)
    return path


with ExitStack() as stack:
    aux = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix='sasd-workflow.')))
    os.umask(0o077)
    inventory, roles, site = (aux / n for n in ('hosts', 'roles', 'site'))
    put(inventory, host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    put(roles, 'server\tsite_server\tmodern\troles/server.tsv\n')
    put(site, 'dns1=192.0.2.53\nsearch=lab.invalid\n')
    common = ['--hostname='+host, '--inventory='+str(inventory), '--roles='+str(roles)]
    env = {'PATH':'/usr/bin:/bin','LC_ALL':'C','HOME':str(aux)}
    engine = load('fixture-config')
    tx0 = load('native-install')
    profile, stages, context = load('plan-packages').inventory_selection(host,str(inventory),str(roles))
    assert profile == 'server'

    def run(*args, code=0):
        r = subprocess.run(['/bin/sh',str(here/'install-client.sh'),*common,*args],
                           env=env,capture_output=True,text=True,timeout=300)
        assert r.returncode == code, (args[0],code,r.returncode,r.stdout,r.stderr)
        return r.stdout

    def report(*args, code=0):
        return json.loads(run(*args,code=code))

    plan = report('--orchestration-plan')
    assert len(plan['tasks']) == 116 and plan['inventory-plan'] == context['client-plan']
    assert plan['execution'] == 'NOT_AUTHORIZED'
    stage = artifact(run('--stage','--site='+str(site),code=3),
                     'Candidate directory: ','sasd-debian-stage',stack)
    assert hash_bytes((stage/'plan.tsv').read_bytes()) == context['client-plan']
    with (stage/'results.tsv').open() as stream:
        rows = list(csv.DictReader(stream,delimiter='\t'))
    staged = [r for r in rows if r['status']=='STAGED']
    assert len(rows)==116 and len(staged)==39
    for row in staged:
        path = stage/(row['id']+'_'+row['task']+'.candidate')
        assert hash_bytes(path.read_bytes())==row['sha256']

    # Baseline has its own legacy contract, deliberately not in D.7b evidence.
    # Legacy baseline accepts alphanumeric suffixes only; Python tempfile
    # may generate underscores. Use the same mktemp contract as the shell tests.
    baseline = Path(subprocess.check_output(
        ['/usr/bin/mktemp','-d','/tmp/sasd-debian-lab.XXXXXXXX'],
        env=env,text=True).strip())
    assert re.fullmatch(r'/tmp/sasd-debian-lab\.[A-Za-z0-9]+',str(baseline))
    assert baseline.resolve()==baseline and baseline.stat().st_uid==owner
    stack.callback(shutil.rmtree,baseline)
    (baseline/'etc').mkdir(mode=0o700)
    put(baseline/'.sasd-fixture','SASD-DEBIAN-FIXTURE-1\n')
    put(baseline/'etc/hostname','old\n')
    put(baseline/'etc/hosts','127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 ip6-localhost\n')
    put(baseline/'etc/resolv.conf','nameserver 192.0.2.99\nsearch old.invalid\n')
    base_report = artifact(run('--fixture-apply','--root='+str(baseline),'--site='+str(site)),
                           'Fixture report: ','sasd-debian-fixture-report',stack)
    assert (base_report/'status').read_text()=='VERIFIED_FIXTURE\n'
    assert (base_report/'results.tsv').read_text().count('FIXTURE_VERIFIED')==3
    assert 'WAIT_RUNTIME' in (base_report/'results.tsv').read_text()
    assert (baseline/'etc/hostname').read_text()=='node\n'
    base_snapshot = {n:(baseline/'etc'/n).read_bytes() for n in ('hostname','hosts','resolv.conf')}

    modules = {}
    roots = {}
    references = {}
    manifests = {}
    snapshots = {}

    def setup(group, original, request=None, filename='request.json'):
        mod = load('fixture-'+group)
        root = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix=mod.PREFIX+'.',dir='/tmp')))
        etc = root/'etc'
        etc.mkdir(mode=0o700)
        (root/'transactions').mkdir(mode=0o700)
        for folder in mod.DIRECTORIES:
            (etc/folder).mkdir(mode=0o700)
        put(root/mod.MARKER,mod.FORMAT+'\n')
        assert set(original)==set(mod.NAMES)
        for n,data in original.items():
            put(etc/n,data,0o644)
        put(etc/'workflow-preserved','untouched\n')
        if request is not None:
            put(root/filename,tx0.encoded(request))
        modules[group], roots[group] = mod,root
        return root

    def group_run(group,*args,code=0):
        return run('--fixture-group='+group,'--root='+str(roots[group]),*args,code=code)

    def commit(group):
        ref = aux/(group+'.reference')
        put(ref,group_run(group,'--review'))
        opt = '--reference='+str(ref)
        group_run(group,'--apply-fixture',opt)
        group_run(group,'--verify',opt)
        store = roots[group]/'transactions'
        journal, = list(store.iterdir())
        tx = engine.transaction(modules[group].NAMES)
        j = tx.load_journal(journal,owner)
        assert j['state']=='COMMITTED_STATIC'
        assert tx.snapshot(roots[group]/'etc',owner)==j['desired']
        references[group]=ref
        snapshots[group]=j['desired']
        manifests[group]={'root':str(roots[group]),'reference':str(ref),'journal':journal.name}

    # Transfer only explicit synthetic outputs between independently scoped groups.
    network = load('fixture-network')
    old = dict.fromkeys(network.NAMES,'')
    old['hosts']=base_snapshot['hosts'].decode('ascii')
    old['resolv.conf']=base_snapshot['resolv.conf'].decode('ascii')
    net_request={'original':old,'hosts':[['files.lab.invalid','192.0.2.50']],
                 'apt':{'release':'12','keyring_present':True,'other_sources':{}},
                 'proxy':{'host':'proxy.lab.invalid','port':3128},
                 'resolver':{'owners':['static'],'dns1':'192.0.2.54','dns2':None,'search':'lab.invalid'},
                 'firewall':{'phase':'stage1','owners':['nftables'],
                             'addresses':[{'ifname':'eth0','flags':['UP'],'addr_info':[
                                 {'family':'inet','local':'192.0.2.40','prefixlen':24,'scope':'global'}]}],
                             'routes':[{'dst':'default','gateway':'192.0.2.1','dev':'eth0'}],
                             'gateway':'192.0.2.1','management_cidr':'192.0.2.10/32'}}
    net_root=setup('network',old,net_request)
    commit('network')
    assert b'nameserver 192.0.2.54\n' in (net_root/'etc/resolv.conf').read_bytes()

    packages = load('fixture-packages')
    selected = sorted(set(stages['1']) | set(stages['2']))
    installed = {'cron':'1'}
    missing = [n for n in selected if n not in installed]
    transcript = ['0 upgraded, %d newly installed, 0 to remove and 0 not upgraded.'%len(missing)]
    transcript += ['Inst %s (1 Debian)'%n for n in missing]
    transcript += ['Conf %s (1 Debian)'%n for n in missing]
    pkg_request={'stage':'both','installed':installed,'candidates':dict.fromkeys(selected,'1'),
                 'simulation':'\n'.join(transcript)+'\n'}
    pkg_root=setup('packages',{packages.NAMES[0]:tx0.encoded(installed)},pkg_request,'simulation.json')
    commit('packages')
    modeled_packages=json.loads((pkg_root/'etc'/packages.NAMES[0]).read_bytes())
    assert set(selected)<=set(modeled_packages)
    assert {'cron','openssh-server','logwatch','nfs-common','smartmontools'}<=set(modeled_packages)

    service=load('fixture-services')
    off=['loaded','inactive','disabled']
    units={'cron.service':off,'ssh.service':off,'rsyslog.service':off}
    service_request={'installed':sorted(modeled_packages),'units':units,
                     'actions':{n:'enable' for n in units},
                     'schedules':[['logwatch','cron:daily-logwatch',True]],
                     'selection':{},'adopt':['logwatch']}
    svc_root=setup('services',dict(zip(service.NAMES,(tx0.encoded(units),tx0.encoded({})))),service_request)
    commit('services')
    assert json.loads((svc_root/'etc'/service.NAMES[1]).read_bytes())=={'logwatch':'cron:daily-logwatch'}

    storage=load('fixture-storage')
    fstab='UUID=root / ext4 defaults 0 1\nUUID=home /home ext4 defaults 0 2\n'
    share='name\tserver\texport\tmode\nprojects\tfiles.lab.invalid\t/export/projects\tmanual\n'
    request={'fstab':fstab,'mountinfo':'1 0 8:1 / / rw - ext4 /dev/fake rw\n',
             'autofs_targets':['/net'],'harden':['/home'],'shares':share,
             'mountpoints':{n:{'kind':'directory','uid':0,'gid':0,'mode':493,'empty':n.count('/')==3}
                            for n in ('/mnt','/mnt/sasd','/mnt/sasd/projects')}}
    storage_root=setup('storage',{'fstab':fstab},request)
    commit('storage')
    assert 'files.lab.invalid:/export/projects' in (storage_root/'etc/fstab').read_text()

    for group in ('banner','logging'):
        mod=load('fixture-'+group)
        setup(group,dict.fromkeys(mod.NAMES,'old\n'))
        commit(group)

    shell=load('fixture-shell')
    old=dict.fromkeys(shell.NAMES,'')
    setup('shell',old,{'original':old,'select':list(shell.TASKS)})
    commit('shell')

    security=load('fixture-security')
    old={security.NAMES[0]:'ENCRYPT_METHOD SHA512\n',security.NAMES[1]:'',security.NAMES[2]:''}
    request={'original':old,'passwd':'root:x:0:0::/root:/bin/sh\nlabuser:x:1000:1000::/home/labuser:/bin/sh\n',
             'group':'root:x:0:\nlabuser:x:1000:\n','hash':{'method':'YESCRYPT','yescrypt_supported':True},
             'limits':{'user':'labuser','soft_nofile':2048,'hard_nofile':4096},'audit_approval':None}
    setup('security',old,request)
    commit('security')

    communications=load('fixture-communications')
    key=base64.b64encode(struct.pack('>I',11)+b'ssh-ed25519'+struct.pack('>I',32)+bytes([2])*32).decode()
    pin='peer.lab.invalid ssh-ed25519 '+key+'\n'
    old=dict.fromkeys(communications.NAMES,'')
    request={'original':old,'pins':pin,'fingerprints':dict(load('plan-communications').public_pins(pin)),
             'x11':True,'sshd_effective':'subsystem sftp internal-sftp\n','mail':None}
    setup('communications',old,request)
    commit('communications')

    monitoring=load('fixture-monitoring')
    old=dict.fromkeys(monitoring.NAMES,'')
    request={'original':old,'checks':'client-smart\t*\tSMART review\n','select':['client-smart'],
             'smart':{'device':{'protocol':'ATA'},'smartctl':{'exit_status':8},'smart_status':{'passed':False}},
             'sensors':None,'hardware':{'kernel':'6.1.0-fixture','architecture':'x86_64','logical_cpus':4,'mount_count':3}}
    monitor_root=setup('monitoring',old,request)
    commit('monitoring')
    assert json.loads((monitor_root/'etc'/monitoring.NAMES[1]).read_bytes())['transport']=='NOT_RUN'

    manifest=aux/'manifest.json'
    put(manifest,tx0.encoded({'groups':manifests}))
    manifest_opt='--manifest='+str(manifest)

    def evidence(code=0):
        r=report('--evidence-report',manifest_opt,code=code)
        assert len(r['groups'])==10 and len(r['tasks'])==116 and len(r['dependencies'])==57
        assert r['native-verification']=='NOT_VERIFIED' and r['dependency-promotion']=='NOT_AUTHORIZED'
        assert all(t['installed']=='NOT_CERTIFIED' for t in r['tasks'])
        assert sum(e['status']=='WAIT_VERIFIED' for e in r['dependencies'])==54
        assert sum(e['status']=='WAIT_CANDIDATE' for e in r['dependencies'])==3
        return r

    initial=evidence()
    assert all(g['status']=='STATIC_COMMITTED_MATCH' for g in initial['groups'].values())
    planned=report('--orchestration-plan',manifest_opt)
    assert planned['evidence-report-sha256']==tx0.digest(tx0.encoded(initial))
    assert planned['execution']=='NOT_AUTHORIZED'
    assert all(t['native-execution']=='NOT_AUTHORIZED' for t in planned['tasks'])
    cp=aux/'checkpoint.json'
    cp_opt='--checkpoint='+str(cp)
    saved=report('--checkpoint-save',manifest_opt,cp_opt)
    digest=saved['checkpoint-sha256']
    assert saved['status']=='CHECKPOINT_SAVED' and hash_bytes(cp.read_bytes())==digest

    def resume(status,code=3):
        r=report('--checkpoint-resume',manifest_opt,cp_opt,'--expect-checkpoint='+digest,code=code)
        assert r['status']==status and r['execution']=='NOT_AUTHORIZED'
        return r

    resume('CHECKPOINT_MATCH_REVIEW_ONLY',0)
    # Prepare a *new* network transaction against the committed snapshot.
    # Kill a child process after its first actual target replacement; the real
    # transaction primitive writes the durable journal first. No test hook in runtime.
    tx=engine.transaction(network.NAMES)
    original=snapshots['network']
    revised=deepcopy(net_request)
    revised['original']={n:bytes.fromhex(v['data']).decode('ascii') for n,v in original.items()}
    revised['hosts'].append(['backup.lab.invalid','192.0.2.60'])
    revised['resolver']['dns1']='192.0.2.55'
    request_path=net_root/'request.json'
    old_request=request_path.read_bytes()
    put(request_path,tx.encoded(revised))
    recovery_ref=aux/'network-recovery.reference'
    put(recovery_ref,group_run('network','--review'))
    approved=json.loads(recovery_ref.read_bytes())
    _, expected, contents=network.prepare(net_root,host,profile,stages,tx,context)
    assert expected==original
    desired={n:{'data':contents[n].hex(),'mode':0o644} for n in network.NAMES}
    assert original['hosts']!=desired['hosts'] and original['resolv.conf']!=desired['resolv.conf']
    store=net_root/'transactions'
    pid=os.fork()
    if pid==0:
        try:
            fd=os.open(store,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
            fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
            atomic=tx.atomic_write
            def interrupted(path,data,mode,user):
                atomic(path,data,mode,user)
                if path==net_root/'etc/hosts':
                    os._exit(86)
            tx.atomic_write=interrupted
            tx.transition(net_root/'etc',store,owner,approved,original,desired,lambda: True)
        except BaseException:
            import traceback
            traceback.print_exc()
        os._exit(87)
    _, status=os.waitpid(pid,0)
    assert os.WIFEXITED(status) and os.WEXITSTATUS(status)==86
    pending=tx.pending(store,owner)
    assert len(pending)==1 and tx.load_journal(pending[0],owner)['state']=='APPLYING'
    partial=tx.snapshot(net_root/'etc',owner)
    assert partial['hosts']==desired['hosts'] and partial['resolv.conf']==original['resolv.conf']
    restart=resume('RECOVERY_REVIEW_REQUIRED')
    assert restart['current']['groups']['network']['open-journal']==pending[0].name
    group_run('network','--apply-fixture','--reference='+str(recovery_ref),code=2)
    group_run('network','--recover='+pending[0].name,'--reference='+str(references['network']),code=2)
    assert tx.snapshot(net_root/'etc',owner)==partial
    group_run('network','--recover='+pending[0].name,'--reference='+str(recovery_ref))
    assert tx.load_journal(pending[0],owner)['state']=='ROLLED_BACK'
    assert tx.snapshot(net_root/'etc',owner)==original and not tx.pending(store,owner)

    # Restore the prior synthetic request explicitly, not through an automatic resume.
    # The rollback journal stays present, so the old checkpoint MUST NOT match.
    put(request_path,old_request)
    final=evidence()
    assert final==initial
    resume('EVIDENCE_CHANGED')
    assert hash_bytes(cp.read_bytes())==digest
    cp2=aux/'checkpoint-after-recovery.json'
    second=report('--checkpoint-save',manifest_opt,'--checkpoint='+str(cp2))
    assert second['status']=='CHECKPOINT_SAVED' and second['checkpoint-sha256']!=digest
    assert report('--checkpoint-resume',manifest_opt,'--checkpoint='+str(cp2),
                  '--expect-checkpoint='+second['checkpoint-sha256'])['status']=='CHECKPOINT_MATCH_REVIEW_ONLY'
    for group,root in roots.items():
        assert engine.transaction(modules[group].NAMES).snapshot(root/'etc',owner)==snapshots[group]
        assert (root/'etc/workflow-preserved').read_text()=='untouched\n'
    assert {n:(baseline/'etc'/n).read_bytes() for n in base_snapshot}==base_snapshot
    assert evidence()==initial
    # Stable summary; random paths, transaction IDs and digests stay in private fixtures.
    print(json.dumps({'format':'SASD-OFFLINE-WORKFLOW-TEST-1','result':'PASS',
                      'tasks':116,'staged':39,'baseline-static':3,'groups-static':10,
                      'dependency-edges-waiting':57,'interruption':'PARTIAL_WRITE_CHILD_EXIT',
                      'recovery':'ROLLED_BACK','old-checkpoint':'EVIDENCE_CHANGED',
                      'new-checkpoint':'CHECKPOINT_MATCH_REVIEW_ONLY',
                      'native-verification':'NOT_VERIFIED','execution':'NOT_AUTHORIZED'},sort_keys=True))
PY
