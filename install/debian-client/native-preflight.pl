#!/usr/bin/env perl
# Read-only modern Debian diagnostics; not an authorization or apply gate.
use strict;
use warnings;
use Cwd qw(abs_path);
$ENV{LC_ALL} = 'C';
sub fail { print STDERR "native-preflight: $_[0]\n"; exit 2; }
sub fqdn {
    my ($h) = @_;
    return length($h) <= 63 && $h =~ /\./ &&
        !grep { $_ !~ /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/ } split /\./, $h, -1;
}
sub ipv4 {
    my ($ip) = @_;
    my @p = split /\./, $ip, -1;
    return @p == 4 && !grep { $_ !~ /\A(?:0|[1-9][0-9]{0,2})\z/ || $_ > 255 } @p;
}
my %arg;
for (@ARGV) {
    if ($_ eq '--live') { exists $arg{live} and fail('duplicate live'); $arg{live}=1; next; }
    /\A--(root|hostname|address|probe-name|probe-address)=(.+)\z/ or fail('invalid option');
    exists $arg{$1} and fail('duplicate option'); $arg{$1}=$2;
}
(exists $arg{live}) != (exists $arg{root}) or fail('choose exactly one of --live or --root=DIR');
exists $arg{hostname} && fqdn($arg{hostname}) or fail('valid lowercase FQDN required');
exists $arg{address} && ipv4($arg{address}) or fail('canonical IPv4 required');
if (exists $arg{'probe-name'} || exists $arg{'probe-address'}) {
    $arg{live} && exists $arg{'probe-name'} && exists $arg{'probe-address'} &&
        fqdn($arg{'probe-name'}) && ipv4($arg{'probe-address'}) or fail('paired probe options require live mode');
}
my $root = '/';
if (!$arg{live}) {
    $arg{root} =~ m!^/! && -d $arg{root} && !-l $arg{root} or fail('invalid fixture root');
    $root = abs_path($arg{root});
    defined($root) && $root ne '/' or fail('real root requires --live');
}
sub path { return ($root eq '/' ? '' : $root).$_[0]; }
sub emit {
    my ($key,$status,$value)=@_;
    $value = '-' unless defined($value) && length($value);
    $value =~ s/([^\x20-\x7e]|%)/sprintf('%%%02X',ord($1))/ge;
    print join("\t",$key,$status,$value),"\n";
}
sub read_small {
    my ($p)=@_;
    return undef unless -f $p && !-l $p && -r $p && -s $p <= 65536;
    open my $f, '<', $p or return undef;
    my $n=read($f,my $buf,65537); close $f;
    return defined($n) && $n <= 65536 ? $buf : undef;
}
# os-release is data, not executable shell. Follow only the conventional location
# within the selected tree; do not follow arbitrary resolver/hostname symlinks.
sub release {
    my $p=path('/etc/os-release');
    if (-l $p) {
        my $link=readlink($p);
        return undef unless defined($link) && ($link eq '../usr/lib/os-release' || $link eq '/usr/lib/os-release');
        $p=path('/usr/lib/os-release');
    }
    my $s=read_small($p); return undef unless defined $s;
    my %v;
    for (split /\n/, $s) {
        next unless /\A(ID|VERSION_ID)=([A-Za-z0-9_.-]+|"[A-Za-z0-9_.-]+"|'[A-Za-z0-9_.-]+')\z/;
        my ($k,$val)=($1,$2); return undef if exists $v{$k};
        $val =~ s/\A["']|["']\z//g; $v{$k}=$val;
    }
    return \%v;
}
sub resolver_hint {
    my $p=path('/etc/resolv.conf');
    if (-l $p) {
        my $link=readlink($p); return ('UNKNOWN','unreadable link') unless defined $link;
        return ('MANAGED_HINT','systemd-resolved') if $link =~ m!\A(?:/|\.\./)run/systemd/resolve/(?:stub-)?resolv\.conf\z!;
        return ('MANAGED_HINT','resolvconf') if $link =~ m!\A(?:/|\.\./)run/resolvconf/resolv\.conf\z!;
        return ('MANAGED_HINT','NetworkManager') if $link =~ m!\A(?:/|\.\./)run/NetworkManager/(?:no-stub-)?resolv\.conf\z!;
        return ('UNKNOWN','unrecognized symlink');
    }
    my $s=read_small($p); return ('UNKNOWN','missing or unreadable') unless defined $s;
    my @h;
    push @h,'systemd-resolved' if $s =~ /^\s*#.*systemd-resolved/im;
    push @h,'NetworkManager' if $s =~ /^\s*#.*NetworkManager/im;
    push @h,'resolvconf' if $s =~ /^\s*#.*\bresolvconf\b/im;
    push @h,'dhclient' if $s =~ /^\s*#.*dhclient/im;
    return @h ? ('MANAGED_HINT',join(',',@h)) : ('UNKNOWN_REGULAR','ownership unproven');
}
# Commands are bounded and invoked without a shell. Trusted local PATH required.
sub command {
    my (@cmd)=@_;
    my $timeout='/usr/bin/timeout'; return (undef,127) unless -x $timeout;
    open my $fh, '-|', $timeout, '-k', '2s', '5s', @cmd or return (undef,127);
    local $/; my $out=<$fh>; close $fh; my $rc=$?;
    $rc = $rc < 0 ? 127 : ($rc & 127 ? 128+($rc & 127) : $rc >> 8);
    $out='' unless defined $out; $out =~ s/\n\z//;
    return ($out,$rc);
}
print "SASD-NATIVE-PREFLIGHT-1\ncheck\tstatus\tvalue\n";
emit('scope','INFO',$arg{live}?'live-read-only':'fixture-static-only');
emit('expected-host','INFO',$arg{hostname}); emit('expected-ipv4','INFO',$arg{address});
my $os=release();
if (!$os || !defined $os->{ID} || !defined $os->{VERSION_ID}) { emit('os','UNKNOWN','release data incomplete'); }
elsif ($os->{ID} ne 'debian') { emit('os','OUT_OF_SCOPE',"$os->{ID}:$os->{VERSION_ID}"); }
else { emit('os','DETECTED',"debian:$os->{VERSION_ID}"); }
my $short=(split /\./,$arg{hostname})[0];
my $stored=read_small(path('/etc/hostname'));
if (!defined $stored) { emit('stored-hostname','UNKNOWN','missing or unsafe file'); }
else { $stored =~ s/\n\z//; emit('stored-hostname',$stored eq $short?'MATCH':'DRIFT',$stored); }
emit('resolver-owner-hint',resolver_hint());
if ($arg{live}) {
    my ($v,$rc)=command('hostname'); emit('runtime-hostname',$rc?'UNKNOWN':$v eq $short?'MATCH':'DRIFT',$rc?"exit=$rc":$v);
    ($v,$rc)=command('ip','-o','-4','address','show');
    my @ips=defined($v)?($v =~ /\binet ([0-9.]+)\/[0-9]+\b/g):();
    emit('runtime-ipv4',$rc?'UNKNOWN':(grep { $_ eq $arg{address} } @ips)?'MATCH':'DRIFT',$rc?"exit=$rc":join(',',@ips));
    ($v,$rc)=command('systemd-detect-virt'); emit('virtualization',$rc==0?'DETECTED':$rc==1 && $v eq 'none'?'NONE_DETECTED':'UNKNOWN',$rc>1?"exit=$rc":$v);
    for my $service (qw(NetworkManager systemd-resolved networking systemd-networkd)) {
        ($v,$rc)=command('systemctl','is-active',"$service.service");
        emit("service-$service",$rc==0 && $v eq 'active'?'ACTIVE':$v =~ /\A(?:inactive|failed|unknown)\z/ && ($rc==3 || $rc==4)?'NOT_ACTIVE':'UNKNOWN',"exit=$rc");
    }
    if (exists $arg{'probe-name'}) {
        ($v,$rc)=command('hostname','-f'); emit('runtime-fqdn',$rc?'UNKNOWN':$v eq $arg{hostname}?'MATCH':'DRIFT',$rc?"exit=$rc":$v);
        ($v,$rc)=command('getent','ahostsv4',$arg{'probe-name'});
        my %found=map { $_=>1 } ($v =~ /^([0-9.]+)\s/mg);
        emit('nss-probe',$rc?'UNKNOWN':keys(%found)==1 && exists $found{$arg{'probe-address'}}?'MATCH':'DRIFT',$rc?"exit=$rc":join(',',sort keys %found));
    } else { emit('runtime-fqdn','NOT_RUN','opt-in name probe required'); emit('nss-probe','NOT_RUN','opt-in name probe required'); }
} else {
    for (qw(runtime-hostname runtime-ipv4 virtualization service-NetworkManager service-systemd-resolved service-networking service-systemd-networkd runtime-fqdn nss-probe)) { emit($_,'NOT_RUN','fixture'); }
}
emit('direct-dns','NOT_RUN','NSS is not direct DNS evidence');
emit('native-apply','NOT_AUTHORIZED','diagnostics only');
exit 0;
