#!/usr/bin/env perl

$run = 7690;
opendir(DIR, qq[/data3/TOB/run]) || die "Can't open directory, $!\n";
my @files = readdir(DIR);
@files = grep { /(?:RU|tif\.)(?:.*)$run(?:.*)\.(?:root|dat)$/ } @files; 
print join ("\n", @files), "\n";

#$_ = "/data3/TOB/run/RU0007690_007.root";
#$_ =~ m/RU(.*)$run(?:.*)\.(?:root|dat)$/;
#print $1;

