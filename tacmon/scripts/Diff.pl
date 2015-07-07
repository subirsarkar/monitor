#!/usr/bin/env perl

use strict;

use lib qw(/home/cmstac/monitor/bin);
use Util qw(_trim);

# Input
my $file1 = shift;
my $file2 = shift;
my $file3 = shift || "final.list";

# Load arrays with file contents
open(FILE, "<$file1") || die "Can't open $file1\n";
chomp(my @alist = <FILE>);
close(FILE);

open(FILE, "<$file2") || die "Can't open $file2\n";
chomp(my @blist = <FILE>);
close(FILE);

# Set %elements hash to 1 for each
my %elements = ();
foreach (@blist) {
  $elements{_trim($_)} = 1;
};

my @finallist = ();
# Loop to create the final array of emails
for my $line (@alist) {
  $line = _trim($line);
  if (not exists $elements{$line}) {
     push @finallist, $line;
  }
}
my $nlines = scalar @finallist;
unshift @finallist, "$nlines extra Lines in file $file1 not present in file $file2";

# Write final array to file
open(FILE, ">$file3") || die "Can't open $file3\n";
print FILE join "\n", @finallist, "\n";
close(FILE);

__END__

