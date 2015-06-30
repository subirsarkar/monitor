#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use List::Util qw/min max/;
use JSON;

use BaseTools::Util qw/trim/;
use BaseTools::ConfigReader;
use BaseTools::RRDsys;

use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::Info::PoolGroup;
use dCacheTools::ActiveTransfers;
use dCacheTools::P2P;
use dCacheTools::Space;
use dCacheTools::Replica;

# auto-flush
$| = 1;

use constant KB2BY => 1024;
use constant MB2BY => 1.0*(KB2BY**2);
use constant GB2BY => 1.0*(KB2BY**3);
use constant TB2BY => 1.0*(KB2BY**4);

our $jsonfile = q|poollist.json|;

# Command line options with Getopt::Long
our $verbose;

sub usage
{
  print <<HEAD;
 - Parses Active Transfers (webserver:2288/context/transfers.html) 
   to find dcap and gridftp transfer rates 
 - prepares poolinfo
 - updates RRD 
 - prepares various charts

The command line options are

-v|--verbose    display debug information       (D=false)
-h|--help       show help on this tool and quit (D=false)

Example usage:
perl -w $0 --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  Getopt::Long::Configure ('bundling');
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage;
}

sub createVORRD
{
  my $rrdH = shift;
  $rrdH->create([
     'totalSpace',
     'freeSpace',
     'usedSpace',
     'preciousSpace',
     'nFiles',
     'nPreciousFiles'
  ]);
}
sub createRRD
{
  my ($rrdH, $addCost) = @_;
  $addCost = 0 unless defined $addCost;
  my @list = qw/
     totalSpace
     freeSpace
     usedSpace
     preciousSpace
     nFiles
     nPreciousFiles
     activeDCapMovers
     queuedDCapMovers
     maxDCapMovers
     activeGFtpMovers
     queuedGFtpMovers
     maxGFtpMovers
     activeP2PSMovers
     queuedP2PSMovers
     maxP2PSMovers
     activeP2PCMovers
     queuedP2PCMovers
     maxP2PCMovers/;
  $addCost and push @list, qw/spaceCost perfCost/;
  push @list, 
     qw/
     DCapConn
     DCapRate
     GFtpInConn
     GFtpInRate
     GFtpOutConn
     GFtpOutRate
     GFtpInLanConn
     GFtpInLanRate
     GFtpInWanConn
     GFtpInWanRate
     GFtpOutLanConn
     GFtpOutLanRate
     GFtpOutWanConn
     GFtpOutWanRate
     P2PConn
     P2PRate/;
  $rrdH->create(\@list);
}

sub getFloat
{
  my $val = shift;
  sprintf(qq|%.2f|, $val);
}

sub fillZero
{
  my ($rrdH) = shift;
  my $aref = [];
  push @$aref, time();
  push @$aref, 0 for (1..36);
  $rrdH->update($aref);
}

sub createJSON
{
  my $pools = shift;
  my $list = ['global', @$pools];

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $location = $config->{rrd}{location};

  my $json = JSON->new(pretty => 1, delimiter => 0);
  my $file = qq|$location/$jsonfile|;
  open OUTPUT, qq|>$file| or die qq|Failed to open output file $jsonfile|;
  print OUTPUT $json->encode({ 'items' => $list });
  close OUTPUT;
}

