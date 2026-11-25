#!/bin/sh
# Test the native transaction primitives on disposable data, not the live CLI.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Native installer test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Native installer test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, os, pathlib, tempfile, sys
here=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('native',here/'native-install.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
uid=os.geteuid(); os.umask(0o077)
assert os.getegid()==uid, 'test needs matching UID/GID'
with tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp); etc=root/'etc'; store=root/'transactions'; etc.mkdir(); store.mkdir()
    initial={'hostname':b'old\n','hosts':b'127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 localhost\n', 'resolv.conf':b'options timeout:2\nnameserver 192.0.2.99\nsearch old.invalid\n'}
    for name, data in initial.items(): (etc/name).write_bytes(data)
    (etc/'hosts').chmod(0o640)
    original=m.snapshot(etc,uid); desired=m.render(root,'node.lab.invalid',here/'site.example.conf',original)
    assert bytes.fromhex(desired['hostname']['data'])==b'node\n'
    assert b'::1 localhost\n' in bytes.fromhex(desired['hosts']['data'])
    assert b'options timeout:2\n' in bytes.fromhex(desired['resolv.conf']['data'])
    ref={'original':m.digest(m.encoded(original)), 'desired':m.digest(m.encoded(desired))}
    def rejected(fn):
        try: fn()
        except (ValueError,OSError): return
        raise AssertionError('unexpected success')
    # Bad reference before first mutation.
    rejected(lambda:m.transition(etc,store,uid,{**ref,'original':'0'*64},original,desired,lambda:True))
    assert not list(store.iterdir()) and m.snapshot(etc,uid)==original
    # Failure at verification after all replacements creates a recoverable journal.
    rejected(lambda:m.transition(etc,store,uid,ref,original,desired,lambda:False))
    path=m.pending(store,uid)[0]; assert m.snapshot(etc,uid)==desired
    assert m.load_journal(path,uid)['state']=='APPLYING'
    rejected(lambda:m.transition(etc,store,uid,ref,original,desired,lambda:True))
    rejected(lambda:m.recover(etc,store,uid,{**ref,'identity':'wrong'},path))
    (etc/'hosts').write_bytes(b'external edit\n'); rejected(lambda:m.recover(etc,store,uid,ref,path))
    (etc/'hosts').write_bytes(bytes.fromhex(desired['hosts']['data']))
    # Inject interruption during rollback; journal remains ROLLING_BACK.
    atomic=m.atomic_write
    def fail_rollback(path,data,mode,owner):
        if path==etc/'hosts': raise OSError('rollback fault')
        return atomic(path,data,mode,owner)
    m.atomic_write=fail_rollback
    rejected(lambda:m.recover(etc,store,uid,ref,path))
    m.atomic_write=atomic
    assert m.load_journal(path,uid)['state']=='ROLLING_BACK'
    m.recover(etc,store,uid,ref,path); assert m.snapshot(etc,uid)==original
    assert m.load_journal(path,uid)['state']=='ROLLED_BACK'
    # Inject actual replacement failure after the first file; recover partial apply.
    atomic=m.atomic_write
    def fail_second(path,data,mode,owner):
        if path==etc/'hosts': raise OSError('test fault')
        return atomic(path,data,mode,owner)
    m.atomic_write=fail_second
    rejected(lambda:m.transition(etc,store,uid,ref,original,desired,lambda:True))
    m.atomic_write=atomic
    path=m.pending(store,uid)[0]; assert m.snapshot(etc,uid)['hostname']==desired['hostname']
    assert m.snapshot(etc,uid)['hosts']==original['hosts']
    m.recover(etc,store,uid,ref,path); assert m.snapshot(etc,uid)==original
    # Extended attributes block rather than disappear.
    os.setxattr(etc/'hosts','user.sasd-test',b'test'); rejected(lambda:m.snapshot(etc,uid)); os.removexattr(etc/'hosts','user.sasd-test')
    # A failed journal sync must prevent target mutation and block further work.
    sync=m.sync_dir
    def fail_sync(path):
        if path==store: raise OSError('journal sync fault')
        return sync(path)
    m.sync_dir=fail_sync
    rejected(lambda:m.transition(etc,store,uid,ref,original,desired,lambda:True))
    m.sync_dir=sync
    assert m.snapshot(etc,uid)==original and (store/'SYNC_FAILED').exists()
    rejected(lambda:m.pending(store,uid))
    # Discard only this deliberately broken disposable store.
    store=root/'new-transactions'; store.mkdir()
    # A successful static commit and a no-change repeat.
    path=m.transition(etc,store,uid,ref,original,desired,lambda:True)
    assert m.load_journal(path,uid)['state']=='COMMITTED_STATIC' and not m.pending(store,uid)
    assert m.snapshot(etc,uid)==desired
    ref2={'original':ref['desired'],'desired':ref['desired']}
    m.transition(etc,store,uid,ref2,desired,desired,lambda:True)
    assert m.snapshot(etc,uid)==desired
    # Closed journal is not recoverable through the open-journal interface.
    rejected(lambda:m.recover(etc,store,uid,ref,path))
print('Native static transaction primitive tests passed')
PY
rc=0; "$here/native-install.py" --review --confirm-disposable-vm --hostname=node.lab.invalid --installation=12345678-1234-4234-8234-123456789abc --fingerprint=invalid --release=invalid >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ]
echo 'Native CLI unprivileged refusal passed'
