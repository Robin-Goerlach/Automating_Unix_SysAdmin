#!/bin/sh
# Collect two independent committed fixture journals, never native evidence.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Evidence test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Evidence test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util,json,os,pathlib,subprocess,sys,tempfile
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('evidence',here/'fixture-evidence.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
host='node.lab.invalid'
with tempfile.TemporaryDirectory() as aux, tempfile.TemporaryDirectory(prefix='sasd-banner-lab.',dir='/tmp') as bn, tempfile.TemporaryDirectory(prefix='sasd-logging-lab.',dir='/tmp') as ln:
    p=pathlib.Path(aux); inv=p/'hosts'; roles=p/'roles'; manifest=p/'manifest'
    inv.write_text(host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    common=['--hostname='+host,'--inventory='+str(inv),'--roles='+str(roles)]
    groups={}
    def run(*args):
        return subprocess.run(['/bin/sh',str(here/'install-client.sh'),*args],capture_output=True,text=True)
    for group,name in [('banner',bn),('logging',ln)]:
        mod=m.load('fixture-'+group)
        root=pathlib.Path(name); etc=root/'etc';store=root/'transactions'
        etc.mkdir(mode=0o700);store.mkdir(mode=0o700)
        for d in mod.DIRECTORIES:(etc/d).mkdir(mode=0o700)
        mark=root/mod.MARKER;mark.write_text(mod.FORMAT+'\n');mark.chmod(0o600)
        for n in mod.NAMES:(etc/n).write_text('old\n');(etc/n).chmod(0o644)
        args=['--fixture-group='+group,'--root='+name,*common]
        ref=p/(group+'.ref')
        r=run(*args,'--review');assert r.returncode==0,r.stderr
        ref.write_text(r.stdout);ref.chmod(0o600)
        r=run(*args,'--apply-fixture','--reference='+str(ref));assert r.returncode==0,r.stderr
        journal=next(store.iterdir()).name
        groups[group]={'root':name,'reference':str(ref),'journal':journal}
    def write():
        manifest.write_text(json.dumps({'groups':groups}));manifest.chmod(0o600)
    write()
    cmd=['--evidence-report',*common,'--manifest='+str(manifest)]
    r=run(*cmd);assert r.returncode==0,r.stderr
    result=json.loads(r.stdout)
    assert result['scope']=='FIXTURE_STATIC_ONLY' and result['consistency']=='SEQUENTIAL_NOT_ATOMIC'
    assert result['native-verification']=='NOT_VERIFIED' and result['dependency-promotion']=='NOT_AUTHORIZED'
    assert len(result['tasks'])==116 and len(result['dependencies'])==57
    assert all(x['installed']=='NOT_CERTIFIED' for x in result['tasks'])
    assert sum(x['status']=='WAIT_VERIFIED' for x in result['dependencies'])==54
    assert sum(x['status']=='WAIT_CANDIDATE' for x in result['dependencies'])==3
    assert all(x['status']=='STATIC_COMMITTED_MATCH' for x in result['groups'].values())
    orchestration=['--orchestration-plan',*common,'--manifest='+str(manifest)]
    planned=run(*orchestration);assert planned.returncode==0,planned.stderr
    plan=json.loads(planned.stdout)
    assert plan['groups']['logging']['observation']=='STATIC_COMMITTED_MATCH'
    assert plan['groups']['banner']['observation']=='STATIC_COMMITTED_MATCH'
    assert plan['evidence-report-sha256'] is not None
    assert all(r['native-execution']=='NOT_AUTHORIZED' for r in plan['tasks'])
    assert next(r for r in plan['tasks'] if r['id']=='0420')['next-action']=='WAIT_VERIFIED'
    assert bn not in r.stdout and ln not in r.stdout and 'Unauthorized access' not in r.stdout
    target=pathlib.Path(bn)/'etc/issue';old=target.read_bytes();target.write_text('drift\n')
    r=run(*cmd);assert r.returncode==3,r.stderr
    assert json.loads(r.stdout)['groups']['banner']['status']=='NOT_VERIFIED'
    planned=run(*orchestration);assert planned.returncode==3,planned.stderr
    assert json.loads(planned.stdout)['groups']['banner']['observation']=='NOT_VERIFIED'
    target.write_bytes(old)
    journal=pathlib.Path(bn)/'transactions'/groups['banner']['journal']
    saved=journal.read_bytes()
    j=json.loads(saved);j['state']='ROLLED_BACK';journal.write_text(json.dumps(j))
    assert run(*cmd).returncode==3
    j['state']='APPLYING';journal.write_text(json.dumps(j))
    assert run(*cmd).returncode==3
    journal.write_bytes(saved)
    assert run(*cmd).returncode==0
    inv.write_text(host+'\t192.0.2.41\tdebian\tserver\t\tserver\n')
    assert run(*cmd).returncode==2
    inv.write_text(host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    original=groups['banner']['journal'];groups['banner']['journal']='native.'+'0'*32+'.json';write()
    assert run(*cmd).returncode==3
    groups['banner']['journal']=original;write()
    ref=pathlib.Path(groups['banner']['reference']);saved=ref.read_bytes()
    j=json.loads(saved);j['release']='0'*64;ref.write_text(json.dumps(j))
    assert run(*cmd).returncode==2
    ref.write_bytes(saved)
    groups['baseline']=groups['banner'];write();assert run(*cmd).returncode==2
    del groups['baseline'];write()
    assert run(*cmd,'--manifest='+str(manifest)).returncode==2
    assert run(*cmd,'--apply-fixture').returncode==2
    assert run(*cmd).returncode==0
print('Cross-group committed fixture evidence tests passed')
PY