sub transferRate
{
  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $webserver = $config->{webserver};
  my $mydomain  = $config->{domain};

  my $transfers = dCacheTools::ActiveTransfers->new({ webserver => $webserver });
  my $rows = $transfers->rows;
 
  my $info = {};
  for my $row (@$rows) {
    my $door_domain = $row->[1];
    my $protocol = (split /-/, $door_domain)[0];
    if ($protocol eq 'gridftp') {
      $protocol .= ($row->[9] =~ /sending/) ? '_up' : '_dn';
    }

    my ($status, $rate) = ($row->[11], $row->[-1]);
    ($rate eq '-' or $rate =~ /No Mover/) and next;
    ($status and $status eq 'A') or next;

    my $poolname = $row->[7];
    $info->{$poolname}{$protocol}{rate} += $rate;
    ++$info->{$poolname}{$protocol}{jobs};

    $protocol =~ /gridftp/ or next;
    my @fields = split /\./, $row->[8]; shift @fields;
    my $rdomain = join "\.", @fields;
    $protocol .= ($rdomain eq $mydomain) ? '_lan' : '_wan';

    $info->{$poolname}{$protocol}{rate} += $rate;
    ++$info->{$poolname}{$protocol}{jobs};
  }
  print Data::Dumper->Dump([$info], [qw/info/]) if $config->{verbose};
  $info;
}

