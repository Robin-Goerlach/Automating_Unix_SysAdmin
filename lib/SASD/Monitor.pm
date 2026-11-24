package SASD::Monitor;

# Small shared parser for the M1 command-line utilities.  It deliberately
# contains no sockets, eval, shell execution, or external module dependency.
use strict;
use Exporter 'import';
use File::Spec;
use Fcntl qw(O_WRONLY O_CREAT O_EXCL);

our @EXPORT_OK = qw(read_config read_inventory read_checks applicable_checks
    validate_status atomic_write read_state read_latest html_escape ensure_dir
    valid_identifier valid_host valid_color valid_path_value now_seconds);

my %CONFIG_KEYS = map { $_ => 1 } qw(inventory roles checks status_dir history_file
    state_file report_file mrtg_file rrd_dir profile freshness history_retention
    mrtg_command);

sub _real_file {
    my ($path, $label) = @_;
    -f $path && !-l $path or die "invalid $label file\n";
}

sub _safe_line {
    my ($s, $label) = @_;
    defined($s) && $s !~ /[\x00-\x1f\x7f]/ or die "unsafe $label\n";
}

sub valid_identifier {
    my ($s) = @_;
    return defined($s) && $s =~ /\A[A-Za-z][A-Za-z0-9_-]{0,31}\z/;
}

sub valid_host {
    my ($s) = @_;
    return defined($s) && $s =~ /\A[A-Za-z0-9](?:[A-Za-z0-9_.-]{0,61}[A-Za-z0-9])?\z/;
}

sub valid_color {
    my ($s) = @_;
    return defined($s) && $s =~ /\A(?:green|yellow|red|purple)\z/;
}

sub valid_path_value {
    my ($s) = @_;
    return 0 unless defined($s) && length($s) && $s !~ m!^/! && $s !~ m!//! &&
        $s =~ m!\A[A-Za-z0-9_.:/-]+\z!;
    $s =~ s!\A\.\./!!;
    return $s !~ m!(?:^|/)\.\.(?:/|$)!;
}

sub _fields {
    my ($line, $count, $label) = @_;
    my @v = split /\t/, $line, -1;
    @v == $count or die "invalid $label record\n";
    _safe_line($_, $label) for @v;
    return @v;
}

sub _resolve {
    my ($base, $value) = @_;
    valid_path_value($value) or die "unsafe configured path: $value\n";
    return File::Spec->canonpath(File::Spec->catfile($base, $value));
}

sub read_config {
    my ($path) = @_;
    _real_file($path, 'configuration');
    my $base = File::Spec->rel2abs($path);
    $base =~ s!/[^/]+\z!!;
    open(my $fh, '<', $path) or die "cannot read configuration: $!\n";
    my %raw;
    while (<$fh>) {
        chomp; s/\r\z//;
        next if /^\s*$/ || /^\s*#/;
        _safe_line($_, 'configuration line');
        /^([A-Za-z][A-Za-z0-9_-]*)=([^\t\r\n]+)\z/ or die "invalid configuration line $.\n";
        my ($key, $value) = ($1, $2);
        $CONFIG_KEYS{$key} or die "unknown configuration key: $key\n";
        exists $raw{$key} and die "duplicate configuration key: $key\n";
        $raw{$key} = $value;
    }
    close $fh;
    my @required = qw(inventory roles checks status_dir history_file state_file
        report_file mrtg_file rrd_dir profile freshness history_retention mrtg_command);
    for (@required) { exists $raw{$_} or die "missing configuration key: $_\n"; }
    valid_path_value($raw{profile}) or die "invalid monitoring profile\n";
    $raw{freshness} =~ /\A[0-9]{1,9}\z/ or die "invalid freshness\n";
    $raw{history_retention} =~ /\A[1-9][0-9]{0,7}\z/ or die "invalid history retention\n";
    my %cfg = %raw;
    $cfg{config_file} = File::Spec->rel2abs($path);
    $cfg{config_dir} = $base;
    for my $key (qw(inventory roles checks status_dir history_file state_file report_file mrtg_file rrd_dir mrtg_command)) {
        $cfg{$key . '_path'} = _resolve($base, $raw{$key});
    }
    return \%cfg;
}

sub _address {
    my ($s) = @_;
    return 0 unless defined($s) && $s =~ /\A(\d+)\.(\d+)\.(\d+)\.(\d+)\z/;
    return $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255;
}

