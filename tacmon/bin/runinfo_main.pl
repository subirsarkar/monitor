#!/usr/bin/env perl
package main;

use RunInfo;

my $inputFile = shift || die qq[Usage: $0 inputFile];
open INPUT, "<$inputFile" || die qq[Could not open Input file, $!];
while (<INPUT>) {
  next if /^$/;
  my ($run, $disk, $det) = split;
  #next if RunInfo::existsXML($run);
  print "Processing Run $run\n";
  my $obj = new RunInfo($run, $disk, $det);
  $obj->saveXML;
}
close INPUT;

