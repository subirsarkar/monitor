#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use File::stat;
use Term::ProgressBar;
use List::Util qw/min max/;

use BaseTools::Util;
use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::Filesize;

# Autoflush
$| = 1;

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

  my $reader = BaseTools::ConfigReader->instance();
  my $pnfspath = $reader->{config}{pnfsroot};

  my @poollist = (scalar @ARGV) 
      ? @ARGV
      : dCacheTools::PoolManager->instance({ parse_all => 0 })->poollist;
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
  
    my @result = $pool->exec({ command => q|rep ls| });
    $pool->alive or next;
    $pool->hasException and next;
  
    foreach (@result) {
      my $pnfsid = (split /\s+/)[0]; 
      my $file = qq|$pnfspath/.(puse)($pnfsid)(0)|;
      my $stats = stat $file;
      defined $stats and next; ## Note and

      $dict->{$poolname}{$pnfsid}++;
  
      print STDERR qq|>>> Non PNFS entry pnfsid=$pnfsid\n| if $verbose;
      eval {
        my $fs = dCacheTools::Filesize->new({ fileid => $pnfsid });
        $fs->show if $verbose;
      };
      if ($@) {
        print STDERR qq|>>> Error finding file properties!\n| if $verbose;
        next;
      }
    }
  }
  $progress->update($ipool) if $ipool > $next_update;
  for my $pool (sort keys %$dict) {
    my $list = $dict->{$pool};
    my @pnfsids = sort keys %$list;
    print STDOUT qq|perl -w removeReplica.pl $pool |. join(' ', @pnfsids) .qq|\n|;
  }
}
main;
__END__