sub read_inventory {
    my ($hosts_path, $roles_path) = @_;
    _real_file($roles_path, 'roles');
    open(my $rf, '<', $roles_path) or die "cannot read roles: $!\n";
    my %roles;
    while (<$rf>) {
        chomp; s/\r\z//; next if /^\s*$/ || /^\s*#/;
        my ($role, $class, $profile, $manifest) = _fields($_, 4, 'role');
        valid_identifier($role) && valid_identifier($class) && valid_path_value($profile) &&
            valid_path_value($manifest) or die "invalid role record at line $.\n";
        exists $roles{$role} and die "duplicate role: $role\n";
        $roles{$role} = { class => $class, profile => $profile, manifest => $manifest };
    }
    close $rf;
    _real_file($hosts_path, 'inventory');
    open(my $hf, '<', $hosts_path) or die "cannot read inventory: $!\n";
    my (%hosts, %addresses);
    while (<$hf>) {
        chomp; s/\r\z//; next if /^\s*$/ || /^\s*#/;
        my ($host, $address, $os, $role, $groups, $profile) = _fields($_, 6, 'host');
        valid_host($host) && _address($address) && $os =~ /\A[A-Za-z0-9_.-]{1,31}\z/ &&
            valid_identifier($role) && valid_path_value($profile) or die "invalid host record at line $.\n";
        exists $roles{$role} or die "unknown role '$role'\n";
        if (length $groups) { valid_identifier($_) or die "invalid host group\n" for split /,/, $groups; }
        exists $hosts{$host} and die "duplicate hostname: $host\n";
        exists $addresses{$address} and die "address assigned to multiple hosts: $address\n";
        $hosts{$host} = { host=>$host, address=>$address, os=>$os, role=>$role,
            groups=>$groups, profile=>$profile };
        $addresses{$address} = $host;
    }
    close $hf;
    scalar(keys %hosts) or die "inventory has no host records\n";
    return (\%hosts, \%roles);
}

sub read_checks {
    my ($path) = @_;
    _real_file($path, 'checks');
    open(my $fh, '<', $path) or die "cannot read checks: $!\n";
    my %checks;
    while (<$fh>) {
        chomp; s/\r\z//; next if /^\s*$/ || /^\s*#/;
        my ($check, $role, $description) = _fields($_, 3, 'check');
        valid_identifier($check) && ($role eq '*' || valid_identifier($role)) &&
            length($description) && length($description) <= 120 or die "invalid check record at line $.\n";
        exists $checks{$check} and die "duplicate check: $check\n";
        $checks{$check} = { role=>$role, description=>$description };
    }
    close $fh;
    scalar(keys %checks) or die "checks file has no checks\n";
    return \%checks;
}

sub applicable_checks {
    my ($host, $checks) = @_;
    return map { $_ } sort grep { $checks->{$_}->{role} eq '*' ||
        $checks->{$_}->{role} eq 'baseline' || $checks->{$_}->{role} eq $host->{role} } keys %$checks;
}

sub validate_status {
    my ($host, $check, $color, $message) = @_;
    valid_host($host) && valid_identifier($check) && valid_color($color) or die "invalid status identifiers\n";
    defined($message) && length($message) <= 240 && $message !~ /[\x00-\x1f\x7f]/ or die "unsafe status message\n";
}

sub now_seconds { return defined($_[0]) ? $_[0] : time(); }

sub ensure_dir {
    my ($path, $mode) = @_;
    -l $path and die "refusing symlink directory: $path\n";
    return if -d $path;
    mkdir($path, defined($mode) ? $mode : 0750) or die "cannot create directory $path: $!\n";
}

sub atomic_write {
    my ($path, $content, $mode) = @_;
    -l $path and die "refusing symlink output: $path\n";
    my ($volume, $dirs, $file) = File::Spec->splitpath($path);
    my $tmp = File::Spec->catpath($volume, $dirs, ".sasd.$$.$file.tmp");
    sysopen(my $fh, $tmp, O_WRONLY|O_CREAT|O_EXCL, defined($mode) ? $mode : 0640)
        or die "cannot create temporary output: $!\n";
    print $fh $content or die "cannot write output: $!\n";
    close($fh) or die "cannot close output: $!\n";
    rename($tmp, $path) or die "cannot install output: $!\n";
}

sub read_latest {
    my ($path) = @_;
    return undef unless -f $path && !-l $path;
    open(my $fh, '<', $path) or die "cannot read latest status: $!\n";
    my $line = <$fh>; close $fh; return undef unless defined $line;
    chomp $line; $line =~ s/\r\z//;
    my @v = split /\t/, $line, -1;
    @v == 6 && $v[0] =~ /\A[0-9]{1,15}\z/ or die "invalid latest status record\n";
    validate_status(@v[1..4]);
    $v[5] =~ /\A[A-Za-z0-9_.:-]{1,64}\z/ or die "invalid latest status source\n";
    return { received=>$v[0], host=>$v[1], check=>$v[2], color=>$v[3], message=>$v[4], source=>$v[5] };
}

sub read_state {
    my ($path) = @_;
    return {} unless -f $path && !-l $path;
    open(my $fh, '<', $path) or die "cannot read state: $!\n";
    my %state;
    while (<$fh>) {
        chomp; s/\r\z//; next if /^\s*$/ || /^\s*#/;
        my @v = split /\t/, $_, -1;
        @v == 8 && $v[0] =~ /\A[0-9]{1,15}\z/ && valid_host($v[1]) && valid_identifier($v[2]) &&
            ($v[3] eq 'none' || valid_color($v[3])) && valid_color($v[4]) or die "invalid state record\n";
        _safe_line($v[7], 'state message');
        $state{$v[1]."\t".$v[2]} = { cycle=>$v[0], host=>$v[1], check=>$v[2], observed=>$v[3],
            state=>$v[4], received=>$v[5], source=>$v[6], message=>$v[7] };
    }
    close $fh;
    return \%state;
}

sub html_escape {
    my ($s) = @_; $s = '' unless defined $s;
    $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g; return $s;
}

1;
