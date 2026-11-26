#!/bin/sh
# Checkpoint persistence and read-only restart assessment using real fixture transactions.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Checkpoint test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Checkpoint test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import fcntl,hashlib,importlib.util,json,os,pathlib,subprocess,sys,tempfile
here=pathlib.Path(sys.argv[1]);host='node.lab.invalid'
spec=importlib.util.spec_from_file_location('checkpoint',here/'orchestration-checkpoint.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as aux, tempfile.TemporaryDirectory(prefix='sasd-banner-lab.',dir='/tmp') as name:
    p=pathlib.Path(aux);root=pathlib.Path(name);etc=root/'etc';store=root/'transactions'
    etc.mkdir(mode=0o700);store.mkdir(mode=0o700)
    group=m.load('fixture-banner');tx=group.engine.transaction(group.NAMES)
    marker=root/group.MARKER;marker.write_text(group.FORMAT+'\n');marker.chmod(0o600)
    for n in group.NAMES:(etc/n).write_text('old\n');(etc/n).chmod(0o644)
    inv=p/'hosts';roles=p/'roles';ref=p/'ref';manifest=p/'manifest';cp=p/'checkpoint.json'
    inv.write_text(host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    common=['--hostname='+host,'--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args):
        return subprocess.run(['/bin/sh',str(here/'install-client.sh'),*args],capture_output=True,text=True)
    args=['--fixture-group=banner','--root='+name,*common]
    r=run(*args,'--review');assert r.returncode==0,r.stderr
    ref.write_text(r.stdout);ref.chmod(0o600)
    r=run(*args,'--apply-fixture','--reference='+str(ref));assert r.returncode==0,r.stderr
    j=next(store.iterdir())
    manifest.write_text(json.dumps({'groups':{'banner':{'root':name,'reference':str(ref),'journal':j.name}}}))
    manifest.chmod(0o600)
    cmd=[*common,'--manifest='+str(manifest),'--checkpoint='+str(cp)]
    def check(mode,status,code,*extra):
        r=run(mode,*cmd,*extra)
        assert r.returncode==code,(r.stdout,r.stderr)
        data=json.loads(r.stdout);assert data['status']==status,data
        assert data['execution']=='NOT_AUTHORIZED' and data['native-verification']=='NOT_VERIFIED'
        assert data['dependency-promotion']=='NOT_AUTHORIZED'
        return data
    saved=check('--checkpoint-save','CHECKPOINT_SAVED',0)
    original=cp.read_bytes();digest=hashlib.sha256(original).hexdigest()
    assert saved['checkpoint-sha256']==digest and cp.stat().st_mode & 0o777==0o600
    opt='--expect-checkpoint='+digest
    check('--checkpoint-resume','CHECKPOINT_MATCH_REVIEW_ONLY',0,opt)
    assert run('--checkpoint-save',*cmd).returncode==2
    assert cp.read_bytes()==original
    assert run('--checkpoint-resume',*cmd).returncode==2
    assert run('--checkpoint-resume',*cmd,'--expect-checkpoint='+'0'*64).returncode==2
    assert run('--checkpoint-resume',*cmd,opt,'--apply-fixture').returncode==2
    target=etc/'issue';old=target.read_bytes();target.write_text('drift\n')
    check('--checkpoint-resume','EVIDENCE_CHANGED',3,opt)
    target.write_bytes(old)
    # A new interrupted journal in the same root blocks restart, even though
    # the originally named committed journal still exists.
    openj=store/'native.00000000000000000000000000000000.json'
    data=tx.load_journal(j,os.geteuid())
    tx.journal_write(openj,data,'APPLYING',os.geteuid())
    observation=check('--checkpoint-resume','RECOVERY_REVIEW_REQUIRED',3,opt)
    assert observation['current']['groups']['banner']['open-journal']==openj.name
    assert openj.exists() and tx.load_journal(openj,os.geteuid())['state']=='APPLYING'
    openj.unlink()
    (store/'SYNC_FAILED').write_text('review\n')
    check('--checkpoint-resume','INSPECTION_BLOCKED',3,opt)
    (store/'SYNC_FAILED').unlink()
    fd=os.open(store,os.O_RDONLY|os.O_DIRECTORY)
    try:
        fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        check('--checkpoint-resume','INSPECTION_BLOCKED',3,opt)
    finally:os.close(fd)
    inv.write_text(host+'\t192.0.2.41\tdebian\tserver\t\tserver\n')
    check('--checkpoint-resume','CONTEXT_CHANGED',3,opt)
    inv.write_text(host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    check('--checkpoint-resume','CHECKPOINT_MATCH_REVIEW_ONLY',0,opt)
    assert cp.read_bytes()==original and target.read_bytes()==old
    cp.write_bytes(original+b' ')
    assert run('--checkpoint-resume',*cmd,opt).returncode==2
    cp.write_bytes(original)
    # Never create a checkpoint inside an existing fixture.
    bad=[*common,'--manifest='+str(manifest),'--checkpoint='+str(root/'bad.json')]
    assert run('--checkpoint-save',*bad).returncode==2
    assert not (root/'bad.json').exists()
print('Immutable checkpoint and restart assessment tests passed')
PY
