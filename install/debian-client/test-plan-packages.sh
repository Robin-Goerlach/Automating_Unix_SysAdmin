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
assert len(calls)==20 and '--simulate' in calls[-1] and '--no-remove' in calls[-1]
assert 'simulation\tSIMULATED' in out.getvalue() and 'package-apply\tNOT_AUTHORIZED' in out.getvalue()
calls.clear()
def unknown(*args):
    calls.append(args); return SimpleNamespace(returncode=0,stderr='warning',stdout='')
m.command=unknown; out=StringIO()
with redirect_stdout(out): assert m.main()==3
assert len(calls)==19 and 'simulation\tBLOCKED' in out.getvalue()
m.command=real
PY
rc=0; "$here/plan-packages.py" --live --stage=1 > /dev/null || rc=$?
[ "$rc" -eq 0 ] || [ "$rc" -eq 3 ]
echo 'Package candidate and simulation tests passed'
