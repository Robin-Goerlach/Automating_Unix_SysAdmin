#!/bin/sh
# Offline boot/recovery observations; never change bootloader, kernel or devices.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Recovery plan test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Recovery plan test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('recoveryplan',here/'plan-recovery.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
assert dict(m.parameters('root=fixture-private ipv6.disable=1 selinux=0 enforcing=1\n'))=={'ipv6.disable':'1','selinux':'0','enforcing':'1'}
assert dict(m.parameters('ipv6.disable=1 ipv6.disable=0'))['ipv6.disable']=='AMBIGUOUS'
assert dict(m.parameters('ipv6.disable'))['ipv6.disable']=='REVIEW_REQUIRED'
assert dict(m.parameters('quiet'))['selinux']=='NOT_EXPLICIT'
assert dict(m.modules('firewire_ohci 123 0 - Live 0x0\n'))['firewire_ohci']=='LISTED'
assert dict(m.modules(''))['usb_storage']=='NOT_LISTED'
assert m.selinux_state('capability,selinux\n','1\n')==('LISTED','ENFORCING_OBSERVED')
assert m.selinux_state('capability\n','1')==('NOT_LISTED','INCONSISTENT_REVIEW')
assert m.selinux_state(None,None)==('UNKNOWN','UNKNOWN')
for fn in [lambda:m.parameters('root="x y"'),lambda:m.modules('bad'),lambda:m.binary_state('2'),lambda:m.selinux_state('selinux,selinux','1')]:
    try: fn()
    except ValueError: pass
    else: raise AssertionError('unexpected success')
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); inv=p/'hosts'; roles=p/'roles'; capture=p/'capture'; capture.mkdir()
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    (capture/'cmdline').write_text('root=fixture-private ipv6.disable=1\n')
    (capture/'modules').write_text('usb_storage 123 0 - Live 0x0\n')
    (capture/'ipv6-all').write_text('1\n')
    (capture/'lsm').write_text('capability,selinux\n')
    (capture/'enforce').write_text('1\n')
    cmd=[str(here/'plan-recovery.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    q=run('--list'); assert q.returncode==0 and 'package\trear\tNOT_SELECTED\tNOT_RUN' in q.stdout
    opts=['--capture='+str(capture)]
    q=run(*opts); assert q.returncode==3
    assert 'kernel-parameter\tipv6.disable\t1' in q.stdout and 'module\tusb_storage\tLISTED' in q.stdout
    assert 'kernel-setting\tipv6-default\tUNKNOWN' in q.stdout and 'selinux\tmode\tENFORCING_OBSERVED' in q.stdout
    assert 'recovery-media\tNOT_CREATED' in q.stdout and 'recovery-apply\tNOT_AUTHORIZED' in q.stdout
    assert 'fixture-private' not in q.stdout+q.stderr and '0x0' not in q.stdout
    assert (capture/'cmdline').read_text()=='root=fixture-private ipv6.disable=1\n'
    (capture/'ipv6-all').write_text('2\n'); assert run(*opts).returncode==2
    (capture/'ipv6-all').unlink(); (capture/'cmdline').unlink(); assert run(*opts).returncode==2
    (capture/'cmdline').symlink_to(inv); assert run(*opts).returncode==2
for task in ('0170','0180','0310','0810','0850','0880'):
    f=next((here/'tasks').glob(task+'_*'))
    q=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True)
    assert q.returncode==0 and q.stdout and not q.stderr
print('Boot protection and recovery planning tests passed')
PY
