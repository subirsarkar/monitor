#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;

use Term::ProgressBar;
use List::Util qw/min max/;

use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::P2P;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';
our $kforce  = undef;
our $kall = undef;

sub usage
{
  print <<HEAD;
Change the number of movers associated with each kind of transfer

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-f|--force      kill p2p by force (server side)
-a|--all        kill all the p2p transfers

Example usage:
perl -w $0 --force --verbose [poollist] 
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
                 'all'  => \$kall,
               'force!' => \$kforce or usage;
}

sub main
{
  readOptions;

  my @poollist = (scalar @ARGV) 
     ? @ARGV
     : dCacheTools::PoolManager->instance({parse_all => 0})->poollist;

  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({
      name => sprintf (qq|Pools: %d, processed|, $npools), 
     count => $npools, 
    remove => 1, 
       ETA => 'linear'
  });
  $progress->minor(0);

  my $it = max 1, int($npools/100);
  for my $spname (@poollist) {
    unless ((++$ipool)%$it) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $server_pool = dCacheTools::Pool->new({ name => $spname });
    $server_pool->online or next;

    # Check p2p ls on each pool 
    my @output = $server_pool->exec({ command => q|p2p ls| });
    $kall or @output = grep { m#bytes=-?\d time/sec=0# or m#bytes=-?\d time/sec=\d{5,}# } @output;
    for (@output) {
      my $p2p = dCacheTools::P2P->new({ 
         input => $_, 
        server => $server_pool
      });
      $p2p->cancel if ($kforce or $p2p->waiting or $p2p->stuck);
    }
  }
  $progress->update($ipool) if $ipool > $next_update;
}
main;
__END__
server (p2p ls)
1412 A H {cmsdcache13_16@cmsdcache13Domain:0} 000800000000000008035D10 h={SM={a=2079810497;u=2079810497};S=None} bytes=253489380 time/sec=16233 LM=16208
1380 A H {cmsdcache13_15@cmsdcache13Domain:0} 000800000000000008022708 h={SM={a=2232210790;u=2232210790};S=None} bytes=336325620 time/sec=18689 LM=18686
1382 A H {cmsdcache13_17@cmsdcache13Domain:0} 00080000000000000837AF90 h={SM={a=1596262454;u=1596262454};S=None} bytes=436987380 time/sec=18221 LM=18219

client (pp ls)
1038 000800000000000008035D10 FSM.Connected
