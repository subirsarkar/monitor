#!/usr/env/bin perl;
package main;

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

use BaseTools::Util qw/fisher_yates_shuffle/;

use dCacheTools::PoolGroup;
use dCacheTools::Pool;
use dCacheTools::Companion;

# Command line options with Getopt::Long
our $verbose;
our $help = '';
our $srcpool;
our @dstpools;
our @blnodes; # blacklisted nodes
our @blpools; # blacklisted pools
our @wlnodes; # whitelisted nodes
our $pgroup = q|cms|;
our $skip_multiple;
our $rfrac = 1.0; # i.e vacate

use constant KB2By => 1024;
use constant MIN_FREE_SPACE => 50 * (KB2By**3); # GB

sub usage
{
  print <<HEAD;
Prepare a replication list

The command line options are

-v|--verbose        Display debug information       (D=false)
-h|--help           Show help on this tool and quit (D=false)
-s|--spool          Source pool                     (D=undefined)
-d|--dpool          Destination pools, overrides all (D=undefined)
--blnode            Destination nodes to be skipped  (D=undefined)
--blpool            Destination pools to be skipped  (D=undefined)
--wlnode            Destination nodes to be selected (D=undefined)
-g|--pgroup         Pool group                      (D=cms)
-f|--fraction       Replicate fraction of files from a source pool (D=1.0 i.e all)
-s|--skip_multiple  Skip further replication if > 1 replicas do already exist (D=false)

Example usage:
perl -w $0 --spool=cmsdcache2_1 --pgroup=cms --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  Getopt::Long::Configure ('bundling');
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
              'spool=s' => \$srcpool,
              'dpool=s' => \@dstpools,
             'blnode=s' => \@blnodes,
             'blpool=s' => \@blpools,
             'wlnode=s' => \@wlnodes,
        'skip_multiple' => \$skip_multiple,
           'fraction=f' => \$rfrac,
           'g|pgroup=s' => \$pgroup;

  die q|You must specify the source pool(s)| unless defined $srcpool;

  @dstpools = split /,/, join (',', @dstpools);
  @blnodes  = split /,/, join (',', @blnodes);
  @blpools  = split /,/, join (',', @blpools);
  @wlnodes  = split /,/, join (',', @wlnodes);
}

sub main
{
  readOptions;
  
  my $dbc = dCacheTools::Companion->new;

  my $spool = dCacheTools::Pool->new({ name => $srcpool });
  $spool->online or die qq|$spool is not a valid pool|;
  my $shost = $spool->host;

  my @poollist = ();
  if (scalar @dstpools) {
    push @poollist, @dstpools;
  }
  else {
    my $pg = dCacheTools::PoolGroup->new({ name => $pgroup });
    for my $poolname (grep { $_ ne $srcpool } $pg->poollist) {
      # get a pool instance
      my $dpool = dCacheTools::Pool->new({ name => $poolname });
      $dpool->online or next;

      # no p2p to the same host
      my $host = $dpool->host;
      ($host eq $shost) and next;

      # a destination node might be whitelisted
      next if (scalar @wlnodes and grep { $_ ne $host } @wlnodes);

      # avoid blacklisted pools as destination
      next if (scalar @blpools and grep { $_ eq $poolname } @blpools);

      # a destination node might also be blacklisted
      next if (scalar @blnodes and grep { $_ eq $host } @blnodes);

      # Check if the destination pool has enough space
      my $space_info = $dpool->space_info;
      $space_info->{free} > MIN_FREE_SPACE or next;

      push @poollist, $poolname;
    }
  }
  my $npools = scalar @poollist;

  my @f_list = ();
  my @output = $spool->exec({ command => q|rep ls -l| });
  my $ri = dCacheTools::Replica->new;
  my $ro = dCacheTools::Replica->new;
  for my $t (@output) {
    $ri->repls($t);
    my ($pnfsid, $status, $vo) = ($ri->pnfsid, $ri->status, $ri->vo);
    # replicate only precious ones, if we drain a pool, 
    # we simply throw away the cached ones
    ($vo eq $pgroup and $ri->precious) or next; 

    # now check how many copies we already have
    # we should use the cached information
    my @repList = grep { $_ ne $srcpool } $dbc->pools({ pnfsid => $pnfsid });
    if (defined $skip_multiple and scalar @repList) {
      my $skip_replication = 0;
      for (@repList) {
        my $dpool = dCacheTools::Pool->new({ name => $_ });
        $dpool->online or next;
        my @list = $spool->exec({ command => qq|rep ls -l $pnfsid| });
        $ro->repls($list[0]);
	if ($ro->precious) {
          $skip_replication = 1;
          last;
        }
      }
      $skip_replication and next;
    }

    my $index = int(rand($npools));
    my $selected_pool = $poollist[$index];
    while (grep { $_ eq $selected_pool } @repList) {
      $index = int(rand($npools));
      $selected_pool = $poollist[$index];
    }
    push @f_list, sprintf qq|%24s %14s %14s|, $pnfsid, $srcpool, $selected_pool;
  }
  fisher_yates_shuffle( \@f_list );    # permutes @array in place
  print join("\n", @f_list), "\n";
}
main;
__END__
