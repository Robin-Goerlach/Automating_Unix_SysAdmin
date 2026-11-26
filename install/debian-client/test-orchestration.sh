#!/bin/sh
# Read-only planning: never apply, render or promote a dependency.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Orchestration test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Orchestration test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import json,pathlib,subprocess,sys,tempfile
here=pathlib.Path(sys.argv[1]); host='node.lab.invalid'
with tempfile.TemporaryDirectory() as name:
    p=pathlib.Path(name); inv=p/'hosts'; roles=p/'roles'
    inv.write_text(host+'\t192.0.2.40\tdebian\tserver\t\tserver\n')
    roles.write_text('server\tsite_server\tmodern\troles/server.tsv\n')
    cmd=['/bin/sh',str(here/'install-client.sh'),'--orchestration-plan','--hostname='+host,
         '--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args):
        return subprocess.run([*cmd,*args],capture_output=True,text=True)
    def plan(*args):
        r=run(*args); assert r.returncode==0,r.stderr
        return json.loads(r.stdout)
    full=plan()
    assert full==plan()
    assert len(full['tasks'])==116
    assert [r['id'] for r in full['tasks']]==['%04d'%i for i in range(10,1161,10)]
    assert full['scope']=='READ_ONLY_PLANNING' and full['native-verification']=='NOT_VERIFIED'
    assert full['execution']==full['dependency-promotion']=='NOT_AUTHORIZED'
    edges=[e for r in full['tasks'] for e in r['prerequisites']]
    assert sum(e['status']=='WAIT_VERIFIED' for e in edges)==54
    assert sum(e['status']=='WAIT_CANDIDATE' for e in edges)==3
    assert all(r['installed']=='NOT_CERTIFIED' for r in full['tasks'])
    assert all(r['native-execution']=='NOT_AUTHORIZED' for r in full['tasks'])
    assert len(full['groups'])==11 and full['evidence-groups']=={}
    assert full['evidence-report-sha256'] is None
    assert all(not r['prerequisites'] for r in full['tasks'] if r['id'] in full['next-review'])
    part=plan('--only=0050')
    assert [r['id'] for r in part['tasks']]==['0030','0040','0050']
    assert part['next-review']==['0030']
    assert [r['next-action'] for r in part['tasks']]==['REVIEW_CANDIDATE','WAIT_CANDIDATE','WAIT_CANDIDATE']
    assert part['inventory-plan']==full['inventory-plan']
    assert part['selected-plan-sha256']!=full['selected-plan-sha256']
    assert [r['id'] for r in plan('--only=1090')['tasks']]==['0730','0880','1090']
    assert plan('--only=1090')['tasks'][-1]['next-action']=='WAIT_VERIFIED'
    assert plan('--only=0060')['operator-review']==['0060']
    for args in (['--only=9999'],['--only=5'],['--only=0050','--only=0060'],
                 ['--apply-fixture'],['--verify'],['--evidence-report'],['--manifest='+str(p/'missing')]):
        assert run(*args).returncode==2,args
    inv.write_text(host+'\t192.0.2.41\tdebian\tserver\t\tserver\n')
    assert plan()['inventory-plan']!=full['inventory-plan']
print('Canonical orchestration plan and dependency closure tests passed')
PY
