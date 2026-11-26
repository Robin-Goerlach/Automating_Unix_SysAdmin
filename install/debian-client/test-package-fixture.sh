#!/bin/sh
# Exercise synthetic package state only; never install packages.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Package fixture test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Package fixture test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, json, os, pathlib, subprocess, sys, tempfile
here = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('packages_fixture', here/'fixture-packages.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
planner = m.engine.load('plan-packages')
stages = planner.select_profile(planner.candidates(here/'package-policy.tsv'),
                                here/'package-profiles.tsv', 'baseline')
def simulation(stage, installed, extra=None):
    selected = [n for s in ('1','2') if stage in (s,'both') for n in stages[s]]
    candidates = dict.fromkeys(selected, '1')
    additions = {n:'1' for n in selected if n not in installed}
    additions.update(extra or {})
    lines = ['0 upgraded, %d newly installed, 0 to remove and 0 not upgraded.' % len(additions)]
    for n,v in additions.items(): lines.append('Inst %s (%s Debian)' % (n,v))
    for n,v in additions.items(): lines.append('Conf %s (%s Debian)' % (n,v))
    return dict(stage=stage, installed=installed, candidates=candidates, simulation='\n'.join(lines)+'\n')
def reject(value):
    try: m.model(value, stages, planner)
    except ValueError: return
    raise AssertionError('invalid plan accepted')
old = {'unrelated':'2', 'vim':'1'}
value = simulation('1', old, {'dependency':'3'})
desired, actions, _ = m.model(value, stages, planner)
assert desired['dependency']=='3' and desired['unrelated']=='2' and len(actions)==12
reject(dict(value, candidates=dict(value['candidates'], extra='1')))
reject(dict(value, installed=dict(old,vim='2')))
reject(dict(value, simulation=value['simulation'].replace('Conf dependency (3', 'Conf dependency (4')))
reject(dict(value, simulation=value['simulation'].replace('Inst dependency (3','Inst dependency [2] (3')))
reject(dict(value, simulation=value['simulation'].replace('Inst dependency (3','Inst dependency:amd64 (3')))
reject(dict(value, simulation=value['simulation'].replace('0 to remove','1 to remove')+'Remv unrelated [2]\n'))
reject(dict(value, simulation=value['simulation']+'unrecognized\n'))
reject(dict(value, simulation=value['simulation'].replace('Conf rsync (1 Debian)\n','')))
reject(dict(value, simulation=value['simulation'].replace('6 newly installed','7 newly installed')))
with tempfile.TemporaryDirectory(prefix=m.PREFIX+'.', dir='/tmp') as name, tempfile.TemporaryDirectory() as aux:
    root=pathlib.Path(name); p=pathlib.Path(aux); etc=root/'etc'; store=root/'transactions'
    etc.mkdir(mode=0o700); store.mkdir(mode=0o700)
    marker=root/m.MARKER; marker.write_text(m.FORMAT+'\n'); marker.chmod(0o600)
    tx=m.engine.transaction(m.NAMES); owner=os.geteuid()
    state=etc/m.NAMES[0]; state.write_bytes(tx.encoded(old)); state.chmod(0o644)
    unrelated=etc/'keep'; unrelated.write_text('untouched\n')
    sim=root/'simulation.json'; sim.write_bytes(tx.encoded(value)); sim.chmod(0o600)
    inv=p/'hosts'; roles=p/'roles'; ref=p/'reference'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    cmd=[str(here/'fixture-packages.py'),'--root='+name,'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args): return subprocess.run([*cmd,*args],capture_output=True,text=True)
    def review():
        r=run('--review'); assert r.returncode==0,r.stderr
        ref.write_text(r.stdout); ref.chmod(0o600)
        return json.loads(r.stdout)
    approved=review(); opt='--reference='+str(ref)
    original=tx.snapshot(etc,owner)
    target={m.NAMES[0]:{'data':tx.encoded(desired).hex(),'mode':0o644}}
    assert run('--verify',opt).returncode==1
    state.write_bytes(tx.encoded({'foreign':'1'}))
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    state.write_bytes(tx.encoded(old))
    sim.write_bytes(tx.encoded(value)+b' ')
    assert run('--apply-fixture',opt).returncode==2 and not list(store.iterdir())
    sim.write_bytes(tx.encoded(value))
    journal=store/'native.1234567890abcdef1234567890abcdef.json'
    tx.journal_write(journal,{'format':'SASD-NATIVE-JOURNAL-1','reference':approved,'original':original,'desired':target},'APPLYING',owner)
    tx.atomic_write(state,tx.encoded(desired),0o644,owner)
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==0
    assert tx.snapshot(etc,owner)==original
    r=run('--apply-fixture',opt); assert r.returncode==0,r.stderr
    assert 'COMMITTED_PACKAGE_FIXTURE' in r.stdout
    assert tx.snapshot(etc,owner)==target and run('--verify',opt).returncode==0
    assert run('--apply-fixture',opt).returncode==2
    assert run('--recover='+journal.name,opt).returncode==2
    # Second stage preserves previous state and installs only its approved additions.
    value2=simulation('2',desired); sim.write_bytes(tx.encoded(value2)); review()
    assert run('--apply-fixture',opt).returncode==0
    final=m.model(value2,stages,planner)[0]
    assert json.loads(state.read_text())==final and run('--verify',opt).returncode==0
    # Replanned repeat is a no-op on package state.
    sim.write_bytes(tx.encoded(simulation('both',final))); review()
    before=state.stat().st_ino
    assert run('--apply-fixture',opt).returncode==0 and state.stat().st_ino==before
    assert unrelated.read_text()=='untouched\n'
    inv.write_text(inv.read_text().replace('baseline','server'))
    assert run('--verify',opt).returncode==2
    inv.write_text(inv.read_text().replace('server','baseline'))
    sim.unlink(); sim.symlink_to(unrelated)
    assert run('--review').returncode==2
    assert subprocess.run([*cmd,'--root=/','--review'],capture_output=True).returncode==2
print('Package fixture model, transaction and recovery tests passed')
PY
