#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Term::ProgressBar;
use List::Util qw/min max/;

use dCacheTools::Admin;
use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::Mover;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';
our $pattern = q|dcap-|;
our $dryrun  = '';
our $dmax    = 86400; # seconds
our $lmax    = 7200; 

sub usage
{
  print <<HEAD;
Kill the dead DCap transfers/movers

The command line options are

-v|--verbose    display debug information       (D=false)
-h|--help       show help on this tool and quit (D=false)
-p|--pattern    dcap domain name pattern        (D=dcap-cmsdcdcap)
-d|--dryrun     take action                     (D=false)
-t|--max-time   maximum duration beyond which the transfer is assumed to be dead (D=86400 sec)
-l|--max-lm     maximum lm beyond which the transfer is assumed to be dead (D=7200)

Example usage:
perl -w $0 --pattern=dcap-cmsdcdcap --dryrun
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
            'pattern=s' => \$pattern,
         't|max-time=i' => \$dmax,
           'l|max-lm=i' => \$lmax,
              'dryrun!' => \$dryrun;
}
sub main
{
  readOptions;

  my $mi = dCacheTools::Mover->new;
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
  my $dict = {};
  my $it = max 1, int($npools/100);
  for my $poolname (@poollist) {
    unless ((++$ipool)%$it) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    print STDERR qq|>>> Processing $poolname\n| if $verbose;
  
    # regexp will not be recompiled for Perl 5.6+, so no need to use /o
    my @output = grep { /$pattern/ } $pool->exec({ command => q|mover ls| });
    $pool->alive or next;

    for (@output) {
      $mi->moverls($_);
      my $id = $mi->id;
      my $t  = $mi->duration;
      my $lm = $mi->lm;
      ($t > $dmax and $lm > $lmax) or next;
      $dict->{$poolname}{$id} = [$t, $lm];
      $pool->exec({ command => qq|mover kill $id| }) unless $dryrun;
    }
  }
  $progress->update($ipool) if $ipool > $next_update;
  print Data::Dumper->Dump([$dict], [qw/info/]) if $verbose;

  print q|>>> movers| . (($dryrun)? ' to be ' : ' ') . qq|removed:\n|;
  for my $pool (sort keys %$dict) {
    print STDERR join ("\n", $pool, '-' x length($pool)), "\n";
    my $list = $dict->{$pool};
    for my $id (keys %$list) {
      printf STDERR qq|mover=%d (t=%d, lm=%d)\n|, 
        $id, $dict->{$pool}{$id}[0], $dict->{$pool}{$id}[1];
    }
  }
}
main;
__END__
