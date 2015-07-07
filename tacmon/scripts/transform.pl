#!/usr/bin/env perl

use strict;
use warnings;

my $name = shift || die "Usage: $0 string";
$name =~ s#\.dat#\.root#;
$name =~ s/tif\.(\d+)\.A\.testStorageManager_0\.(\d+)(.*)/sprintf("EDM%s_%3.3d%s",$1,$2,$3);/e; # execute
print $name;

__END__
perl -w transform.pl tif.00002891.A.testStorageManager_0.26.dat
