#!/usr/env/bin perl
package main;

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

use BaseTools::ConfigReader;
use BaseTools::Util qw/trim fisher_yates_shuffle/;
use dCacheTools::Filemap;
use dCacheTools::PoolGroup;
use dCacheTools::Pool;

# Command line options with Getopt::Long
our $verbose;
our $help = '';
our @srcpools;
our @dstpools;
our @srcnodes; # in case all the pools of a nodes act as source
our @dstnodes; # whitelisted nodes
our @blnodes;  # blacklisted nodes
our @blpools;  # blacklisted pools
our $pgroup = q|cms|;
our $recursive = '';
our $pnfsroot  = undef;
our $rfrac = 0.9;
our $max_pools = 1;

use constant KB2By => 1024;
use constant MIN_FREE_SPACE => 50 * (KB2By**3); # GB

sub usage
{
  print <<HEAD;
Prepare a replication list for a dataset

The command line options are

-v|--verbose     Display debug information        (D=false)
-h|--help        Show help on this tool and quit  (D=false)
-s|--spool       Source pool                      (D=undefined)
-d|--dpool       Destination pools, overrides all (D=undefined)
-g|--pgroup      Pool group                       (D=cms)
--snode          Source nodes to be selected      (D=undefined)
--dnode          Destination nodes to be selected (D=undefined)
--blnode         Destination nodes to be skipped  (D=undefined)
--blpool         Destination pools to be skipped  (D=undefined)
-R|--recursive   traverse the path recursively    (D=0)
-p|--pnfsroot    pnfs root folder                 (D=config)
-f|--fraction    Replicate fraction of files from a source pool, common to all pools (D=0.9)
-m|--max_pools   skip further replication if _max_pools copy already present (D=1)

Example usage:
perl -w $0 --spool=cmsdcache1_1,cmsdcache1_4 --pgroup=cms --blnode=cmsdcache8 --recursive DATASET_PATH
HEAD

  exit 0;
}
sub readOptions
{
  # Extract command line options
  #Getopt::Long::Configure ('bundling');
  GetOptions 'verbose+' => \$verbose,
               'h|help' => \&usage,
           'pnfsroot=s' => \$pnfsroot,
         'R|recursive!' => \$recursive,
           'fraction=f' => \$rfrac,
        'm|max_pools=i' => \$max_pools,
              'spool=s' => \@srcpools,
              'dpool=s' => \@dstpools,
              'snode=s' => \@srcnodes,
              'dnode=s' => \@dstnodes,
             'blnode=s' => \@blnodes,
             'blpool=s' => \@blpools,
           'g|pgroup=s' => \$pgroup;

  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }
  @srcpools = split /,/, join (',', @srcpools);
  @srcnodes = split /,/, join (',', @srcnodes);
  die q|Source pool(s) not specified, died at| 
    unless (scalar @srcpools or scalar @srcnodes);

  @dstpools = split /,/, join (',', @dstpools);
  @dstnodes = split /,/, join (',', @dstnodes);
  @blnodes  = split /,/, join (',', @blnodes);
  @blpools  = split /,/, join (',', @blpools);
}
sub main
{
  readOptions;

  # Read the pathname
  my $path = shift @ARGV;
  defined $path or die q|Please specify a valid pnfs path! stopped|;
  
  my $pg = dCacheTools::PoolGroup->new({ name => $pgroup });
  my @poollist_pgroup = $pg->poollist;

  # prepare a list of valid destination pools
  my @poollist = ();
  if (scalar @dstpools) {
    for my $p (@dstpools) {
      push @poollist, $p if grep { $_ eq $p } @poollist_pgroup;
    }
  }
  else {
    for my $poolname (@poollist_pgroup) {
      # must not match a source pool
      next if (scalar @srcpools and grep { $_ eq $poolname } @srcpools);

      my $pool = dCacheTools::Pool->new({ name => $poolname });
      $pool->online or next;
      my $host = $pool->host;
      next if (scalar @srcnodes and grep { $_ eq $host } @srcnodes);

      # a destination node might be whitelisted
      next if (scalar @dstnodes and not grep { $_ eq $host } @dstnodes);

      # avoid using a blacklisted destination pool
      next if (scalar @blpools and grep { $_ eq $poolname } @blpools);

      # a destination node might also be blacklisted
      next if (scalar @blnodes and grep { $_ eq $host } @blnodes);

      # Check if the destination pool has enough space
      my $space_info = $pool->space_info;
      my $free_space = $space_info->{free};
      $free_space > MIN_FREE_SPACE 
        or warn qq|Free space on $poolname: |
        . sprintf(qq|%5.2f|, ($free_space/(KB2By**3)))
        . q| GB not enough!| and next;

      push @poollist, $poolname;
    }
  }
  my $npools = scalar @poollist;
  warn q|Destination Poollist empty!| and return unless $npools;

  # Now find the filelist
  my $fileinfo = dCacheTools::Filemap->new({
       source => q|path|,
         path => $path, 
     pnfsroot => $pnfsroot,
    recursive => $recursive,
     get_size => 1,
      verbose => $verbose
  })->fileinfo;
  my @fileList = ();
  my $info = {};
  while ( my ($file) = each %$fileinfo ) {
    my $poolList = $fileinfo->{$file}{pools};
    my $npools = scalar @$poolList;
    unless ($npools <= $max_pools) {
      $verbose and warn qq|$file is available on $npools pools, skipped|;
      next;
    }

    my $poolname = $poolList->[0];
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;

    my $host = $pool->host;
    my $idec = 0;
    ++$idec if (scalar @srcpools and grep { $_ eq $poolname } @srcpools);
    ++$idec if (scalar @srcnodes and grep { $_ eq $host } @srcnodes);

    $idec and push @{$info->{$poolname}}, $fileinfo->{$file}{pnfsid};
  }
  my @result = ();
  for my $pool (keys %$info) {
    my @list = @{$info->{$pool}};
    my $nl = int($rfrac * scalar(@list)) - 1;
    for my $pnfsid (@list[0..$nl]) {
      my $index = int(rand($npools));
      next unless $index > -1;
      my $dpool = $poollist[$index];
      push @result, sprintf qq|%24s %14s %14s|, $pnfsid, $pool, $dpool;
    }
  }
  fisher_yates_shuffle( \@result );    # permutes @array in place
  print join("\n", @result), "\n";
}
main;
__END__

