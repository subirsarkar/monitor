#!/usr/env/bin perl;
package main;

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

use dCacheTools::PoolGroup;
use dCacheTools::Pool;
use dCacheTools::CompanionDB;

# Command line options with Getopt::Long
our $verbose;
our $help = '';
our $srcpool;
our $pgroup = q|cms|;
our $skip_multiple;

use constant KB2By => 1024;
use constant MIN_FREE_SPACE => 50 * (KB2By**3); # GB

sub usage
{
  print <<HEAD;
Prepare a replication list

The command line options are

-v|--verbose        Display debug information       (D=false)
-h|--help           Show help on this tool and quit (D=false)
-p|--pool           Source pool                     (D=undefined)
-g|--pgroup         Pool group                      (D=cms)
-s|--skip_multiple  Skip further replication if > 1 replicas do already exist (D=false)

Example usage:
perl -w $0 --pool=cmsdcache2_1 --pgroup=cms --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  Getopt::Long::Configure ('bundling');
  GetOptions 'verbose+' => \$verbose,
                 'help' => \&usage,
               'pool=s' => \$srcpool,
        'skip_multiple' => \$skip_multiple,
           'g|pgroup=s' => \$pgroup;

  die qq|You must specify the source pool| unless defined $srcpool;
}

sub main
{
  readOptions;
  
  my $dbc = new dCacheTools::CompanionDB;

  my $spool = new dCacheTools::Pool({ name => $srcpool });
  ($spool->enabled && $spool->active) or die qq|$spool is not a valid pool|;
  my $shost = $spool->host;

  my @poollist = ();
  my $pg =  new dCacheTools::PoolGroup({ name => $pgroup });
  for my $poolname (grep { $_ ne $srcpool } $pg->poollist) {
    my $dpool = new dCacheTools::Pool({ name => $poolname });
    ($dpool->enabled && $dpool->active) or next;
    my $host = $dpool->host;
    ($host eq $shost) and next;

    # Check if the destination pool has enough space
    my $space_info = $dpool->space_info;
    $space_info->{free} > MIN_FREE_SPACE or next;

    push @poollist, $poolname;
  }
  my $npools = scalar @poollist;

  my @output = $spool->exec({ command => qq|rep ls -l| });
  for my $t (@output) {
    my $ri = new dCacheTools::Replica($t);
    my ($pnfsid, $status, $vo) = ($ri->pnfsid, $ri->status, $ri->vo);
    ($vo eq $pgroup and $ri->precious) or next;

    my @repList = grep { $_ ne $srcpool } $dbc->pools({ pnfsid => $pnfsid });
    if (defined $skip_multiple and scalar @repList) {
      my $skip_replication = 0;
      for (@repList) {
        my $dpool = new dCacheTools::Pool({ name => $_ });
        ($dpool->enabled && $dpool->active) or next;
        my @list = $spool->exec({ command => qq|rep ls -l $pnfsid| });
        my $ro = new dCacheTools::Replica($list[0]);
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
    printf "%24s %14s %14s\n", $pnfsid, $srcpool, $selected_pool;
  }
}
main;
__END__
