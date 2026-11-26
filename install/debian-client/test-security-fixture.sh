#!/bin/sh
# Synthetic security fixture only: no PAM/sudo/password/scanner commands.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Security fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Security fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import hashlib, importlib.util, json, os, pathlib, subprocess, sys, tempfile
from copy import deepcopy
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('security_fixture',here/'fixture-security.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tx=m.engine.transaction(m.NAMES); planner=m.engine.load('plan-security')
audits=m.engine.load('plan-audits'); pkg=m.engine.load('plan-packages')
host='node.lab.invalid'
old={m.NAMES[0]:'# preserve\nENCRYPT_METHOD SHA512\nUMASK 022\n',m.NAMES[1]:'',m.NAMES[2]:''}
value={'original':old,'passwd':'root:x:0:0::/root:/bin/sh\nlabuser:x:1000:1000::/home/labuser:/bin/sh\n',
       'group':'root:x:0:\nlabuser:x:1000:\n','hash':{'method':'YESCRYPT','yescrypt_supported':True},
       'limits':{'user':'labuser','soft_nofile':2048,'hard_nofile':4096},'audit_approval':None}
desired=m.model(value,planner,None)
assert desired[m.NAMES[0]]==b'# preserve\nENCRYPT_METHOD YESCRYPT\nUMASK 022\n'
assert b'labuser soft nofile 2048\nlabuser hard nofile 4096\n' in desired[m.NAMES[1]]
def reject(change, manifest=None):
    v=deepcopy(value); change(v)
    try: m.model(v,planner,manifest)
    except ValueError: return
    raise AssertionError('unsafe security request accepted')
reject(lambda v:v['hash'].update(yescrypt_supported=False))
reject(lambda v:v['hash'].update(method='MD5'))
reject(lambda v:v['original'].update({m.NAMES[0]:'ENCRYPT_METHOD SHA512\nENCRYPT_METHOD YESCRYPT\n'}))
reject(lambda v:v['limits'].update(user='root'))
reject(lambda v:v['limits'].update(user='*'))
reject(lambda v:v['limits'].update(soft_nofile=8192))
reject(lambda v:v['limits'].update(hard_nofile=True))
reject(lambda v:v.update(passwd=v['passwd']+'other:x:0:0::/root:/bin/sh\n'))
reject(lambda v:v['original'].update({m.NAMES[1]:'* hard nofile 999999\n'}))
reject(lambda v:v.update(audit_approval='0'*64), 'synthetic')
reject(lambda v:v.update(hash=None,limits=None))
assert m.hash_setting('# only comment\n',value['hash'],planner)=='# only comment\nENCRYPT_METHOD YESCRYPT\n'
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
    for folder in m.DIRECTORIES: (etc/folder).mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    for n,data in old.items():
        (etc/n).write_text(data); (etc/n).chmod(0o644)
    keep={'passwd':value['passwd'],'group':value['group'],'shadow':'synthetic-not-read\n',
          'sudoers':'root ALL=(ALL) ALL\n','security/limits.conf':'# distribution defaults\n'}
    for n,data in keep.items(): (etc/n).write_text(data)
    capture=etc/'sasd-security/audit-source'
    for n in audits.NAMES:
        (capture/n).write_text('synthetic '+n+'\n'); (capture/n).chmod(0o640)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text(host+'\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    _,_,context=pkg.inventory_selection(host,str(inv),str(roles))
    manifest=audits.snapshot(capture,host,context['client-plan'])
    value['audit_approval']=hashlib.sha256(manifest.encode('ascii')).hexdigest()
    desired=m.model(value,planner,manifest)
    assert desired[m.NAMES[2]]==manifest.encode('ascii')
    assert all(s=='MATCH' for _,s in audits.compare(manifest,manifest))
    reject(lambda v:v.update(audit_approval=value['audit_approval'],
                            original=dict(old,**{m.NAMES[2]:'old baseline\n'})),manifest)
    request=root/'request.json'; request.write_bytes(tx.encoded(value)); request.chmod(0o600)
    cmd=[str(here/'fixture-security.py'),'--root='+name,'--hostname='+host,
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
    (capture/'hosts').write_text('changed\n')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    (capture/'hosts').write_text('synthetic hosts\n')
    (etc/m.NAMES[0]).write_text('changed\n')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    (etc/m.NAMES[0]).write_text(old[m.NAMES[0]])
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,
                             'original':original,'desired':target},'APPLYING',owner)
    tx.atomic_write(etc/m.NAMES[0],desired[m.NAMES[0]],0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==original
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_SECURITY_FIXTURE' in r.stdout
    assert tx.snapshot(etc,owner)==target and run('--verify',opt).returncode==0
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==2
    repeat=dict(value,original={n:data.decode('ascii') for n,data in desired.items()})
    request.write_bytes(tx.encoded(repeat)); review()
    before=[(etc/n).stat().st_ino for n in m.NAMES]
    assert run('--apply-fixture',opt).returncode==0
    assert before==[(etc/n).stat().st_ino for n in m.NAMES]
    assert all((etc/n).read_text()==data for n,data in keep.items())
    assert run('--verify',opt).returncode==0
    (capture/'hosts').chmod(0o600)
    assert run('--verify',opt).returncode==2
    (capture/'hosts').chmod(0o640)
    request.unlink(); request.symlink_to(etc/'passwd')
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Security configuration and approved integrity fixture tests passed')
PY
