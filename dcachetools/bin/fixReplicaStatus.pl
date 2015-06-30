#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw/usleep/;
use List::Util qw/shuffle/;

use BaseTools::ConfigReader;
use BaseTools::MyStore;
use dCacheTools::Companion;
use dCacheTools::PnfsManager;
use dCacheTools::PoolGroup;
use dCacheTools::Pool;
use dCacheTools::Replica;

# Command line options with Getopt::Long
our $verbose  = '';
our $help     = '';
our $pnfsroot = undef;
our $dryrun   = undef;
our $pgroup   = q|cms|;

use constant MINUTE => 60;

sub usage
{
  print <<HEAD;
Fix status of entries which do not have any precious replica. This tool simply
make one such replica precious

The command line options are

-v|--verbose   display debug information (D=false)
-h|--help      show help on this tool and quit (D=false)
-d|--dryrun    just show entries which need attention
-p|--pnfsroot  pnfs namespace to prepend to filename (D=config)
-g|--pgroup    PoolGroup (D=cms)

Example usage:
perl -w $0 --dryrun
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!'   => \$verbose,
             'help!'      => \&usage,
             'pnfsroot=s' => \$pnfsroot,
             'g|pgroup=s' => \$pgroup,
             'dryrun'     => \$dryrun;

  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }
  print qq|INFO. Will make entries precious as I move along\n| unless defined $dryrun;
}

sub filename
{
  my ($pnfsid, $store, $pnfsH, $pnfsroot) = @_;
  my $pfn;
  if ( $store->contains($pnfsid) ) {
    $pfn = $store->get($pnfsid);
  }
  else {
    $pfn = $pnfsH->pathfinder($pnfsid);
    (defined $pfn) ? $store->add($pnfsid, $pfn) : ($pfn = '?');
  }
  $pfn =~ s#$pnfsroot##;
  $pfn;
}
sub main
{
  readOptions;

  my $reader = BaseTools::ConfigReader->instance();
  my $dbc    = dCacheTools::Companion->new;
  my $pnfsH  = dCacheTools::PnfsManager->instance();

  my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};
  my $dbfile   = qq|$cacheDir/pnfsid2pfn.db|;
  my $store    = BaseTools::MyStore->new({ dbfile => $dbfile });

  my $nentries = 0;
  my $tstart = time;
  my $pg = dCacheTools::PoolGroup->new({ name => $pgroup });
  my $ri = dCacheTools::Replica->new;
  my $pdict = {};
  for my $poolname ($pg->poollist) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    warn qq|Pool $poolname is not enabled/active, skipped\n| 
      and next unless $pool->online;
    print qq|>>> $poolname\n|;
    my @list = $pool->exec({ command => qq|sweeper ls| });
    ($pool->alive and not $pool->hasException) 
       or warn qq|Pool $poolname did not respond! skipped\n| and next;
    $nentries += scalar @list;
    for (@list) {
      my ($pnfsid, $status, $size, $si) = (split /\s+/);
      # one pnfsid should be treated only once 
      exists $pdict->{$pnfsid} and next; 
      ++$pdict->{$pnfsid};
      my @poolList = $dbc->pools({ pnfsid => $pnfsid });
      my $nprec = 0;
      my $ndead = 0;
      my $rinfo = {};
      for (grep {$_ ne $poolname } @poolList) {
        my $px = dCacheTools::Pool->new({ name => $_ }); 
        $px->online or 
          (warn qq|Pool $_ is not enabled/active, $pnfsid skipped\n| and ++$ndead and next);
        # there is a possibility that the pool is momentarily unresponsive
        my $natt = 0;
        my @result = $px->exec({ command => qq|rep ls -l $pnfsid| });
        until ($px->alive and not $px->hasException) {
	  warn qq|Pool $_ is not responding! retrying, attempt:$natt ...|;
          @result = $px->exec({ command => qq|rep ls -l $pnfsid| });
          last if ++$natt > 2;
          usleep 5000;
        }
        ($px->alive and not $px->hasException) or
          (warn qq|Pool $_ did not respond! $pnfsid skipped\n| and ++$ndead and next);
        $ri->repls($result[0]);
        $ri->precious and ++$nprec;
        $rinfo->{$_} = $result[0];
      }
      ($nprec or $ndead) and next;
      my $pfn = filename($pnfsid, $store, $pnfsH, $pnfsroot);
      printf qq|>>> $pnfsid does not have a precious replica!\nlfn:$pfn\npools:\n|; 
      for my $p (sort keys %$rinfo) {
        printf qq|%15s %s\n|, $p, $rinfo->{$p};
      }

      # mark the replica as precious
      $dryrun and next;

      $pool->exec({ command => qq|rep set precious $pnfsid -force| });
      usleep 5000;
    }
  }
  my $duration = time() - $tstart;
  printf qq|>>> Processed %d entries in %d minutes\n|, $nentries, int($duration/MINUTE);
}
main;
__END__
