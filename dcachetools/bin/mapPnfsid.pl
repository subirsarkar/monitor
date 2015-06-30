#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Data::Dumper;
use Math::BigInt;
use Getopt::Long;

use BaseTools::ConfigReader;
use BaseTools::MyStore;
use dCacheTools::PnfsManager;
use dCacheTools::ActiveTransfers;
use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::Mover;
use dCacheTools::Cell;

# Command line options with Getopt::Long
our $verbose = '';
our $help    = '';
our $webserver = undef;
our $pnfsroot  = undef;
our $skip_dcap = '';

sub usage
{
  print <<HEAD;
Find the ongoing transfers and map pnfsids to pfn/lfn.

The command line options are

-v|--verbose    display debug information       (D=false)
-h|--help       show help on this tool and quit (D=false)
-s|--webserver  dcache web server               (D=config)
-r|--pnfsroot   pnfs root directory             (D=config)
-d|--skip-dcap  skip dcap connections           (D=false)

Example usage:
perl -w $0 --webserver=cmsdcache --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
        's|webserver=s' => \$webserver,
         'r|pnfsroot=s' => \$pnfsroot,
         'd|skip-dcap!' => \$skip_dcap;

  my $reader = BaseTools::ConfigReader->instance();
  defined $pnfsroot or $pnfsroot = $reader->{config}{pnfsroot};
  defined $webserver or $webserver = $reader->{config}{webserver};
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

  my $transfers = dCacheTools::ActiveTransfers->new({ webserver => $webserver });
  my $rows = $transfers->rows;
 
  my $pnfsH = dCacheTools::PnfsManager->instance();

  my $reader = BaseTools::ConfigReader->instance();
  my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};
  my $dbfile = qq|$cacheDir/pnfsid2pfn.db|;
  my $store = BaseTools::MyStore->new({ dbfile => $dbfile });

  for my $row (sort { $a->[11] cmp $b->[11] } @$rows) {
    my $status = $row->[-1];
    next if $status =~ /No Mover found/;

    my $pnfsid = $row->[6];
    next unless $pnfsid =~ /[0-9A-F]{24,}/;

    my $door_domain = $row->[1];
    my $pool        = $row->[7];
    next if ($skip_dcap and $door_domain =~ /dcap-(?:\w+)Domain/);

    my $pfn = filename($pnfsid, $store, $pnfsH, $pnfsroot);
    my $protocol = (split /-/, $door_domain)[0];
    my $state = $row->[11];
    my $user = $row->[4];
    my $node = $row->[8];
    printf STDOUT "%s %8s %14s %12s %32s %s %s\n", 
     $state, $protocol, $pool, $user, $node, $pnfsid, $pfn;
  }
  my $remotegsiftp = $reader->{config}{lookup_remotegsiftp} || 0;
  if ($remotegsiftp) {
    my $mi = dCacheTools::Mover->new;
    # Now find the RemoteGsiftpTransfers
    # Create a RemoteGsiftpTransferManager
    my $gsiftp = dCacheTools::Cell->new({ name => q|RemoteGsiftpTransferManager| });
    my $pm = dCacheTools::PoolManager->instance({ parse_all => 0 }); # We do not need the detailed info
    for my $pname ($pm->poollist) {
      my $pool = dCacheTools::Pool->new({ name => $pname });
      $pool->online or next;

      my @moverls = grep { /RemoteGsiftpTransfer/ } $pool->exec({ command => q|mover ls| });
      for my $ls (@moverls) {
        $mi->moverls($ls);
        my $pfn = filename($mi->pnfsid, $store, $pnfsH, $pnfsroot);

        # find the remote gsiftp door
        my $remote_door = '?';
        my $seqid = $mi->seqid;
        my @result = $gsiftp->exec({ command => qq|ls "$seqid"| });
        if (scalar @result == 1) {
          my $data = (split m#src=gsiftp://#, $result[0])[-1];
          $remote_door = (split /:/, $data)[0];
        }
        printf STDOUT "%s %12s %24s %14s %32s %12s %6d %7.1f %s\n", 
              $mi->status1,
              "RemoteGsiftp",
              $mi->pnfsid, 
              $pname,
              $remote_door,
              (Math::BigInt->new($mi->bytes))->bstr, 
              $mi->duration,
              $mi->rate,
              $pfn;
      }
    }
  }
  $store->save;
}

main;
__END__