sub main
{
  readOptions;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->config;
  my $webserver  = $config->{webserver};
  my $location   = $config->{rrd}{location};
  my $moverTypes = $config->{mover_types};
  
  # create the RRD object
  my $rrdH = BaseTools::RRDsys->new;
 
  # get transfer rate from dcache transfer page
  my $info = transferRate();

  my $ginfo = {};
  my $voinfo = {};
  my $pm = dCacheTools::PoolManager->instance();
  my @poollist = $pm->poollist;

  # save the poollist as a JSON
  createJSON(\@poollist);

  my $ri = dCacheTools::Replica->new;
  for my $poolname (@poollist) {
    my $dbfile = $poolname.q|.rrd|;
    $rrdH->rrdFile($dbfile);
    -r qq|$location/$dbfile| 
      or warn qq|$dbfile not found! creating ...| 
        and createRRD($rrdH, 1); 

    my $pool = dCacheTools::Pool->new({ name => $poolname });
    unless ($pool->online) {
      warn qq|$poolname not enabled/active!| and sleep 1;
      eval {   
        fillZero($rrdH);
      };
      warn qq|>>> fillZero: RRD Update failed!| if $@;
      next;
    }
    print STDERR qq|>>> Processing $poolname ...\n| if $verbose;

    # total space usage
    my $space_info = $pool->space_info;
    $ginfo->{space}{total}    += $space_info->{total};
    $ginfo->{space}{free}     += $space_info->{free};
    $ginfo->{space}{precious} += $space_info->{precious};

    # total number of movers for each category
    my $mover_info = $pool->mover_info('client_movers');
    $moverTypes = [sort keys %$mover_info] unless defined $moverTypes;
    for my $m (@$moverTypes) { # lan and wan are usually put together in client_movers
      $ginfo->{movers}{$m}{active} += $mover_info->{$m}{active};
      $ginfo->{movers}{$m}{max}    += $mover_info->{$m}{max};
      $ginfo->{movers}{$m}{queued} += $mover_info->{$m}{queued};
    }
    # must treat p2p separately
    for my $m (qw/p2p_server p2p_client/) { # usually standard naming convention
      my $linfo = $pool->mover_info($m);
      $ginfo->{movers}{$m}{active} += $linfo->{active};
      $ginfo->{movers}{$m}{max}    += $linfo->{max};
      $ginfo->{movers}{$m}{queued} += $linfo->{queued};
    }

    # use rep ls to find number of files in a pool
    my @repls = $pool->exec({ command => q|rep ls| });
    unless ($pool->alive) {
      warn qq|Pool $poolname did not respond! skipped\n| and sleep 1;
      eval {   
        fillZero($rrdH);
      };
      warn qq|>>> fillZero: RRD Update failed!| if $@;
      next;
    }
    my $nFiles = scalar @repls;
    my $nPrecFiles = 0;
    for (@repls) {
      $ri->repls($_);
      my $vo = $ri->vo;
      ++$voinfo->{$vo}{nFiles};
      if ($ri->precious) {
	++$nPrecFiles;
        ++$voinfo->{$vo}{nPrecFiles};
      }
    }
    $ginfo->{nFiles}     += $nFiles;
    $ginfo->{nPrecFiles} += $nPrecFiles;

    # P2P
    my @output = $pool->exec({ command => q|p2p ls| });
    if ($pool->alive) {
      for (@output) {
        my $p2p  = dCacheTools::P2P->new({ input => $_ });
        my $rate = $p2p->rate;

        ++$info->{$poolname}{p2p}{jobs};
        $info->{$poolname}{p2p}{rate} += $rate;
      }
    }
    my $types = $info->{$poolname};
    for my $type (keys %$types) {
      $ginfo->{conn}{$type}{jobs} += $info->{$poolname}{$type}{jobs};
      $ginfo->{conn}{$type}{rate} += $info->{$poolname}{$type}{rate};
    }
    # update RRD for the individual pool quanties
    my $space_used = $space_info->{total} - $space_info->{free};
    my $data = 
    [
      time(),
      getFloat($space_info->{total}/MB2BY),
      getFloat($space_info->{free}/MB2BY),
      getFloat($space_used/MB2BY),
      getFloat($space_info->{precious}/MB2BY),
      $nFiles,
      $nPrecFiles,
      $mover_info->{$moverTypes->[0]}{active} || 0,
      $mover_info->{$moverTypes->[0]}{queued} || 0,
      $mover_info->{$moverTypes->[0]}{max} || 0,
      $mover_info->{$moverTypes->[1]}{active} || 0,
      $mover_info->{$moverTypes->[1]}{queued} || 0,
      $mover_info->{$moverTypes->[1]}{max} || 0,
      $pool->mover_info('p2p_server')->{active} || 0,  # must be this way
      $pool->mover_info('p2p_server')->{queued} || 0,
      $pool->mover_info('p2p_server')->{max} || 0,
      $pool->mover_info('p2p_client')->{active} || 0,
      $pool->mover_info('p2p_client')->{queued} || 0,
      $pool->mover_info('p2p_client')->{max} || 0,
      $pool->space_cost,
      $pool->perf_cost,
      $info->{$poolname}{dcap}{jobs} || 0,
      $info->{$poolname}{dcap}{rate} || 0,
      $info->{$poolname}{gridftp_dn}{jobs} || 0,
      $info->{$poolname}{gridftp_dn}{rate} || 0,
      $info->{$poolname}{gridftp_up}{jobs} || 0,
      $info->{$poolname}{gridftp_up}{rate} || 0,
      $info->{$poolname}{gridftp_dn_lan}{jobs} || 0,
      $info->{$poolname}{gridftp_dn_lan}{rate} || 0,
      $info->{$poolname}{gridftp_dn_wan}{jobs} || 0,
      $info->{$poolname}{gridftp_dn_wan}{rate} || 0,
      $info->{$poolname}{gridftp_up_lan}{jobs} || 0,
      $info->{$poolname}{gridftp_up_lan}{rate} || 0,
      $info->{$poolname}{gridftp_up_wan}{jobs} || 0,
      $info->{$poolname}{gridftp_up_wan}{rate} || 0,
      $info->{$poolname}{p2p}{jobs} || 0,
      $info->{$poolname}{p2p}{rate} || 0
    ];
    print join(":", @$data), "\n" if $verbose;
    eval {
      $rrdH->update($data);
    };
    warn q|>>> RRD Update failed!| if $@;
  }
  $ginfo->{space}{used} = $ginfo->{space}{total} - $ginfo->{space}{free};

  # now total space usage and movers in use
  my $dbfile = $config->{rrd}{db};
  $rrdH->rrdFile($dbfile);
  -r qq|$location/$dbfile| or createRRD($rrdH, 0);
  my $data = 
  [
    time(),
    getFloat($ginfo->{space}{total}/MB2BY),
    getFloat($ginfo->{space}{free}/MB2BY),
    getFloat($ginfo->{space}{used}/MB2BY),
    getFloat($ginfo->{space}{precious}/MB2BY),
    $ginfo->{nFiles},
    $ginfo->{nPrecFiles},
    $ginfo->{movers}{$moverTypes->[0]}{active} || 0,
    $ginfo->{movers}{$moverTypes->[0]}{queued} || 0,
    $ginfo->{movers}{$moverTypes->[0]}{max} || 0,
    $ginfo->{movers}{$moverTypes->[1]}{active} || 0,
    $ginfo->{movers}{$moverTypes->[1]}{queued} || 0,
    $ginfo->{movers}{$moverTypes->[1]}{max} || 0,
    $ginfo->{movers}{p2p_server}{active} || 0,
    $ginfo->{movers}{p2p_server}{queued} || 0,
    $ginfo->{movers}{p2p_server}{max} || 0,
    $ginfo->{movers}{p2p_client}{active} || 0,
    $ginfo->{movers}{p2p_client}{queued} || 0,
    $ginfo->{movers}{p2p_client}{max} || 0,
    $ginfo->{conn}{dcap}{jobs} || 0,
    $ginfo->{conn}{dcap}{rate} || 0,
    $ginfo->{conn}{gridftp_dn}{jobs} || 0,
    $ginfo->{conn}{gridftp_dn}{rate} || 0,
    $ginfo->{conn}{gridftp_up}{jobs} || 0,
    $ginfo->{conn}{gridftp_up}{rate} || 0,
    $ginfo->{conn}{gridftp_dn_lan}{jobs} || 0,
    $ginfo->{conn}{gridftp_dn_lan}{rate} || 0,
    $ginfo->{conn}{gridftp_dn_wan}{jobs} || 0,
    $ginfo->{conn}{gridftp_dn_wan}{rate} || 0,
    $ginfo->{conn}{gridftp_up_lan}{jobs} || 0,
    $ginfo->{conn}{gridftp_up_lan}{rate} || 0,
    $ginfo->{conn}{gridftp_up_wan}{jobs} || 0,
    $ginfo->{conn}{gridftp_up_wan}{rate} || 0,
    $ginfo->{conn}{p2p}{jobs} || 0,
    $ginfo->{conn}{p2p}{rate} || 0
  ];
  print join(":", @$data), "\n" if $verbose;
  eval {
    $rrdH->update($data);
  };
  warn q|>>> RRD Update failed!| if $@;

  # now VO space
  my @voList = @{$config->{rrd}{supportedVOs}};
  for my $vo (@voList) {
    my $info = {};
    if (exists $config->{has_info_service} and $config->{has_info_service}) {
      my $pg = dCacheTools::Info::PoolGroup->new({ webserver => $webserver, name => $vo });
      $info->{total} = $pg->total;
      $info->{free}  = $pg->free;
      $info->{prec}  = $pg->precious/MB2BY;
      $info->{used}  = ($info->{total} - $info->{free})/MB2BY;
      # for precision do not convert to MB earlier
      $info->{total} /= MB2BY;
      $info->{free}  /= MB2BY;
    }
    else {
      my $obj = dCacheTools::Space->new({ webserver => $webserver, pgroup => $vo });
      my $usage = $obj->getUsage;
      $info->{total} = $usage->{total}; # in MB
      $info->{free}  = $usage->{free};
      $info->{prec}  = $usage->{precious};
      $info->{used}  = $info->{total} - $info->{free};
    }
    # Update RRD for individual VO
    my $dbfile = $vo.q|.rrd|;
    $rrdH->rrdFile($dbfile);
    createVORRD($rrdH) unless -r qq|$location/$dbfile|;
    my $data = 
    [
      time(),
      getFloat($info->{total}),
      getFloat($info->{free}),
      getFloat($info->{used}),
      getFloat($info->{prec}),
      $voinfo->{$vo}{nFiles} || 0,
      $voinfo->{$vo}{nPrecFiles} || 0
    ];
    print join(':', @$data), "\n" if $verbose;
    eval {
      $rrdH->update($data);
    };
    warn q|>>> RRD Update failed!| if $@;
  }
}
main;
__END__
