#!/usr/bin/env perl

use strict;
use warnings;

use constant DEBUG => 0;

my $dict = {};

for my $file (@ARGV) {
  next if !-e $file;
  open INPUT, "<$file" or die qq[Cannot open $file, $!];
  while (<INPUT>) {
    chomp;
    my $file = (split)[0];
    my ($disk, $det, $base) = (split m#\/#, $file)[1,3,-1];
    print join (" ", $disk, $det, $base), "\n" if DEBUG; 
    my $runPart = (split /_/, $base)[0];
    my $run = -1;
    if ($runPart =~ /EDM000(\d+)/) {
       $run = $1;
    }
    elsif ($runPart =~ /tif\.0000(\d+)\.A.testStorageManager/) {
       $run = $1;
    }
    next if $run == -1;
    $dict->{$run} = [$disk, $det] if not exists $dict->{$run};
  }
  close INPUT;
}

for my $b (sort keys %$dict) {
  print join (" ", $b, $dict->{$b}[0], $dict->{$b}[1]), "\n";
}
__END__
/data3/EDMProcessed/TIBTOB/edm_2007_03_31/EDM0005141_000.root
EDM0007252
tif.00006920.A.testStorageManager
