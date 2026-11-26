#!/bin/sh
# Install only reviewed opt-in fragments; never source real startup files.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Shell fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Shell fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, json, os, pathlib, shutil, subprocess, sys, tempfile
from copy import deepcopy
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('shell_fixture',here/'fixture-shell.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tx=m.engine.transaction(m.NAMES); owner=os.geteuid()
host='node.lab.invalid'
rendered={task:tx.command('/bin/sh',str(here/'tasks'/(task+'_'+script)),
                          '--hostname='+host,'--render') for task,(script,_) in m.TASKS.items()}
old=dict.fromkeys(m.NAMES,'')
value={'original':old,'select':list(m.TASKS)}
desired=m.model(value,rendered)
assert rendered==m.EXPECTED and len(desired)==5
partial=deepcopy(value); partial['select']=['0190']
partial['original']['sasd-shell/pager.sh']='# existing opt-in preference\n'
assert m.model(partial,rendered)['sasd-shell/pager.sh']==b'# existing opt-in preference\n'
def reject(change, candidates=rendered):
    v=deepcopy(value); change(v)
    try: m.model(v,candidates)
    except ValueError: return
    raise AssertionError('unsafe shell request accepted')
reject(lambda v:v['select'].append('0190'))
reject(lambda v:v['select'].append('0610'))
reject(lambda v:v.update(select=[]))
reject(lambda v:v['original'].update({'sasd-shell/root-interactive.sh':'exit 99\n'}))
reject(lambda v:v['original'].update({'profile':'arbitrary\n'}))
reject(lambda v:v['original'].update({'sasd-shell/pager.sh':'bad\x00text'}))
reject(lambda v:None,dict(rendered,**{'0580':b'exit 99\n'}))
repeat=dict(value,original={name:data.decode('ascii') for name,data in desired.items()})
assert m.model(repeat,rendered)==desired
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700); (etc/'sasd-shell').mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    for n,data in old.items():
        (etc/n).write_text(data); (etc/n).chmod(0o644)
    preserved={'profile':'exit 99\n','bash.bashrc':'# existing bash\n','csh.cshrc':'# existing csh\n',
               'passwd':'synthetic:x:1000:1000::/home/synthetic:/bin/sh\n',
               'group':'synthetic:x:1000:\n'}
    for n,data in preserved.items(): (etc/n).write_text(data)
    request=root/'request.json'; request.write_bytes(tx.encoded(value)); request.chmod(0o600)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text(host+'\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    cmd=[str(here/'fixture-shell.py'),'--root='+name,'--hostname='+host,
         '--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    def review():
        r=run('--review'); assert r.returncode==0,r.stderr
        ref.write_text(r.stdout); ref.chmod(0o600)
        return json.loads(r.stdout)
    approved=review(); opt='--reference='+str(ref)
    original=tx.snapshot(etc,owner)
    target={n:{'data':data.hex(),'mode':0o644} for n,data in desired.items()}
    assert run('--verify',opt).returncode==1
    request.write_bytes(tx.encoded(value)+b' ')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    request.write_bytes(tx.encoded(value))
    (etc/m.NAMES[0]).write_text('changed\n')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    (etc/m.NAMES[0]).write_text('')
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,
                             'original':original,'desired':target},'APPLYING',owner)
    for n in m.NAMES[:2]: tx.atomic_write(etc/n,desired[n],0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==original
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_SHELL_FIXTURE' in r.stdout
    assert tx.snapshot(etc,owner)==target and run('--verify',opt).returncode==0
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==2
    # Exercise only exact reviewed fragments, in clean child shells.
    env={'PATH':'/usr/bin:/bin','HOME':str(p),'LC_ALL':'C','TERM':'dumb'}
    for n in m.NAMES:
        if n.endswith('.sh'):
            subprocess.run(['/bin/sh','-n',str(etc/n)],env=env,check=True,timeout=10)
            r=subprocess.run(['/bin/sh','-c','umask 022; . "$1"; umask','test',str(etc/n)],
                             env=env,capture_output=True,text=True,check=True,timeout=10)
            assert r.stdout.strip()=='0022'
    r=subprocess.run(['/bin/dash','-i','-c',' . "$1"; . "$2"; umask','test',
                      str(etc/'sasd-shell/interactive.sh'),str(etc/'sasd-shell/root-interactive.sh')],
                     env=env,capture_output=True,text=True,check=True,timeout=10)
    assert r.stdout.strip()=='0077'
    tcsh=shutil.which('tcsh',path='/usr/bin:/bin')
    if tcsh:
        subprocess.run([tcsh,'-f','-n',str(etc/'sasd-shell/interactive.csh')],env=env,check=True,timeout=10)
    else:
        print('C-shell syntax check SKIPPED: tcsh unavailable')
    request.write_bytes(tx.encoded(repeat)); review()
    before=[(etc/n).stat().st_ino for n in m.NAMES]
    assert run('--apply-fixture',opt).returncode==0
    assert before==[(etc/n).stat().st_ino for n in m.NAMES]
    assert all((etc/n).read_text()==data for n,data in preserved.items())
    request.unlink(); request.symlink_to(etc/'profile')
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Shell opt-in fragment installation and recovery tests passed')
PY
