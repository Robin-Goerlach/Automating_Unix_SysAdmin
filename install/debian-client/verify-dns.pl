#!/usr/bin/env perl
# Read-only, single-record DNS acceptance probe for an operator-owned lab.
use strict;
use warnings;
$ENV{LC_ALL} = 'C';
sub fail { print STDERR "verify-dns: $_[0]\n"; exit 2; }
sub ipv4 {
    my @p = split /\./, $_[0], -1;
    return @p == 4 && !grep { $_ !~ /\A(?:0|[1-9][0-9]{0,2})\z/ || $_ > 255 } @p;
}
sub fqdn {
    my $n = shift;
    return length($n) <= 253 && $n =~ /\./ && !grep {
        length($_)>63 || $_ !~ /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/
    } split /\./, $n, -1;
}
my %a;
for (@ARGV) {
    if ($_ eq '--live') { exists $a{live} and fail('duplicate option'); $a{live}=1; next; }
    /\A--(server|name|expected|fixture)=(.+)\z/ or fail('invalid option');
    exists $a{$1} and fail('duplicate option'); $a{$1}=$2;
}
(exists $a{live}) != (exists $a{fixture}) or fail('choose --live or --fixture=FILE');
for (qw(server name expected)) { exists $a{$_} or fail("missing --$_"); }
ipv4($a{server}) && ipv4($a{expected}) && fqdn($a{name}) or fail('invalid server, name or expected address');
my $scope = $a{live} ? 'LIVE_DNS' : 'FIXTURE_ONLY';
sub result {
    my ($status,$reason,$exit)=@_;
    print "SASD-DNS-VERIFY-1\nscope\t$scope\nserver\t$a{server}\nname\t$a{name}\nexpected\t$a{expected}\nstatus\t$status\nreason\t$reason\n";
    exit $exit;
}
my $fh;
if ($a{live}) {
    -x '/usr/bin/dig' && -x '/usr/bin/timeout' or result('UNKNOWN','required-tool-missing',3);
    # -r ignores user .digrc; absolute query name prevents search expansion.
    open $fh, '-|', '/usr/bin/timeout','-k','1s','6s','/usr/bin/dig', '-r',
        '@'.$a{server}, $a{name}.'.', 'A', '+time=2', '+tries=1',
        '+noall', '+comments', '+question', '+answer', '+stats'
        or result('UNKNOWN','tool-start-failed',3);
} else {
    -f $a{fixture} && !-l $a{fixture} && -r $a{fixture} or fail('invalid fixture');
    open $fh, '<', $a{fixture} or fail('cannot read fixture');
}
my $out='';
while (1) {
    my $n=read($fh,my $chunk,4096);
    defined($n) or result('UNKNOWN','read-failed',3);
    last unless $n;
    $out.=$chunk;
    length($out)<=65536 or result('UNKNOWN','output-too-large',3);
}
close $fh or result('UNKNOWN','query-or-read-failed',3);
# Inspect only the expected dig response sections; reject ambiguous output.
my (@headers,@flags,@servers,@questions,@answers);
my $section='';
for my $line (split /\n/, $out) {
    if ($line =~ /^;; ->>HEADER<<- opcode: (\w+), status: (\w+), id: \d+\s*$/) { push @headers,[$1,$2]; next; }
    if ($line =~ /^;; flags: ([a-z ]+); QUERY: (\d+), ANSWER: (\d+), AUTHORITY: \d+, ADDITIONAL: \d+\s*$/) { push @flags,[$1,$2,$3]; next; }
    if ($line =~ /^;; SERVER: ([0-9.]+)#53\([^\r\n]*\)(?: \((?:UDP|TCP)\))?\s*$/) { push @servers,$1; next; }
    if ($line =~ /^;; ([A-Z]+) SECTION:\s*$/) { $section=$1; next; }
    next if $line =~ /^\s*$/ || $line =~ /^;;/;
    if ($section eq 'QUESTION') { push @questions,$line; }
    elsif ($section eq 'ANSWER') { push @answers,$line; }
}
@headers==1 && @flags==1 && @servers==1 && @questions==1
    or result('UNKNOWN','ambiguous-response',3);
my ($opcode,$status)=@{$headers[0]};
my ($flags,$qcount,$acount)=@{$flags[0]};
my %flags=map { $_=>1 } split /\s+/, $flags;
my $name=quotemeta($a{name}.'.');
$opcode eq 'QUERY' && $flags{qr} && !$flags{tc} && $qcount==1 && $servers[0] eq $a{server}
    && $questions[0] =~ /^;$name\s+IN\s+A\s*$/i
    or result('UNKNOWN','response-context-mismatch',3);
$status eq 'NOERROR' or result('MISMATCH','dns-response-status',1);
$acount==1 && @answers==1 or result('MISMATCH','expected-single-answer',1);
$answers[0] =~ /^$name\s+\d+\s+IN\s+A\s+([0-9.]+)\s*$/i
    or result('MISMATCH','unexpected-answer-owner-or-type',1);
my $observed=$1;
ipv4($observed) && $observed eq $a{expected} or result('MISMATCH','unexpected-address',1);
result($a{live}?'MATCH':'FIXTURE_MATCH','single-a-record',0);
