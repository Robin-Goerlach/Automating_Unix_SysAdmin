#!/usr/bin/env perl
# Exercise the documented offline macro contract without a product parser
# and without evaluating generated text as a shell command.
use strict;

my ($file,$host,$service) = @ARGV;
open(my $fh, '<', $file) or die "cannot read candidate: $!\n";
my (%commands,@targets);
my ($type,%object);
while (<$fh>) {
    chomp;
    if (/^define ([a-z]+)\{$/) {
        $type = $1;
        %object = ();
    } elsif (defined $type && /^\s*([a-z_]+)\s+(.+)$/) {
        $object{$1} = $2;
    } elsif (defined $type && /^\}$/) {
        if ($type eq 'command') {
            $commands{$object{command_name}} = $object{command_line};
        }
        if (($type eq 'host' && $service eq '-') ||
            ($type eq 'service' && ($object{service_description} || '') eq $service)) {
            push @targets, $object{check_command} if ($object{host_name} || '') eq $host;
        }
        undef $type;
    }
}
close $fh or die "cannot close candidate: $!\n";
@targets == 1 or die "candidate command target must be unique\n";
my ($name,$check,$path) = split /!/, $targets[0], -1;
defined($path) && join('!', $name,$check,$path) eq $targets[0] or die "invalid command arguments\n";
$check =~ /\A[A-Za-z][A-Za-z0-9_-]{0,31}\z/ &&
    $host =~ /\A[A-Za-z0-9][A-Za-z0-9_.-]{0,62}\z/ &&
    $path =~ m!\A(?:-|/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*)\z! &&
    $path !~ m!/(?:\.|\.\.)(?:/|\z)! or die "unsafe candidate arguments\n";

my $contract = '$USER1$/sasd-check-plugin --plugin $USER1$/sasd-check-adapter --check sasd --arg $ARG1$ --arg $HOSTNAME$ --arg $ARG2$';
exists($commands{$name}) && $commands{$name} eq $contract or die "unsupported command template\n";
my %macros = (USER1 => 'bin', ARG1 => $check, HOSTNAME => $host, ARG2 => $path);
my @command = map { s/\$([A-Z0-9]+)\$/$macros{$1}/g; $_ } split / /, $commands{$name};
exec {$command[0]} @command or die "cannot run candidate command: $!\n";
