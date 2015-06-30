#!/usr/bin/env perl
package main;

use strict;
use warnings;

use dCacheTools::Pool;

sub main
{
  my ($poolname, $maxspace) = @_;

  my $pool = dCacheTools::Pool->new({ name => $poolname });
  die qq|Pool $poolname may be dead, stopped| unless $pool->alive({refresh => 1});

  my $command = qq|set max diskspace $maxspace\nsave|; # in g
  print $pool->exec({ command => $command }), "\n";
}
my $poolname = shift || die qq|$0 poolname new_space_size_in_GB|;
my $space    = shift || die qq|$0 poolname new_space_size_in_GB|;
main($poolname, $space);
__END__
