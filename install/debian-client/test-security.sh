#!/bin/sh
# Synthetic account data; no real shadow or authentication changes.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Security test SKIPPED: python3 unavailable'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, os, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('security',here/'plan-security.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
users='root:x:0:0::/root:/bin/sh\nlabuser:x:1000:1000::/home/labuser:/bin/sh\n'
groups='root:x:0:\nlabuser:x:1000:\nvideo:x:44:labuser\nsudo:x:27:labuser\n'
def reject(fn):
    try: fn()
    except ValueError: return
    raise AssertionError('unexpected success')
s=m.summarize(m.accounts(users),m.groups(groups))
assert s['accounts']==2 and s['sudo-memberships']==1 and s['video-memberships']==1
assert s['unexpected-uid-zero']==0 and s['root-uid-zero-count']==1
bad=users+'other:fixture-secret:00:999::relative:sh\n'
s=m.summarize(m.accounts(bad),m.groups(groups+'extra:x:044:remote\n'))
assert s['unexpected-uid-zero']==1 and s['duplicate-uids']==1 and s['passwd-field-review']==1
assert s['primary-gid-not-local']==1 and s['group-member-not-local']==1 and s['duplicate-gids']==1
assert s['home-path-review']==1 and s['shell-path-review']==1
reject(lambda:m.accounts('bad:record\n'))
reject(lambda:m.accounts(users.replace('1000:1000','-1:1000')))
reject(lambda:m.groups(groups.replace('video:x:44:labuser','video:x:44:labuser,labuser')))
assert m.hash_policy('ENCRYPT_METHOD YESCRYPT\n')=='YESCRYPT'
assert m.hash_policy('ENCRYPT_METHOD SHA512\nENCRYPT_METHOD YESCRYPT\n')=='REVIEW_REQUIRED'
assert m.hash_policy('# ENCRYPT_METHOD SHA512\n')=='NOT_EXPLICIT'
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); capture=p/'capture'; capture.mkdir(); inv=p/'hosts'; roles=p/'roles'
    (capture/'passwd').write_text(bad); (capture/'group').write_text(groups); (capture/'login.defs').write_text('ENCRYPT_METHOD YESCRYPT\n')
    (capture/'shadow').write_text('not-read-fixture\n')
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n'); roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    cmd=[str(here/'plan-security.py'),'--capture='+str(capture),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    r=subprocess.run(cmd,capture_output=True,text=True); assert r.returncode==3
    assert 'unexpected-uid-zero\t1' in r.stdout and 'login-defs-method\tYESCRYPT' in r.stdout
    assert all(v not in r.stdout+r.stderr for v in ('fixture-secret','labuser','not-read-fixture','/home/labuser'))
    assert 'security-apply\tNOT_AUTHORIZED' in r.stdout and 'shadow-content\tNOT_READ' in r.stdout
    assert (capture/'passwd').read_text()==bad
    root=p/'fixture'; root.mkdir(); etc=root/'etc'; etc.mkdir()
    uid=os.geteuid(); observer=m.load('plan-shell').observe
    shadow=etc/'shadow'; shadow.write_text('not-read-fixture\n'); shadow.chmod(0o644)
    assert m.sensitive_mode(root,'/etc/shadow',observer,uid)=='MODE_REVIEW'
    shadow.chmod(0o640); assert m.sensitive_mode(root,'/etc/shadow',observer,uid)=='MODE_MATCH_ONLY'
    sudo=etc/'sudoers'; sudo.write_text('fixture\n'); sudo.chmod(0o600)
    assert m.sensitive_mode(root,'/etc/sudoers',observer,uid)=='MODE_REVIEW'
    sudo.chmod(0o440); assert m.sensitive_mode(root,'/etc/sudoers',observer,uid)=='MODE_MATCH_ONLY'
    shadow.unlink(); shadow.symlink_to(sudo)
    assert m.sensitive_mode(root,'/etc/shadow',observer,uid)=='SYMLINK_REVIEW'
    (capture/'group').unlink(); (capture/'group').symlink_to(p/'missing')
    assert subprocess.run(cmd,capture_output=True).returncode==2
for task in ('0520','0550','0560','0570','0600','0610'):
    f=next((here/'tasks').glob(task+'_*'))
    r=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True)
    assert r.returncode==0 and r.stdout
print('Security policy and account summary tests passed')
PY
