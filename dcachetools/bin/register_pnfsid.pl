#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw/usleep/;
use Term::ProgressBar;
use List::Util qw/max min/;

use dCacheTools::PoolManager;
use dCacheTools::Pool;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';

sub usage
{
  print <<HEAD;
(Re)register all the pnfsid to respective pools

The command line options are

-v|--verbose    display debug information       (D=false)
-h|--help       show help on this tool and quit (D=false)

Example usage:
perl -w $0 --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage;
}
sub main
{
  readOptions;

  my @poollist = (scalar @ARGV) 
       ? @ARGV
       : dCacheTools::PoolManager->instance({parse_all => 0})->poollist;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $it = max 1, int($npools/100);
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);
  my $dict = {};
  for my $poolname (@poollist) {
    unless ((++$ipool)%$it) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    print qq|Processing $poolname\n| if $verbose;
  
    my @output = $pool->exec({ command => q|pnfs register| });
    $dict->{$poolname} = qq|Problem re-registering PNFSIDs to $poolname! Please check.| if scalar @output;
    print join("\n", $pool->exec({ command => q|show pinboard 10| })), "\n" if $verbose;
    sleep 2; # seconds
  }
  $progress->update($ipool) if $ipool > $next_update;
  for my $pool (sort keys %$dict) {
    print join(' ', $pool, ' => ', $dict->{$pool}), "\n";
  }
}
main;
__END__
