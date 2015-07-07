#!/usr/bin/env perl

use strict;
use warnings;
use File::Basename;

my $inputFile = shift || "./fileProcessed.txt";
my $map = {};
open INPUT, "<$inputFile" || die qq(Could not open $inputFile, $!);
while (<INPUT>) {
  chop;
  my $name = (split)[0];
  $map->{basename $name}++;
}
close INPUT;

for my $key (sort keys %$map) {
  print "$key: $map->{$key}\n" if $map->{$key}>1;
}
