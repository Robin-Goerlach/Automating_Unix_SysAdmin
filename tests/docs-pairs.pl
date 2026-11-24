#!/usr/bin/env perl
# Check German companions and obvious local Markdown links.
use strict;
use File::Spec;

open(FILES, '-|', 'git', 'ls-files', '--', '*.md') or die "cannot enumerate Markdown files: $!\n";
my @files;
while (<FILES>) { chomp; s/\r\z//; push @files, $_ if length $_; }
close FILES or die "git ls-files failed\n";
my ($missing,$bad_links)=(0,0);
for my $file (@files) {
    next if $file =~ /\.de\.md\z/;
    my $german = $file; $german =~ s/\.md\z/.de.md/;
    if (!-f $german || -l $german) { print "MISSING\t$file\t$german\n"; $missing++; }
    open(IN, '<', $file) or die "cannot read $file: $!\n";
    my ($line_no,$line)=(0,'');
    while ($line=<IN>) {
        $line_no++;
        while ($line =~ /\[[^\]]*\]\(([^)]+)\)/g) {
            my $target=$1; $target =~ s/^<|>$//g; $target =~ s/[?#].*\z//;
            next if $target eq '' || $target =~ m!^[A-Za-z][A-Za-z0-9+.-]*:! || $target =~ m!^//!;
            my $path=File::Spec->canonpath(File::Spec->catfile(File::Spec->rel2abs(File::Spec->curdir), File::Spec->catfile((File::Spec->splitpath($file))[1], $target)));
            my $ok=(-f $path || -d $path);
            if (!$ok) { print "BROKEN\t$file:$line_no\t$target\n"; $bad_links++; }
        }
    }
    close IN;
}
print "documents=",scalar(@files)," missing=$missing broken_links=$bad_links\n";
exit($missing || $bad_links ? 1 : 0);
