#!/bin/sh
# Test generated fragments in isolated subprocesses; never load real startup files.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Shell policy test SKIPPED: python3 unavailable'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, os, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('shellplan',here/'plan-shell.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); fragments={}
    for task in ('0190','0390','0580','0590','0630','0640','0650','0660','0670','0680'):
        f=next((here/'tasks').glob(task+'_*'))
        r=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True,check=True)
        assert r.stdout and not r.stderr
        fragments[task]=p/task; fragments[task].write_text(r.stdout)
    assert 'KEEP_UNCHANGED' in fragments['0390'].read_text()
    assert 'NO_HARDLINK' in fragments['0640'].read_text()
    assert 'KEEP_EXISTING_NO_NEW_ALIAS' in fragments['0650'].read_text()
    assert 'KEEP_EXISTING_NO_NEW_ALIAS' in fragments['0660'].read_text()
    assert 'KEEP_DISTRIBUTION_DEFAULT' in fragments['0680'].read_text()
    env={'PATH':'/usr/bin:/bin','HOME':tmp,'LC_ALL':'C','TERM':'dumb'}
    def shell(binary, args, cmd, task, environment=env):
        return subprocess.run([binary,*args,'-c',cmd,'test',str(fragments[task])],env=environment,capture_output=True,text=True,check=True).stdout.strip()
    for task in ('0190','0580','0630','0670'):
        subprocess.run(['/bin/sh','-n',str(fragments[task])],check=True)
        assert shell('/bin/sh',[], 'umask 022; . "$1"; umask',task)=='0022'
    assert shell('/bin/dash',['-i'],' . "$1"; umask; alias ll','0190').splitlines()[0]=='0077'
    assert shell('/bin/dash',['-i'],' . "$1"; umask; test -z "${TMOUT+x}"','0580')=='0027'
    if pathlib.Path('/bin/bash').is_file():
        args=['--noprofile','--norc','-i']
        assert shell('/bin/bash',args,' . "$1"; . "$1"; umask; printf "%s\\n" "$TMOUT"','0580')=='0027\n600'
        assert shell('/bin/bash',args,' TMOUT=900; readonly TMOUT; . "$1"; printf "%s\\n" "$TMOUT"','0580')=='900'
    else: print('Bash interactive tests SKIPPED: unavailable')
    assert 'ps aux' in shell('/bin/dash',['-i'],' . "$1"; alias bsdps','0630')
    # A synthetic executable is detected, never executed.
    tools=p/'bin'; tools.mkdir(); less=tools/'less'; less.write_text('#!/bin/sh\nexit 99\n'); less.chmod(0o700)
    assert shell('/bin/dash',['-i'],' . "$1"; printf "%s\\n" "$PAGER"','0670',{**env,'PATH':str(tools)})=='less'
    assert shell('/bin/dash',['-i'],' PAGER=more; . "$1"; printf "%s\\n" "$PAGER"','0670',{**env,'PATH':str(tools)})=='more'
    assert shell('/bin/dash',['-i'],' . "$1"; printf "%s\\n" "${PAGER-unset}"','0670',{**env,'PATH':str(p/'missing')})=='unset'
    root=p/'fixture'; root.mkdir(); etc=root/'etc'; etc.mkdir(); profile=etc/'profile'; profile.write_text('exit 99\n')
    uid=os.geteuid(); assert m.observe(root,'/etc/profile',uid)=='FILE_OBSERVED'
    profile.chmod(0o666); assert m.observe(root,'/etc/profile',uid)=='METADATA_REVIEW'; profile.chmod(0o600)
    (etc/'hard').hardlink_to(profile); assert m.observe(root,'/etc/profile',uid)=='HARDLINK_REVIEW'
    (etc/'link').symlink_to(profile); assert m.observe(root,'/etc/link',uid)=='SYMLINK_REVIEW'
    (root/'usr').symlink_to(etc); assert m.observe(root,'/usr/profile',uid)=='SYMLINK_REVIEW'
    assert m.observe(root,'/etc/missing',uid)=='MISSING' and m.observe(root,'/etc/profile/child',uid)=='TYPE_REVIEW'
    assert profile.read_text()=='exit 99\n'
    inv=p/'hosts'; roles=p/'roles'; inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n'); roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    cmd=[str(here/'plan-shell.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    r=subprocess.run([*cmd,'--list'],capture_output=True,text=True); assert r.returncode==0 and 'startup-content\tNOT_READ' in r.stdout and 'shell-apply\tNOT_AUTHORIZED' in r.stdout
    r=subprocess.run([*cmd,'--live'],capture_output=True,text=True); assert r.returncode==(2 if uid==0 else 3)
    inv.write_text('invalid\n'); assert subprocess.run([*cmd,'--list'],capture_output=True).returncode==2
print('Shell fragment and compatibility metadata tests passed')
PY
