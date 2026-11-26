#!/bin/sh
# Real fixture mutations only, no daemon, job, rotation or live configuration changes.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Logging fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Logging fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import grp, importlib.util, json, os, pathlib, pwd, shutil, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('logging_fixture',here/'fixture-logging.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.',dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
    for folder in m.DIRECTORIES: (etc/folder).mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    for n in m.NAMES:
        (etc/n).write_text('old '+n+'\n'); (etc/n).chmod(0o644)
    unrelated=etc/'keep'; unrelated.write_text('untouched\n')
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    cmd=[str(here/'fixture-logging.py'),'--root='+name,'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    r=run('--review'); assert r.returncode==0,r.stderr
    ref.write_text(r.stdout); ref.chmod(0o600); opt='--reference='+str(ref)
    assert run('--verify',opt).returncode==1
    tx=m.transaction(); owner=os.geteuid(); old=tx.snapshot(etc,owner)
    approved=json.loads(ref.read_text())
    desired={n:{'data':v.hex(),'mode':0o644} for n,v in m.render('node.lab.invalid',tx).items()}
    # Optional real logrotate syntax/debug test, scoped to one disposable log.
    binary=shutil.which('logrotate',path='/usr/sbin:/usr/bin:/sbin:/bin')
    if binary:
        logfile=p/'client.log'; logfile.write_text('synthetic log\n')
        rotation=p/'rotation.conf'
        user=pwd.getpwuid(owner).pw_name; group=grp.getgrgid(os.getegid()).gr_name
        text=bytes.fromhex(desired[m.NAMES[1]]['data']).decode('ascii')
        rotation.write_text(text.replace('/var/log/sasd/client.log',str(logfile)).replace('root adm',user+' '+group))
        before=logfile.read_bytes()
        result=subprocess.run([binary,'-d','-s','/dev/null',str(rotation)],capture_output=True,text=True,timeout=30)
        assert result.returncode==0,result.stderr
        assert logfile.read_bytes()==before and not list(p.glob('client.log.*'))
        print('Logrotate disposable debug syntax check passed')
    else:
        print('Logrotate debug check SKIPPED: binary unavailable')
    (etc/m.NAMES[0]).write_text('changed\n')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    (etc/m.NAMES[0]).write_bytes(bytes.fromhex(old[m.NAMES[0]]['data']))
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,'original':old,'desired':desired},'APPLYING',owner)
    for n in m.NAMES[:2]: tx.atomic_write(etc/n,bytes.fromhex(desired[n]['data']),0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==old
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_LOGGING_FIXTURE' in r.stdout
    assert tx.snapshot(etc,owner)==desired and run('--verify',opt).returncode==0
    assert unrelated.read_text()=='untouched\n'
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==2
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tserver\t\tbaseline\n')
    assert run('--review').returncode==2
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tserver\t\tserver\n')
    folder=etc/'logwatch'; moved=etc/'moved'; folder.rename(moved); folder.symlink_to(moved)
    assert run('--review').returncode==2
    folder.unlink(); moved.rename(folder)
    target=etc/m.NAMES[0]; target.unlink(); target.symlink_to(unrelated)
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Logging configuration fixture transaction tests passed')
PY
