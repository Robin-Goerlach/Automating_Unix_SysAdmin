#!/bin/sh
# Offline IPv4 and APT source candidate tests; no network or APT changes.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Network plan test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Network plan test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
/usr/bin/python3 -B - "$here" <<'PY'
import importlib.util, json, pathlib, subprocess, sys, tempfile
here=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('network',here/'plan-network.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
a=[{'ifname':'eth0','flags':['UP'],'addr_info':[{'family':'inet','local':'192.0.2.40','prefixlen':24,'scope':'global'}]}]
r=[{'dst':'default','gateway':'192.0.2.1','dev':'eth0'}]
assert m.observe_network(a,r,'192.0.2.40','192.0.2.1')==('MATCH_CONFIGURED','MATCH_CONFIGURED',1)
assert m.observe_network(a,r,'192.0.2.41','192.0.2.1')==('MISSING','REVIEW_REQUIRED',1)
assert m.observe_network(a,r*2,'192.0.2.40','192.0.2.1')[1]=='AMBIGUOUS'
assert m.observe_network(a,r,'192.0.2.40','192.0.2.2')[1]=='MISMATCH'
assert m.observe_network(a,[],'192.0.2.40','192.0.2.1')[1]=='MISSING'
assert m.observe_network(a,r,'192.0.2.40')[1]=='NOT_REQUESTED'
assert m.observe_network(a+[dict(a[0],ifname='eth1')],r,'192.0.2.40')[0]=='AMBIGUOUS'
assert m.observe_network([dict(a[0],flags=[])],r,'192.0.2.40')[0]=='REVIEW_REQUIRED'
assert m.observe_network(a,[dict(r[0],nexthops=[])],'192.0.2.40','192.0.2.1')[1]=='REVIEW_REQUIRED'
def reject(fn):
    try: fn()
    except ValueError: return
    raise AssertionError('unexpected success')
reject(lambda:m.observe_network([{'ifname':'x'}],r,'192.0.2.40'))
reject(lambda:m.observe_network({},r,'192.0.2.40'))
reject(lambda:m.observe_network(a,r,'127.0.0.1'))
reject(lambda:m.apt_candidate('stable'))
for version,codename in m.RELEASES.items():
    candidate=m.apt_candidate(version)
    assert 'Suites: '+codename+' '+codename+'-updates\n' in candidate
    assert 'Suites: '+codename+'-security\n' in candidate
    assert candidate.count('Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg')==2
    assert 'stable' not in candidate and 'Trusted:' not in candidate
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); inv=p/'hosts'; roles=p/'roles'; addr=p/'addresses'; route=p/'routes'
    inv.write_text('node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n')
    roles.write_text('workstation\tsite_workstation\tmodern\troles/workstation.tsv\n')
    addr.write_text(json.dumps(a)); route.write_text(json.dumps(r))
    cmd=[str(here/'plan-network.py'),'--hostname=node.lab.invalid','--inventory='+str(inv),'--roles='+str(roles)]
    def run(*args):
        return subprocess.run([*cmd,*args],capture_output=True,text=True)
    q=run('--list','--release=12')
    assert q.returncode==0 and 'Suites: bookworm bookworm-updates' in q.stdout
    opts=['--capture','--addresses='+str(addr),'--routes='+str(route),'--gateway=192.0.2.1','--release=13']
    q=run(*opts)
    assert q.returncode==3 and 'ipv4\tMATCH_CONFIGURED' in q.stdout and 'default-route\tMATCH_CONFIGURED' in q.stdout
    assert 'Suites: trixie-security' in q.stdout and 'network-apply\tNOT_AUTHORIZED' in q.stdout
    assert '192.0.2.40' not in q.stdout and '192.0.2.1' not in q.stdout and 'eth0' not in q.stdout
    assert 'connectivity\tNOT_TESTED' in q.stdout
    assert run('--capture','--addresses='+str(addr)).returncode==2
    assert run('--live','--release=13').returncode==2
    addr.write_text('{"x":1,"x":2}'); assert run(*opts).returncode==2
    addr.unlink(); addr.symlink_to(route); assert run(*opts).returncode==2
for task in ('0020','0050','0210','0220','0230','0240','0250','0260','0270','0280','0370','0400'):
    f=next((here/'tasks').glob(task+'_*'))
    q=subprocess.run([str(f),'--hostname=node.lab.invalid','--site='+str(here/'site.example.conf'),'--render'],capture_output=True,text=True)
    assert q.returncode==0 and q.stdout and not q.stderr
    if task=='0370':
        first=next((here/'tasks').glob('0010_*'))
        assert q.stdout==subprocess.check_output([str(first),'--hostname=node.lab.invalid','--site='+str(here/'site.example.conf'),'--render'],text=True)
print('Network policy, IPv4 and APT source candidate tests passed')
PY
