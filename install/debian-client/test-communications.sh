#!/bin/sh
# Offline review tests: never connect to SSH or mail services.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Communications test SKIPPED: python3 unavailable'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import base64, importlib.util, pathlib, struct, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('comms',here/'plan-communications.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def reject(fn):
    try: fn()
    except ValueError: return
    raise AssertionError('unexpected success')
key=base64.b64encode(struct.pack('>I',11)+b'ssh-ed25519'+struct.pack('>I',32)+bytes(range(32))).decode()
line='peer.lab.invalid ssh-ed25519 '+key+'\n'
assert m.public_pins(line)[0][1].startswith('SHA256:')
for bad in (line+line,line.replace('peer.lab.invalid','*'),line.replace('ssh-ed25519','ssh-rsa'),line.replace(key,'AAAA'), '@revoked '+line):
    reject(lambda:m.public_pins(bad))
assert m.sftp_result('subsystem sftp internal-sftp\n')=='RECOGNIZED_STATIC'
assert m.sftp_result('subsystem sftp /usr/lib/openssh/sftp-server\n')=='RECOGNIZED_STATIC'
for bad in ('','subsystem sftp internal-sftp\n'*2,'subsystem sftp /tmp/other\n','subsystem sftp internal-sftp -d /tmp\n'):
    assert m.sftp_result(bad)=='REVIEW_REQUIRED'
assert dict(m.mail_values('relay.lab.invalid','admin@lab.invalid'))['smtp_tls_security_level']=='verify'
for relay,recipient in [('bad;host','admin@lab.invalid'),('relay.lab.invalid','|command@lab.invalid'),('relay.lab.invalid','admin@lab.invalid\nroot: other')]:
    reject(lambda:m.mail_values(relay,recipient))
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); inv=p/'hosts'; roles=p/'roles'; pins=p/'pins'; effective=p/'effective'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    pins.write_text(line); effective.write_text('subsystem sftp internal-sftp\n')
    def run(*args):
        return subprocess.run([str(here/'plan-communications.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles),*args],capture_output=True,text=True)
    r=run(); assert r.returncode==3 and 'INPUT_REQUIRED' in r.stdout
    r=run('--known-hosts='+str(pins),'--sshd-effective='+str(effective),'--relay=relay.lab.invalid','--root-alias=admin@lab.invalid')
    assert r.returncode==3 and 'sftp\tRECOGNIZED_STATIC' in r.stdout and 'postfix\tNOT_SELECTED' in r.stdout
    assert 'mail-candidate\trelayhost\t[relay.lab.invalid]' in r.stdout and key not in r.stdout
    assert 'communications-apply\tNOT_AUTHORIZED' in r.stdout and 'ssh-access\tNOT_TESTED' in r.stdout
    assert run('--relay=node.lab.invalid','--root-alias=admin@lab.invalid').returncode==2
    assert run('--relay=relay.lab.invalid').returncode==2
    (p/'link').symlink_to(pins); assert run('--known-hosts='+str(p/'link')).returncode==2
    assert pins.read_text()==line
for task in ('0430','0440','0450','0480','0490','0500','1030'):
    f=next((here/'tasks').glob(task+'_*'))
    r=subprocess.run([str(f),'--hostname=node.lab.invalid','--render'],capture_output=True,text=True)
    assert r.returncode==0 and r.stdout
print('Communications policy and offline review tests passed')
PY
