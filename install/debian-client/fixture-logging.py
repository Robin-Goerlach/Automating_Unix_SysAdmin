#!/usr/bin/python3 -I
"""Review and apply four logging configuration candidates in a private server fixture."""
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-LOGGING-FIXTURE-1'
PREFIX = 'sasd-logging-lab'
MARKER = '.sasd-logging-fixture'
LABEL = 'LOGGING'
DIRECTORIES = ('rsyslog.d', 'logrotate.d', 'default', 'logwatch', 'logwatch/conf')
PROFILES = ('server',)
TASKS = {
    'rsyslog.d/60-sasd-client.conf': '0410_Syslog_Configure',
    'logrotate.d/sasd-client': '0420_Logrotate_Configure',
    'default/sysstat': '0790_Sysstat_Configure',
    'logwatch/conf/logwatch.conf': '0800_Logwatch_Configure',
}
NAMES = tuple(TASKS)

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('fixture_config', HERE / 'fixture-config.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


def transaction():
    return engine.transaction(NAMES)


def render(host, tx):
    # Exact reviewed templates are a narrow fixture contract, not native syntax proof.
    expected = {
        NAMES[0]: b'''# Candidate: /etc/rsyslog.d/60-sasd-client.conf
# Dedicated local5 facility; existing distribution routes remain in effect.
if ($syslogfacility-text == "local5") then {
    action(type="omfile" file="/var/log/sasd/client.log"
           fileCreateMode="0640" fileOwner="root" fileGroup="adm" createDirs="off")
}
''',
        NAMES[1]: b'''# Candidate: /etc/logrotate.d/sasd-client
/var/log/sasd/client.log {
    weekly
    rotate 4
    missingok
    notifempty
    compress
    delaycompress
    su root adm
    create 0640 root adm
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
''',
        NAMES[2]: b'ENABLED="true"\n',
        NAMES[3]: ('MailTo = root@localhost\nMailFrom = logwatch@' + host +
                   '\nDetail = High\nRange = Yesterday\nService = all\n').encode('ascii'),
    }
    for name, task in TASKS.items():
        result = tx.command('/bin/sh', str(HERE / 'tasks' / task), '--hostname=' + host, '--render')
        if result != expected[name]:
            raise ValueError('unexpected logging renderer output')
    return expected


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
