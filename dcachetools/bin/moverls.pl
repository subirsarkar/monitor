#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Term::ProgressBar;
use List::Util qw/min max/;
use Data::Dumper;

use dCacheTools::PoolManager;
use dCacheTools::Pool;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';

sub usage
{
  print <<HEAD;
Shows current mover list for all the pools

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
                                : dCacheTools::PoolManager->instance({parse_all => 0})->poollist;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);
  
  my $info = {};
  my $it = max 1, int($npools/100);
  for my $pname (@poollist) {
    unless ((++$ipool)%$it) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $pname });
    $info->{$pname}{message} = qq|$pool did not respond| and next 
      unless $pool->online;
    print qq|>>> Processing $pname\n| if $verbose;
    my @output = $pool->exec({ command => q|mover ls| });
    $info->{$pname}{movers} = \@output if scalar @output;
  }
  $progress->update($ipool) if $ipool > $next_update;
  print Data::Dumper->Dump([$info], [qw/info/]) if $verbose;
  for my $pool (sort keys %$info) {
    defined $info->{$pool}{message} and print $info->{$pool}{message}, "\n" and next;
    my $movers = $info->{$pool}{movers};
    print join ("\n", $pool, '-' x length($pool), @$movers), "\n";
  }
}
main;
__END__
