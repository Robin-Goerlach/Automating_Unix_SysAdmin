#!/bin/sh
# Offline NSS policy checks; never perform remote lookups or change login settings.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Directory test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Directory test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('directory',here/'plan-directory.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def report(text):
    return {x[0]:x[1:] for x in m.summarize(m.parse_nss(text))}
assert report('passwd: files sss\ngroup: files\n')['passwd']==('DIRECTORY_REVIEW','files,sss','0')
assert report('passwd: nis files\n')['passwd'][0]=='LOCAL_FIRST_NOT_EXPLICIT'
assert report('passwd: files [NOTFOUND=return] sss\n')['passwd']==('REVIEW_REQUIRED','files,sss','1')
assert report('passwd: files vendor_secret\n')['passwd'][1]=='files,OTHER'
assert report('passwd: files files\n')['passwd'][0]=='REVIEW_REQUIRED'
assert report('passwd: compat\npasswd_compat: nis\n')['passwd_compat'][0]=='REVIEW_REQUIRED'
assert report('hosts: files dns # comment\n')['hosts'][0]=='LOCAL_FIRST_OBSERVED'
for bad in ('','passwd: files\npasswd: nis\n','passwd: [NOTFOUND=return] files','passwd: files [BOGUS=return]','passwd: files [NOTFOUND=return','passwd: files []','passwd: files ]','passwd:'):
    try: m.parse_nss(bad)
    except ValueError: pass
    else: raise AssertionError('invalid NSS accepted')
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); inv=p/'hosts'; roles=p/'roles'; nss=p/'nsswitch'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    data='passwd: files sss\ngroup: files sss\nshadow: files\nhosts: files dns\nnetgroup: nis\nservices: vendor_secret\n'
    nss.write_text(data)
    cmd=[str(here/'plan-directory.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    q=run('--list'); assert q.returncode==0 and 'package\tsssd\tNOT_SELECTED\tNOT_RUN' in q.stdout
    q=run('--nss-capture='+str(nss)); assert q.returncode==3
    assert 'nss\tpasswd\tDIRECTORY_REVIEW\tfiles,sss\t0' in q.stdout
    assert 'nss\tnetgroup\tREVIEW_REQUIRED\tnis\t0' in q.stdout
    assert 'remote-lookup\tNOT_RUN' in q.stdout and 'directory-apply\tNOT_AUTHORIZED' in q.stdout
    assert 'vendor_secret' not in q.stdout and nss.read_text()==data
    nss.write_text('passwd: files\npasswd: nis\n'); assert run('--nss-capture='+str(nss)).returncode==2
    nss.unlink(); nss.symlink_to(inv); assert run('--nss-capture='+str(nss)).returncode==2
for task in ('0720','0860','0870','0980','0990'):
    f=next((here/'tasks').glob(task+'_*'))
    q=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True)
    assert q.returncode==0 and q.stdout and not q.stderr
print('Directory policy and NSS capture tests passed')
PY
