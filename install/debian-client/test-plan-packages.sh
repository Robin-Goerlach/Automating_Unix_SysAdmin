#!/bin/sh
# Test package policy and APT result handling without changing the package database.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Package plan test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Package plan test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, pathlib, subprocess, sys, tempfile
from types import SimpleNamespace
from contextlib import redirect_stdout
from io import StringIO
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('packages',here/'plan-packages.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
stages=m.candidates(here/'package-policy.tsv')
assert len(stages['1'])==19 and len(stages['2'])==15
profiles={profile:m.select_profile(stages,here/'package-profiles.tsv',profile) for profile in m.PROFILES}
assert profiles['all-candidates']==stages
assert profiles['baseline']=={'1':['vim','rsync','openssh-client','bc','screen','tmux'],'2':['wget','unix2dos']}
assert profiles['workstation']==profiles['laptop']
assert 'openssh-server' in profiles['server']['1'] and 'openssh-server' not in profiles['workstation']['1']
assert 'cups' in profiles['workstation']['1'] and 'cups' not in profiles['server']['1']
assert all('postfix' not in profiles[p]['1'] for p in m.PROFILES[1:])
assert m.installed_result('ii \t2:9.1-1\n')==('INSTALLED','2:9.1-1')
assert m.installed_result('rc \t1\n')[0]=='NOT_HEALTHY_OR_UNKNOWN'
assert m.simulation_actions('Inst vim:amd64 (2:9.1-1 Debian:13 [amd64])\nConf vim:amd64 (2:9.1-1 Debian:13 [amd64])')==[('Inst','vim:amd64','-','2:9.1-1'),('Conf','vim:amd64','-','2:9.1-1')]
assert m.simulation_actions('Inst vim [1] (2 Debian)\nRemv old [1]')==[('Inst','vim','1','2'),('Remv','old','1','-')]
for stage,task in [('1','0200_Packages_Stage_1'),('2','0730_Packages_Stage_2')]:
    rendered=subprocess.check_output([str(here/'tasks'/task),'--hostname=node.lab.invalid','--render'],text=True).splitlines()
    assert rendered==stages[stage]
assert m.policy_result('vim','')==('NO_LOCAL_RECORD','-','-')
assert m.policy_result('vim','vim:\n  Installed: (none)\n  Candidate: 2:9.1-1\n')==('CANDIDATE','-','2:9.1-1')
assert m.policy_result('vim','vim:\n  Installed: 1\n  Candidate: 1\n')[0]=='INSTALLED_SAME'
assert m.policy_result('vim','vim:\n  Installed: 1\n  Candidate: 2\n')[0]=='VERSION_REVIEW'
assert m.policy_result('vim','vim:\n  Installed: (none)\n  Candidate: (none)\n')[0]=='NO_LOCAL_CANDIDATE'
def rejected(fn):
    try: fn()
    except ValueError: return
    raise AssertionError('unexpected success')
rejected(lambda:m.simulation_actions('Inst --bad (1 Debian)'))
rejected(lambda:m.simulation_actions('Inst vim (1 Debian)\nInst vim (1 Debian)'))
rejected(lambda:m.policy_result('vim','other:\n  Installed: 1\n  Candidate: 1\n'))
rejected(lambda:m.policy_result('vim','vim:\n  Installed: 1\n  Candidate: 1\n  Candidate: 2\n'))
assert m.simulation_result('0 upgraded, 1 newly installed, 0 to remove and 2 not upgraded.\nInst vim (1 Debian)\nConf vim (1 Debian)\n')==('SIMULATED',0,1,0,2)
assert m.simulation_result('1 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.\nInst vim [1] (2 Debian)\n')[0]=='REVIEW_REQUIRED'
assert m.simulation_result('0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.\nRemv vim [1]\n')[0]=='REVIEW_REQUIRED'
rejected(lambda:m.simulation_result('0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.\n'))
with tempfile.TemporaryDirectory() as tmp:
    path=pathlib.Path(tmp)/'policy'; data=(here/'package-policy.tsv').read_text()
    path.write_text(data+'1\tcandidate\tvim\tduplicate\n'); rejected(lambda:m.candidates(path))
    path.write_text(data+'1\tcandidate\t--bad\tinvalid\n'); rejected(lambda:m.candidates(path))
    data=(here/'package-profiles.tsv').read_text()
    path.write_text(data+'1\tserver\tvim\n'); rejected(lambda:m.select_profile(stages,path,'server'))
    path.write_text(data.replace('vim rsync','rsync')); rejected(lambda:m.select_profile(stages,path,'server'))
    path.write_text(data.replace('vim rsync','unknown rsync')); rejected(lambda:m.select_profile(stages,path,'server'))
# Exercise actual CLI logic with synthetic command results; no APT changes.
real=m.command; calls=[]
def fake(*args):
    calls.append(args)
    if args[0].endswith('apt-cache'):
        return SimpleNamespace(returncode=0,stderr='',stdout=args[-1]+':\n  Installed: 1\n  Candidate: 1\n')
    return SimpleNamespace(returncode=0,stderr='',stdout='0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.\n')
m.command=fake
sys.argv=['plan-packages.py','--live','--stage=1','--simulate']; out=StringIO()
with redirect_stdout(out): assert m.main()==0
assert len(calls)==20 and '--simulate' in calls[-1] and '--no-remove' in calls[-1] and 'vim=1' in calls[-1]
assert 'plan-sha256\t' in out.getvalue()
assert 'simulation\tSIMULATED' in out.getvalue() and 'package-apply\tNOT_AUTHORIZED' in out.getvalue()
calls.clear()
def unknown(*args):
    calls.append(args); return SimpleNamespace(returncode=0,stderr='warning',stdout='')
m.command=unknown; out=StringIO()
with redirect_stdout(out): assert m.main()==3
assert len(calls)==19 and 'simulation\tBLOCKED' in out.getvalue()
calls.clear()
sys.argv=['plan-packages.py','--list','--profile=baseline']; out=StringIO()
with redirect_stdout(out): assert m.main()==0
assert not calls and out.getvalue().count('SELECTED')==8
calls.clear()
def dpkg(*args):
    calls.append(args); return SimpleNamespace(returncode=0,stderr='',stdout='ii \t1\n')
m.command=dpkg
sys.argv=['plan-packages.py','--live','--profile=baseline','--verify-installed']; out=StringIO()
with redirect_stdout(out): assert m.main()==0
assert len(calls)==8 and all(c[0].endswith('dpkg-query') for c in calls)
assert out.getvalue().count('\tINSTALLED\t')==8
# A configuration-only action must not be printed as successful simulation.
def conf_only(*args):
    if args[0].endswith('apt-cache'):
        return SimpleNamespace(returncode=0,stderr='',stdout=args[-1]+':\n  Installed: 1\n  Candidate: 1\n')
    return SimpleNamespace(returncode=0,stderr='',stdout='0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.\nConf vim (1 Debian)\n')
m.command=conf_only
sys.argv=['plan-packages.py','--live','--profile=baseline','--simulate']; out=StringIO()
with redirect_stdout(out): assert m.main()==3
assert 'simulation\tREVIEW_REQUIRED' in out.getvalue() and 'simulation\tSIMULATED' not in out.getvalue()
# A selected missing package cannot disappear from the simulated transaction.
def missing_action(*args):
    if args[0].endswith('apt-cache'):
        return SimpleNamespace(returncode=0,stderr='',stdout=args[-1]+':\n  Installed: (none)\n  Candidate: 1\n')
    return SimpleNamespace(returncode=0,stderr='',stdout='0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.\n')
m.command=missing_action; out=StringIO()
with redirect_stdout(out): assert m.main()==3
assert 'simulation\tUNKNOWN' in out.getvalue() and 'plan-sha256' not in out.getvalue()
m.command=real
PY
rc=0; "$here/plan-packages.py" --live --stage=1 > /dev/null || rc=$?
[ "$rc" -eq 0 ] || [ "$rc" -eq 3 ]
echo 'Package candidate and simulation tests passed'
