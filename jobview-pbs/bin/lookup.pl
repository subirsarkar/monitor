#!/usr/bin/env perl

use strict;
use warnings;
use Storable;
use Data::Dumper;

sub printMap
{
  my $file = shift;
  # Read stored info about the DN->VO mapping
  my $info = {};
  eval {
    $info = retrieve $file;
  };
  print qq|Error reading from file, $file: $@| if $@;
  print Data::Dumper->Dump([$info], [qw/info/]);    

  while ( my ($jid) = each %$info ) {
    print join("##", $jid, $info->{$jid}{dn} || '?'), "\n";
  }
}
printMap(qq|/opt/jobview/db/dnmap.db|);
__END__


