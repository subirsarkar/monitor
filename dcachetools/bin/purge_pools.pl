#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Time::HiRes qw/usleep/;
use List::Util qw/min max/;
use Term::ProgressBar;

use dCacheTools::PoolGroup;
use dCacheTools::Pool;

our $verbose = '';
our $help    = '';
our $pgroup  = q|cms|;
our $fspace  = 20; # GB

use constant GB2BY => 1024**3;
use constant SPACE_CUTOFF => 50;

sub usage
{
  print <<HEAD;
Purge pools of least used cached files and recover space

The command line options are

-v|--verbose     display debug information (D=false)
-h|--help        show help on this tool and quit (D=false)
-g|--pgroup      pool group (D=cms)
-r|--recover     free up this much space in GB (D=20)

Example usage: perl -w $0 --recover=20
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
            'recover=i' => \$fspace,
           'g|pgroup=s' => \$pgroup;

  $fspace > 0 or $fspace = 20;
  $fspace = min(SPACE_CUTOFF, $fspace);

  $fspace *= GB2BY;
}

sub main
{
  readOptions;

  my $pg = dCacheTools::PoolGroup->new({ name => $pgroup });
  my @poollist = $pg->poollist;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);

  my $it = max 1, int($npools/100);

  my @pspared = ();
  for my $poolname (@poollist) {
    unless ( (++$ipool)%$it ) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    my $space_info = $pool->space_info;
    my $free_space = $space_info->{free};
    $free_space > SPACE_CUTOFF * GB2BY and push (@pspared, $poolname) and next; 
    print qq|>> Purging $poolname\n| if $verbose;
    $pool->exec({ command => qq|sweeper free $fspace| });
    usleep 5000;
  }
  $progress->update($ipool) if $ipool > $next_update;
  print qq|Pools not purged:\n|. join(' ', @pspared), "\n";
}
main;
__END__
