#!/usr/bin/env perl
# SASD: detect Windows CRLF in Unix scripts before POSIX shell parses them.
# Perl is already required for the project's historical runtime.
use strict;
my $checked = 0;
my $bad = 0;
for my $file (@ARGV) {
    next unless -f $file;
    open(IN, '<', $file) or die "cannot inspect $file: $!\n";
    binmode(IN);
    $checked++;
    my $line = 0;
    while (my $record = <IN>) {
        $line++;
        if ($record =~ /\r/) {
            print STDERR "ERROR: CRLF or carriage return in $file line $line; convert to LF (see README)\n";
            $bad++;
            last;
        }
    }
    close(IN);
}
$checked or die "no source files found for line-ending check\n";
exit($bad ? 1 : 0);
