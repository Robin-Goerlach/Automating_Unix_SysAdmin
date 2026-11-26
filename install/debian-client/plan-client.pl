#!/usr/bin/env perl
# Modern Debian planning only; never executes a task or writes system files.
use strict;
use warnings;
use FindBin qw($RealBin);
use File::Spec;

sub fail { die "client-plan: $_[0]\n"; }
sub regular { -f $_[0] && !-l $_[0] && -r $_[0] }
sub rows {
    my ($path, $header, $consume) = @_;
    regular($path) or fail("invalid file: $path");
    open my $fh, '<', $path or fail("cannot read $path");
    my $first = <$fh>;
    defined($first) or fail("empty file: $path");
    chomp $first;
    $first eq $header or fail("invalid header: $path");
    while (my $line = <$fh>) {
        chomp $line;
        $line !~ /[\x00-\x08\x0a-\x1f\x7f]/ or fail("control character: $path");
        $consume->(split /\t/, $line, -1);
    }
    close $fh or fail("read error: $path");
}
my %arg;
for (@ARGV) {
    /\A--(hostname|inventory|roles|only|host-state)=(.+)\z/ or fail('invalid argument');
    exists $arg{$1} and fail("duplicate option: $1");
    $arg{$1} = $2;
}
for (qw(hostname inventory roles)) { exists $arg{$_} or fail("missing --$_"); }
my $host = $arg{hostname};
sub fqdn {
    my ($h) = @_;
    return length($h) <= 63 && $h =~ /\./ && $h !~ /\.\z/ &&
        !grep { $_ !~ /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/ } split /\./, $h, -1;
}
fqdn($host) or fail('expected lowercase R2 FQDN (max 63 characters)');
!exists($arg{only}) || $arg{only} =~ /\A[0-9]{4}\z/ or fail('invalid task number');
my $validator = "$RealBin/../../bin/sasd-site-inventory";
my $monitor = "$RealBin/../../lib/SASD/Monitor.pm";
# Distribution archives carry a byte-for-byte copy of the canonical validator.
if (-e "$RealBin/lib/sasd-site-inventory" || -l "$RealBin/lib/sasd-site-inventory") {
    $validator = "$RealBin/lib/sasd-site-inventory";
    $monitor = "$RealBin/lib/SASD/Monitor.pm";
}
regular($validator) or fail('R2 inventory validator unavailable');
regular($monitor) or fail('R2 inventory module unavailable');
for (qw(inventory roles)) {
    $arg{$_} = File::Spec->rel2abs($arg{$_});
    regular($arg{$_}) or fail("invalid $_ file");
}
# Consume one validated R2 snapshot, preserving empty group fields.
open my $inv, '-|', $^X, $validator, '--input', $arg{inventory}, '--roles', $arg{roles}, '--list'
    or fail('cannot start R2 validator');
my (%names, %ips, %inventory_hosts, $record);
while (my $line = <$inv>) {
    chomp $line;
    my @v = split /\t/, $line, -1;
    @v == 6 or fail('unexpected R2 record');
    my ($name, $ip) = @v;
    $names{lc $name}++ and fail('case-insensitive duplicate host');
    my $canonical = join '.', map { 0 + $_ } split /\./, $ip;
    $canonical eq $ip or fail('noncanonical IPv4 in inventory');
    $ips{$canonical}++ and fail('duplicate canonical IPv4');
    $inventory_hosts{$name} = 1;
    $record = \@v if $name eq $host;
}
close $inv or fail('R2 validation failed');
$record or fail('host not registered in R2 inventory');
$record->[2] eq 'debian' or fail('selected OS family must be debian');
# Explicit lifecycle mode uses the same canonical parser as site management.
# Legacy planning without this option remains read-only, not authorization.
if (exists $arg{'host-state'}) {
    my $state_path = File::Spec->rel2abs($arg{'host-state'});
    regular($state_path) or fail('explicit host state file unavailable');
    require $monitor;
    my $states = SASD::Monitor::read_host_state($state_path, \%inventory_hosts, 0);
    exists($states->{$host}) && $states->{$host}->{state} eq 'enabled'
        or fail('explicit enabled host state required');
}

my (%tasks, %deps, %edges);
rows("$RealBin/checklist.tsv", "id\toriginal_line\ttask\tstate\thandler", sub {
    @_ == 5 or fail('invalid catalog row');
    my ($id, $line, $name, $state, $handler) = @_;
    $id =~ /\A[0-9]{4}\z/ && $line =~ /\A[1-9][0-9]*\z/ && $name =~ /\A[A-Za-z0-9_]+\z/ &&
        $state =~ /\A(?:render|deferred|manual|central|review)\z/ &&
        ($state eq 'render' ? $handler =~ /\A[a-z0-9]+\z/ : $handler eq '-') or fail('invalid catalog fields');
    exists $tasks{$id} and fail("duplicate task: $id");
    regular("$RealBin/tasks/${id}_$name") or fail("missing or unsafe task: $id");
    $tasks{$id} = [$name, $state];
});
keys %tasks or fail('empty catalog');
-d "$RealBin/tasks" && !-l "$RealBin/tasks" or fail('unsafe tasks directory');
opendir my $td, "$RealBin/tasks" or fail('cannot list tasks');
for my $name (readdir $td) {
    next if $name eq '.' || $name eq '..';
    $name =~ /\A([0-9]{4})_([A-Za-z0-9_]+)\z/ && exists $tasks{$1} && $tasks{$1}[0] eq $2
        or fail("uncatalogued task: $name");
}
closedir $td;
rows("$RealBin/dependencies.tsv", "task\tprerequisite\tevidence", sub {
    @_ == 3 or fail('invalid dependency row');
    my ($task, $prereq, $kind) = @_;
    exists $tasks{$task} && exists $tasks{$prereq} or fail('unknown dependency task');
    $prereq lt $task or fail("dependency must precede task: $task/$prereq");
    $kind =~ /\A(?:candidate|verified)\z/ or fail('invalid evidence kind');
    $edges{"$task:$prereq"}++ and fail('duplicate dependency');
    $kind ne 'candidate' || $tasks{$prereq}[1] eq 'render' or fail('candidate prerequisite cannot render');
    push @{$deps{$task}}, [$prereq, $kind];
});
my %selected;
sub select_task {
    my ($id) = @_;
    exists $tasks{$id} or fail("unknown selected task: $id");
    return if $selected{$id}++;
    select_task($_->[0]) for @{$deps{$id} || []};
}
if (exists $arg{only}) { select_task($arg{only}); } else { $selected{$_}=1 for keys %tasks; }
# Planning status is intentionally not an execution or verification result.
my %status;
print "SASD-CLIENT-PLAN-1\n";
print join("\t", 'host', @$record), "\n";
print "id\ttask\tcategory\tplan_status\tprerequisites\n";
for my $id (sort keys %selected) {
    my ($name, $category) = @{$tasks{$id}};
    my @d = sort { $a->[0] cmp $b->[0] } @{$deps{$id} || []};
    my $s = $category eq 'render' ? 'PLAN_CANDIDATE' : uc($category);
    if (grep { $_->[1] eq 'verified' } @d) { $s = 'WAIT_VERIFIED'; }
    elsif (grep { $status{$_->[0]} ne 'PLAN_CANDIDATE' } @d) { $s = 'WAIT_CANDIDATE'; }
    $status{$id} = $s;
    print join("\t", $id, $name, $category, $s, @d ? join(',', map { join(':', @$_) } @d) : '-'), "\n";
}
exit 0;
