#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Collector::Util qw/restoreInfo/;
sub printMap
{
  my $file = shift;
  my $info = restoreInfo($file);
  print Data::Dumper->Dump([$info], [qw/info/]);    
}
my $file = shift || die qq|Usage: $0 dbfile|;
printMap($file);
__END__
