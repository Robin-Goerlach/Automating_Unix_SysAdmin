#!/bin/sh
# Combined canonical R2 and native lifecycle contract, no privileged calls.
set -eu
[ -x /usr/bin/python3 ] || { echo 'R2 lifecycle test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'R2 lifecycle test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -I -B - "$here" <<'PY'
import importlib.util, os, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('native',here/'native-install.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
host='node.lab.invalid'; owner=os.geteuid()
with tempfile.TemporaryDirectory() as name:
    root=pathlib.Path(name)
    inventory=root/'hosts.tsv'; roles=root/'roles.tsv'; state=root/'host-state.tsv'
    legacy=host+'\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n'
    enabled=host+'\tenabled\tapproved lab\n'
    marker='# SASD-SITE-INVENTORY-1\n'
    def put(path,data):
        path.write_text(data,encoding='ascii');path.chmod(0o600)
    put(inventory,legacy)
    put(roles,'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    put(root/'site.conf','dns1=192.0.2.53\nsearch=lab.invalid\n')
    put(state,enabled)
    command=['/usr/bin/perl',str(here/'plan-client.pl'),'--hostname='+host,
             '--inventory='+str(inventory),'--roles='+str(roles)]
    def plan(*args):
        return subprocess.run([*command,*args],capture_output=True)
    def expected():
        return m.digest(state.read_bytes())
    def native(digest=None):
        return m.approved_plan(root,owner,host,expected() if digest is None else digest)
    def reject(fn):
        try: fn()
        except (OSError,ValueError,subprocess.SubprocessError): return
        raise AssertionError('unsafe native context accepted')
    plain=plan();assert plain.returncode==0,plain.stderr
    bound=plan('--host-state='+str(state));assert bound.returncode==0,bound.stderr
    assert plain.stdout==bound.stdout
    hashes, result=native()
    assert result==plain.stdout and hashes['host-state.tsv']==expected()
    assert len(result.splitlines())==119
    old={'inputs':hashes,'plan':m.digest(result)}
    m.match_approval(old,old)
    put(inventory,marker+legacy)
    marked=plan('--host-state='+str(state));assert marked.returncode==0,marked.stderr
    assert marked.stdout==plain.stdout and native()[1]==result
    for bad in ('# SASD-SITE-INVENTORY-2\n'+legacy,legacy+marker,marker+marker+legacy,
                marker+legacy+legacy,marker+legacy.replace('192.0.2.40','192.0.2.040'),
                marker+legacy.replace('workstation','unknown'),
                marker+legacy.replace('baseline\n','server\n')):
        put(inventory,bad)
        assert plan().returncode!=0
        reject(native)
    put(inventory,legacy)
    for bad in ('', '# no explicit state\n',host+'\tdisabled\tmaintenance\n',
                host+'\tremoved\tretired\n',host+'\tunknown\tbad\n',enabled+enabled,
                enabled+'other.lab.invalid\tenabled\tunknown\n'):
        put(state,bad)
        assert plan().returncode==0 # deliberately legacy read-only
        assert plan('--host-state='+str(state)).returncode!=0
        reject(native)
    put(state,enabled); pinned=expected()
    put(state,host+'\tenabled\tnew approval\n')
    reject(lambda:native(pinned))
    new_hashes,new_plan=native()
    reject(lambda:m.match_approval(old,{'inputs':new_hashes,'plan':m.digest(new_plan)}))
    # Removed tombstones for hosts absent from inventory are canonical and allowed.
    put(state,enabled+'retired.lab.invalid\tremoved\tretired\n')
    assert native()[1]==result
    state.chmod(0o644);reject(native);state.chmod(0o600)
    data=state.read_bytes();state.unlink()
    reject(lambda:native(pinned))
    outside=root/'other-state';outside.write_bytes(data);outside.chmod(0o600)
    state.symlink_to(outside);reject(lambda:native(pinned));state.unlink()
    put(state,enabled)
    # Simulate change while the canonical parser runs, before any mutation.
    original=m.command
    def changed(*args):
        answer=original(*args)
        put(state,host+'\tdisabled\tchanged during review\n')
        return answer
    m.command=changed
    reject(lambda:native(pinned))
    m.command=original
    assert (root/'site.conf').read_text()=='dns1=192.0.2.53\nsearch=lab.invalid\n'
    # Use real transaction primitives with the same guard as the native CLI.
    # All state changes here are synthetic; never restore stale lifecycle in a VM.
    put(state,enabled); pinned=expected()
    hashes, result=native()
    etc=root/'etc';store=root/'transactions';etc.mkdir();store.mkdir()
    for name in m.NAMES: put(etc/name,'original '+name+'\n')
    original=m.snapshot(etc,owner)
    desired={n:{'data':('desired '+n+'\n').encode().hex(),'mode':v['mode']}
             for n,v in original.items()}
    ref={'inputs':hashes,'plan':m.digest(result),
         'original':m.digest(m.encoded(original)),'desired':m.digest(m.encoded(desired))}
    auth=root/'authorization.json'
    auth.write_bytes(m.encoded(ref));auth.chmod(0o600)
    def guard(): m.recheck_approval(root,owner,host,pinned,hashes,result,ref)
    auth.chmod(0o644);reject(guard);auth.chmod(0o600)
    auth.write_bytes(m.encoded(dict(ref,extra='changed')));reject(guard)
    auth.write_bytes(m.encoded(ref))
    guard()
    atomic=m.atomic_write
    def disable_after_write(path,data,mode,uid):
        atomic(path,data,mode,uid)
        if path==etc/'hostname':
            put(state,host+'\tdisabled\tchanged during apply\n')
    m.atomic_write=disable_after_write
    reject(lambda:m.transition(etc,store,owner,ref,original,desired,lambda:True,guard=guard))
    m.atomic_write=atomic
    journal,=m.pending(store,owner)
    partial=m.snapshot(etc,owner)
    assert partial==dict(original,hostname=desired['hostname'])
    assert m.load_journal(journal,owner)['state']=='APPLYING'
    reject(lambda:m.recover(etc,store,owner,ref,journal,guard=guard))
    assert m.snapshot(etc,owner)==partial and m.load_journal(journal,owner)['state']=='APPLYING'
    # Reset this test-only simulated authority to exercise unchanged-context recovery.
    put(state,enabled)
    m.recover(etc,store,owner,ref,journal,guard=guard)
    assert m.snapshot(etc,owner)==original
    journal=m.transition(etc,store,owner,ref,original,desired,lambda:True,guard=guard)
    assert m.load_journal(journal,owner)['state']=='COMMITTED_STATIC'
    # An open rollback halted by revoked authorization remains open.
    reverse=dict(ref,original=ref['desired'],desired=ref['original'])
    auth.write_bytes(m.encoded(reverse))
    def reverse_guard(): m.recheck_approval(root,owner,host,pinned,hashes,result,reverse)
    reject(lambda:m.transition(etc,store,owner,reverse,desired,original,lambda:False,guard=reverse_guard))
    journal,=m.pending(store,owner)
    def revoke_after_write(path,data,mode,uid):
        atomic(path,data,mode,uid)
        if path==etc/'hostname': auth.unlink()
    m.atomic_write=revoke_after_write
    reject(lambda:m.recover(etc,store,owner,reverse,journal,guard=reverse_guard))
    m.atomic_write=atomic
    assert m.load_journal(journal,owner)['state']=='ROLLING_BACK'
    assert m.snapshot(etc,owner)==dict(original,hostname=desired['hostname'])
    auth.write_bytes(m.encoded(reverse));auth.chmod(0o600)
    m.recover(etc,store,owner,reverse,journal,guard=reverse_guard)
    assert m.snapshot(etc,owner)==desired and not m.pending(store,owner)
print('R2 explicit lifecycle, versioned inventory and native context tests passed (fixture only)')
PY
