#!/bin/sh
# Private synthetic configuration only; no remote connection, mail or daemon changes.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Communications fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Communications fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import base64, importlib.util, json, os, pathlib, shutil, struct, subprocess, sys, tempfile
from copy import deepcopy
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('communications_fixture',here/'fixture-communications.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
planner=m.engine.load('plan-communications'); tx=m.engine.transaction(m.NAMES)
pkg=m.engine.load('plan-packages')
stages=pkg.select_profile(pkg.candidates(here/'package-policy.tsv'),here/'package-profiles.tsv','server')
host='node.lab.invalid'
def pin(name, seed):
    key=base64.b64encode(struct.pack('>I',11)+b'ssh-ed25519'+struct.pack('>I',32)+bytes([seed])*32).decode()
    return name+' ssh-ed25519 '+key+'\n'
oldpin=pin('old.lab.invalid',1); newpin=pin('peer.lab.invalid',2)
old={m.NAMES[0]:'# existing pin\n'+oldpin,m.NAMES[1]:'',
     m.NAMES[2]:'# aliases\npostmaster: root\nroot: old\n',
     m.NAMES[3]:'# synthetic main.cf\nmyhostname = node.lab.invalid\nrelayhost =\ninet_interfaces = all\n'}
value={'original':old,'pins':newpin,'fingerprints':dict(planner.public_pins(newpin)),
       'x11':True,'sshd_effective':'subsystem sftp internal-sftp\n',
       'mail':{'relay':'relay.lab.invalid','recipient':'admin@lab.invalid','postfix_installed':True}}
desired=m.model(value,host,'server',stages,planner)
assert desired[m.NAMES[0]]==old[m.NAMES[0]].encode()+newpin.encode()
assert desired[m.NAMES[1]]==m.X11
assert desired[m.NAMES[2]]==b'# aliases\npostmaster: root\nroot: admin@lab.invalid\n'
assert b'inet_interfaces = loopback-only\n' in desired[m.NAMES[3]]
assert b'smtp_tls_security_level = verify\n' in desired[m.NAMES[3]]
assert b'relayhost = [relay.lab.invalid]\n' in desired[m.NAMES[3]]
assert b'mydestination = \n' in desired[m.NAMES[3]]
assert b'myhostname = node.lab.invalid\n' in desired[m.NAMES[3]]
def reject(change, profile='server'):
    candidate=deepcopy(value); change(candidate)
    try: m.model(candidate,host,profile,stages,planner)
    except ValueError: return
    raise AssertionError('unsafe communications request accepted')
reject(lambda v:v['fingerprints'].clear())
reject(lambda v:v['original'].update({m.NAMES[0]:pin('peer.lab.invalid',3)}))
reject(lambda v:v['original'].update({m.NAMES[0]:'@revoked '+oldpin}))
reject(lambda v:v['original'].update({m.NAMES[1]:'Host *\n    ForwardX11 yes\n'}))
reject(lambda v:v.update(sshd_effective='subsystem sftp /tmp/other\n'))
reject(lambda v:None,'workstation')
reject(lambda v:v['mail'].update(postfix_installed=False))
reject(lambda v:v['mail'].update(relay=host))
reject(lambda v:v['mail'].update(recipient='admin@'+host))
reject(lambda v:v['mail'].update(recipient='|command@lab.invalid'))
reject(lambda v:v['original'].update({m.NAMES[2]:'root: old\nroot: duplicate\n'}))
reject(lambda v:v['original'].update({m.NAMES[2]:'root: |command\n'}))
reject(lambda v:v['original'].update({m.NAMES[3]:'relayhost = a\nrelayhost = b\n'}))
reject(lambda v:v['original'].update({m.NAMES[3]:'smtp_sasl_password_maps = hash:/etc/secret\n'}))
reject(lambda v:v['original'].update({m.NAMES[3]:'relayhost = a\n  continuation\n'}))
repeat=dict(value,original={n:data.decode() for n,data in desired.items()})
assert m.model(repeat,host,'server',stages,planner)==desired
without_mail=dict(value,mail=None)
assert m.model(without_mail,host,'server',stages,planner)[m.NAMES[3]]==old[m.NAMES[3]].encode()
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
    for folder in m.DIRECTORIES: (etc/folder).mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    for n,data in old.items():
        (etc/n).write_text(data); (etc/n).chmod(0o644)
    keep=etc/'ssh/sshd_config'; keep.write_text('PasswordAuthentication no\n')
    request=root/'request.json'; request.write_bytes(tx.encoded(value)); request.chmod(0o600)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text(host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    cmd=[str(here/'fixture-communications.py'),'--root='+name,'--hostname='+host,
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
    (etc/m.NAMES[2]).write_text('root: changed\n')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    (etc/m.NAMES[2]).write_text(old[m.NAMES[2]])
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,
                             'original':original,'desired':target},'APPLYING',owner)
    for n in m.NAMES[:2]: tx.atomic_write(etc/n,desired[n],0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==original
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_COMMUNICATIONS_FIXTURE' in r.stdout
    assert tx.snapshot(etc,owner)==target and run('--verify',opt).returncode==0
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==2
    request.write_bytes(tx.encoded(repeat)); review()
    before=[(etc/n).stat().st_ino for n in m.NAMES]
    assert run('--apply-fixture',opt).returncode==0
    assert before==[(etc/n).stat().st_ino for n in m.NAMES]
    assert keep.read_text()=='PasswordAuthentication no\n'
    ssh=shutil.which('ssh',path='/usr/bin:/bin')
    if ssh:
        r=subprocess.run([ssh,'-G','-F',str(etc/m.NAMES[1]),host],
                         capture_output=True,text=True,timeout=15)
        assert r.returncode==0,r.stderr
        assert 'forwardx11 no' in r.stdout.splitlines()
        assert 'forwardx11trusted no' in r.stdout.splitlines()
        print('Standalone SSH client fragment syntax check passed')
    else:
        print('Standalone SSH client fragment check SKIPPED: ssh unavailable')
    request.unlink(); request.symlink_to(keep)
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Communications configuration fixture, conflict and recovery tests passed')
PY
