#!/usr/bin/env perl

use strict;
use warnings;
use Collector::PBS::GridmapParser;

sub main
{
  # parser files for this CE
  my $parser = new Collector::PBS::GridmapParser;
  $parser->save;
}
main
__END__


