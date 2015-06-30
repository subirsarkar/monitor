#!/Usr/bin/env perl
package main;

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Term::ProgressBar;
use List::Util qw/min max/;

use BaseTools::ConfigReader;
use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::ActiveTransfers;
use dCacheTools::P2P;
use dCacheTools::Mover;

use constant KB2By => 1024;

# Command line options with Getopt::Long
our $verbose;
our $help = '';
our $webserver = undef;
our $parse_p2p = '';

$| = 1;

our $state_pmap = 
{
  A => 'active',
  W => 'waiting',
  S => 'stuck'
};
sub usage
{
  print <<HEAD;
Parses Active Transfers (webserver:2288/context/transfers.html) to find dcap and gridftp transfers. 
Additionally, finds the p2p transfers using the admin console and prepares a summary report for various 
types of transfer.

The command line options are

-v|--verbose    display debug information            (D=false)
-h|--help       show help on this tool and quit      (D=false)
-s|--webserver  web server for the dcache monitoring (D=config)
-p|--parse-p2p  parse p2p transfers as well          (D=false)

Example usage:
perl -w $0 --webserver=cmsdcache --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  Getopt::Long::Configure ('bundling');
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
          'p|parse-p2p' => \$parse_p2p,
        's|webserver=s' => \$webserver;

  unless (defined $webserver) {
    my $reader = BaseTools::ConfigReader->instance();
    $webserver = $reader->{config}{webserver};
  }
}
sub main
{
  readOptions;
  my $transfers = dCacheTools::ActiveTransfers->new({ webserver => $webserver });
  my $rows = $transfers->rows;
 
  my $pmap = {};
  my $dmap = {};
  for my $row (@$rows) {
    my $door_domain = $row->[1];
    my $protocol = (split /-/, $door_domain)[0];
    if ($protocol eq 'gridftp') {
      $protocol .= ($row->[9] =~ /sending/) ? '-up' : '-dn';
    }

    my ($status, $rate) = ($row->[11], $row->[-1]);
    next if ($rate eq '-' or $rate =~ /No Mover/);
    next unless ($status and $status eq 'A');

    my $pname = $row->[7];
    $pmap->{$protocol}{pool}{$pname}{rate} += $rate;
    $pmap->{$protocol}{pool}{$pname}{jobs}++;

    my $pool = dCacheTools::Pool->new({ name => $pname });
    if ($pool->online) {
      my $host = $pool->host;  
      $pmap->{$protocol}{host}{$host}{rate} += $rate;
      $pmap->{$protocol}{host}{$host}{jobs}++;
    }

    next unless $protocol =~ /gridftp/;
    my @fields = split /\./, $row->[8]; shift @fields;
    my $rdomain = join "\.", @fields;
    $dmap->{$protocol}{$rdomain}{rate} += $rate;
    $dmap->{$protocol}{$rdomain}{jobs}++;
  }

  my $reader = BaseTools::ConfigReader->instance();
  my $remotegsiftp = $reader->{config}{lookup_remotegsiftp} || 0;

  # now find the active transfers (p2p + optionally remotegsiftp) for all the pools
  if ($parse_p2p or $remotegsiftp) {
    # Prepare the command
    my $command = ''; 
    $command .= q|p2p ls| if $parse_p2p;
    $command .= qq|\n| if ($parse_p2p and $remotegsiftp);
    $command .= q|mover ls| if $remotegsiftp;

    my $mi = dCacheTools::Mover->new;

    my @poollist = dCacheTools::PoolManager->instance()->poollist;
    my $npools = scalar @poollist;
    my $ipool = 0;
    my $next_update = -1;
    my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                           count => $npools, 
                                          remove => 1, 
                                             ETA => 'linear' });
    $progress->minor(0);
    my $it = max 1, int($npools/100);
    for my $pname (@poollist) {
      unless ((++$ipool)%$it) {
        $next_update = $progress->update($ipool) if $ipool >= $next_update;
      }

      my $pool = dCacheTools::Pool->new({ name => $pname });
      $pool->online or next;
      print STDERR ">>> Processing Pool $pname\n" if $verbose; 

      # P2P (+ RemoteGsiftpTransferManager)
      my @output = $pool->exec({ command => $command });
      $pool->alive or next;

      my $host = $pool->host;  
      for (@output) {
        next if /DCap-/ or /GFTP-/;
        if (/RemoteGsiftpTransfer/) {
          $mi->moverls($_);
          my $rate = $mi->rate;
          $pmap->{remotegsiftp}{pool}{$pname}{rate} += $rate;
          $pmap->{remotegsiftp}{pool}{$pname}{jobs}++;

          $pmap->{remotegsiftp}{host}{$host}{rate} += $rate;
          $pmap->{remotegsiftp}{host}{$host}{jobs}++;
        }
        else {
          my $p2p = dCacheTools::P2P->new({ input => $_ });
          my $rate = $p2p->rate;
          my $cpname = $p2p->clientpool || '?';
          $pmap->{p2p}{pool}{$pname}{rate} += $rate;
          $pmap->{p2p}{pool}{$pname}{jobs}++;

          $pmap->{p2p}{host}{$host}{rate} += $rate;
          $pmap->{p2p}{host}{$host}{jobs}++;

          my $state = 'A';
          if ($p2p->waiting) {
            $state = 'W';
          }
          elsif ($p2p->stuck) {
            $state = 'S';
          }
          push @{$pmap->{p2p}{pool}{$pname}{clientpool}}, qq|$cpname($state)|;
          $pmap->{p2p}{pool}{$pname}{$state_pmap->{$state}}++;
        }
      }
    }
    $progress->update($ipool) if $ipool > $next_update;
  }

  # Summary for sitewise up/dn gridftp transfers 
  for my $protocol (sort keys %$dmap) {
    print qq|-----------------------\n$protocol Rate(KB/s)\n-----------------------\n|;
    printf qq|%26s %s %8s %7s\n|, q|Domain|, q|Jobs|, q|Rate|, q|AvgRate|;
    # Cumulative numbers for each protocol
    my $domains = $dmap->{$protocol};    
    for my $d (sort keys %$domains) {
      my $jobs = $dmap->{$protocol}{$d}{jobs};
      my $rate = $dmap->{$protocol}{$d}{rate};
      my $avgrate = ($jobs>0) ? $rate*1.0/$jobs : -1; 
      printf qq|%26s %4d %8.1f %7.1f\n|, $d, $jobs, $rate, $avgrate;
    }
  }

  # Now the detail
  my $dict = {};
  for my $protocol (sort keys %$pmap) {
    print qq|-----------------------\n$protocol Rate(KB/s)\n-----------------------\n|;
    my $href = $pmap->{$protocol};
    for my $type (sort keys %$href) {
      printf qq|%14s %s %8s %7s|, ucfirst $type, q|Jobs|, q|Rate|, q|AvgRate|;
      printf qq| %12s|, q/State(A|W|S)/ if ($protocol eq 'p2p' and $type eq 'pool');
      print "\n";
      # Cumulative numbers for each protocol
      my ($tjobs, $trate) = (0, 0.0);
      my $list = $pmap->{$protocol}{$type};    
      for my $l (sort keys %$list) {
        my $jobs = $pmap->{$protocol}{$type}{$l}{jobs};
        my $rate = $pmap->{$protocol}{$type}{$l}{rate};
        my $avgrate = ($jobs>0) ? $rate*1.0/$jobs : -1; 
        printf qq|%14s %4d %8.1f %7.1f|, $l, $jobs, $rate, $avgrate;
        if ($protocol eq 'p2p' and $type eq 'pool') {
          my $res = sprintf qq/%d|%d|%d/, 
                      ($pmap->{$protocol}{$type}{$l}{$state_pmap->{A}} || 0),
                      ($pmap->{$protocol}{$type}{$l}{$state_pmap->{W}} || 0),
                      ($pmap->{$protocol}{$type}{$l}{$state_pmap->{S}} || 0);
          my $aref = $pmap->{$protocol}{$type}{$l}{clientpool};
          printf qq| %8s %s|, $res, join(' ', q|Clients:|, @$aref);
        }
        print "\n";
        $tjobs += $jobs;
        $trate += $rate;

        $dict->{$type}{$l}{jobs} += $jobs;
        $dict->{$type}{$l}{rate} += $rate;
      }
      printf qq|%14s %4d %8.1f %7.1f\n\n|, 
        q|Aggregate|, $tjobs, $trate, ($tjobs>0) ? $trate*1.0/$tjobs : -1;
    }
  }
  my $cRate = 0.0;
  for my $type (sort keys %$dict) {
    print qq|--------------------------------------\n|;
    print q|Aggregate for all protocols for |. ucfirst $type. qq|s\n|;
    print qq|--------------------------------------\n|;
    printf qq|%14s %s %8s %7s\n|, ucfirst $type, q|Jobs|, q|Rate|, q|AvgRate|;
    for my $l (sort keys %{$dict->{$type}}) {
      my $tjobs = $dict->{$type}{$l}{jobs};
      my $trate = $dict->{$type}{$l}{rate};
      my $avgrate = ($tjobs>0) ? $trate*1.0/$tjobs : -1;
      printf qq|%14s %4d %8.1f %7.1f\n|, $l, $tjobs, $trate, $avgrate;
      $cRate += $trate if $type eq 'pool';
    }
  }
  printf qq|\nCumulative Rate: %8.1f KB/s\n|, $cRate;
}

main;
__END__
