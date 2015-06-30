#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Term::ProgressBar;
use List::Util qw/min max/;

use dCacheTools::PoolManager;
use dCacheTools::Pool;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';

sub usage
{
  print <<HEAD;
Shows current P2P transfer detail

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)

Example usage:
perl -w $0 --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage;
}
sub main
{
  readOptions;
  my @poollist = (scalar @ARGV) ? @ARGV
                                : dCacheTools::PoolManager->instance({ parse_all => 0 })->poollist;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);
  
  my $it = max 1, int($npools/100);
  my $info = {};
  for my $pname (@poollist) {
    unless ((++$ipool)%$it) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $pname });
    $pool->online or next;
    print ">>> Processing $pname\n" if $verbose;
  
    # Now check pp ls and p2p ls on each pool 
    my @output = $pool->exec({ command => qq|pp ls\np2p ls| });
    scalar @output and $info->{$pname} = \@output;
  }
  $progress->update($ipool) if $ipool > $next_update;

  # Now print out
  for my $pool (sort keys %$info) {
    print join("\n", $pool, @{$info->{$pool}}), "\n";
  }
}
main;
__END__
