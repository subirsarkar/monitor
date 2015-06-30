#!/usr/bin/env perl

use strict;
use warnings;

use dCacheTools::PoolManager;

sub main
{
  # We do not need the detailed info
  my $pm = dCacheTools::PoolManager->instance({ parse_all => 0 });
  my @list = $pm->exec({ command => q|rc ls| });
  for (@list) {
    my $id = (split)[0];
    $pm->exec({ command => qq|rc retry $id -force-all -update-si| });  
  }
  sleep 2;
  @list = $pm->exec({ command => q|rc ls| });
  print join ("\n", @list), "\n" if scalar @list;
}
main;
__END__
