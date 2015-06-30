#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use List::Util qw/shuffle min max/;

use BaseTools::Util qw/trim 
                       filereadFH 
                       fisher_yates_shuffle/;
use dCacheTools::ReplicationHandler;
use dCacheTools::Companion;
use dCacheTools::Pool;
use dCacheTools::PoolGroup;
use dCacheTools::ActiveTransfers;

our $verbose = '';
our $help    = '';
our $webserver = undef;
our $pgroup  = q|cms|;
our $max_active_cutoff = 10;
our $max_queued_cutoff = 5;
our $dryrun = undef;
our $protocol = q|dcap|;

sub usage
{
  print <<HEAD;
Hot file replication tool

The command line options are

-v|--verbose     display debug information (D=false)
-h|--help        show help on this tool and quit (D=false)
-s|--webserver   dcache web server               (D=config)
-g|--pgroup      pool group (D=cms)
-a|--max-active  max active dcap transfers allowed for each pnfsid before a p2p is triggered
-q|--max-queued  max queued dcap transfers allowed for each pnfsid before a p2p is triggered
-p|--protocol    File access protocol, dcap/xrootd (D=dcap)

Example usage: perl -w $0
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
        's|webserver=s' => \$webserver,
       'a|max-active=i' => \$max_active_cutoff,
       'q|max-queued=i' => \$max_queued_cutoff,
           'protocol=s' => \$protocol,
               'dryrun' => \$dryrun,
           'g|pgroup=s' => \$pgroup;

  my $reader = BaseTools::ConfigReader->instance();
  defined $webserver or $webserver = $reader->{config}{webserver};
  $max_active_cutoff > 0 or $max_active_cutoff = 10;
  $max_queued_cutoff > 0 or $max_queued_cutoff = 5;
}

sub main
{
  readOptions;

  my $info = {};
  my $transfers = dCacheTools::ActiveTransfers->new({ webserver => $webserver });
  my $rows = $transfers->rows;
  for my $row (@$rows) {
    my $status = $row->[-1];
    next if $status =~ /No Mover found/;

    my $pnfsid = $row->[6];
    next unless $pnfsid =~ /[0-9A-F]{24,}/;

    my $door_domain = $row->[1];
    my $protocol = (split /-/, $door_domain)[0]; # redundant
    next unless $door_domain =~ /$protocol-(?:\w+)Domain/;
    my $pool  = $row->[7];
    my $state = $row->[11];
    $info->{$pnfsid}{$pool}{$state}++;
  }
  print Data::Dumper->Dump([$info], [qw/info/]) if $verbose;

  # Companion DB
  my $dbc = dCacheTools::Companion->new;
  
  # build {host => pools} mapping for pgroup cms
  my $hostmap = {};
  my $pg = dCacheTools::PoolGroup->new({ name => $pgroup });
  my @pools = $pg->poollist;
  for my $poolname (@pools) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    my $host = $pool->host;
    push @{$hostmap->{$host}}, $poolname;
  }

  my @list = ();
  while (my ($pnfsid, $pinfo) = each %$info) {
    my @hosts = ();
    my @poolList = $dbc->pools({ pnfsid => $pnfsid });
    for my $poolname (@poolList) {
      my $pool = dCacheTools::Pool->new({ name => $poolname });
      $pool->online or next;
      push @hosts, $pool->host;
    }
    while ( my ($pool, $states) = each %$pinfo) {
      my $na = $states->{A} || 0;
      my $nw = $states->{W} || 0;
      next if ($na < $max_active_cutoff and $nw < $max_queued_cutoff);
      for my $h (keys %$hostmap) {
        next if grep { $_ eq $h } @hosts;
        push @hosts, $h;
        my @alist = shuffle @poolList;      
        my @blist = shuffle @{$hostmap->{$h}};
        push @list, {
                      pnfsid => $pnfsid,
                       spool => $alist[0],
                       dpool => $blist[0]
                    };
      }
      last;
    }
  }
  my $nitems = scalar @list;
  die q|>>> no files to replicate, stopped| unless $nitems;
  print qq|>>> Replicate $nitems files\n|;
  @list = shuffle @list;      
  print Data::Dumper->Dump([\@list], [qw/list/]) if $verbose;
  for my $l (@list) {
    print join(' ', $l->{pnfsid}, $l->{spool}, $l->{dpool}), "\n";
  }
  defined $dryrun and return;
  my $handler = dCacheTools::ReplicationHandler->new({ 
            max_threads => min(30, $nitems), 
             src_cached => 0, 
           dst_precious => 0, 
     cached_src_allowed => 1,
      same_host_allowed => 0,
     ignore_space_limit => 1
  });
  $handler->add($_) for (@list);
  $handler->run;
}
main;
__END__
