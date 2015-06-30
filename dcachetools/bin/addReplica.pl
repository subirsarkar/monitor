#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Time::HiRes qw/usleep/;
use List::Util qw/shuffle min max/;

use BaseTools::ConfigReader;
use BaseTools::Util qw/fisher_yates_shuffle/;
use dCacheTools::Filemap;
use dCacheTools::Replica;
use dCacheTools::PoolGroup;
use dCacheTools::ReplicationHandler;

# Command line options with Getopt::Long
our $verbose     = '';
our $help        = '';
our $pnfsroot    = undef;
our $min_replica = undef;
our $pgroup      = q|cms|;
our $dryrun = undef;
our $max_files = 100;
our $max_replica_per_host = 1;
our $recursive  = '';

use constant KB2By => 1024;
use constant MIN_FREE_SPACE => 20 * (KB2By**3); # GB
sub usage
{
  print <<HEAD;
Replicate files found recursively under a path. Continue until
min-replica is ensured

The command line options are

-v|--verbose              display debug information (D=false)
-h|--help                 show help on this tool and quit (D=false)
-p|--pnfsroot             pnfs namespace to prepend to filename (D: value of config)
-R|--recursive            traverse the path recursively (D=false)
-g|--pgroup               pool group (D=cms)
-d|--dryrun               simulate (D=false)
-m|--min-replica          minimum number of replica that should be available for each entry(D=undef)
-x|--max-replica-per-host maximum number of replica on each pool node (D=1)
-f|--max-files            maximum number of replication per invokation(D=100)

Example usage:
perl -w $0 /cms/store/PhEDEx_LoadTest07
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions        'verbose!' => \$verbose,
                       'help!' => \&usage,
                  'pnfsroot=s' => \$pnfsroot,
                 'R|recursive!'=> \$recursive,
                  'g|pgroup=s' => \$pgroup,
                      'dryrun' => \$dryrun,
    'x|max-replica-per-host=i' => \$max_replica_per_host,
                 'max-files=i' => \$max_files,
             'm|min-replica=i' => \$min_replica;

  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }
}

sub main
{
  readOptions;

  # pathname
  my $path = shift @ARGV;
  defined $path or die q|Dataset path underfined!|;

  $path = $pnfsroot . $path unless $path =~ m#^/pnfs#;
  -r $path or die qq|$path is not a valid path!|;

  my $host2pool = {};
  my $pg = dCacheTools::PoolGroup->new({ name => $pgroup });
  my @pools = $pg->poollist;
  for my $poolname (@pools) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    $pool->online or next;
    my $space_info = $pool->space_info;
    my $free_space = $space_info->{free};
    next unless $free_space > MIN_FREE_SPACE;

    my $host = $pool->host;
    ++$host2pool->{$host}{$poolname};
  }
  my $fileinfo = dCacheTools::Filemap->new({
        source => q|path|,
          path => $path, 
      pnfsroot => $pnfsroot,
     recursive => $recursive
  })->fileinfo;

  # single instance of dCacheTools::Replica may suffice
  my @list = ();
  my $ri = dCacheTools::Replica->new;
  while (my ($file, $pinfo) = each %$fileinfo) {
    my @poolList = @{$pinfo->{pools}};
    my %pmap = map { $_ => 1 } @poolList;
    my $n_replica = scalar @poolList;
    next if (defined $min_replica and $n_replica >= $min_replica);
    my $pnfsid = $pinfo->{pnfsid};
    my $hosts = {};
    for my $poolname (@poolList) {
      my $pool = dCacheTools::Pool->new({ name => $poolname });
      $pool->online or next;
      ++$hosts->{$pool->host};
    }
    print join(' ', $pnfsid, scalar keys(%$hosts)), "\n" if $verbose;
    while (my ($h, $hinfo)=  each %$host2pool) {
      next if (exists $hosts->{$h} and $hosts->{$h} >= $max_replica_per_host);
      ++$hosts->{$h};

      my @alist = shuffle @poolList;      
      my @blist = ();
      while (my ($p) = each %$hinfo) {
        push @blist, $p unless exists $pmap{$p};
      }
      fisher_yates_shuffle( \@blist );
      next unless (scalar @alist and scalar @blist);
      print join(' ', $pnfsid, $alist[0], $blist[0]), "\n" if $verbose;
      push @list, {
                     pnfsid => $pnfsid,
                      spool => $alist[0],
                      dpool => $blist[0]
                  };
      last if (defined $min_replica and ++$n_replica >= $min_replica);
    }
  }
  my $nitems = scalar @list;
  die q|>>> No files to replicate, stopped| unless $nitems;
  fisher_yates_shuffle( \@list );  # permutes @array in place
  my $nel = min $nitems, $max_files;
  @list = @list[0..($nel-1)];
  print qq|>>> Replicate $nel files\n|;
  print Data::Dumper->Dump([\@list], [qw/list/]) if $verbose;
  for my $l (@list) {
    print join(' ', $l->{pnfsid}, $l->{spool}, $l->{dpool}), "\n";
  }
  defined $dryrun and return;
  my $handler = dCacheTools::ReplicationHandler->new({ 
            max_threads => min(30, $nel), 
             src_cached => 0, 
           dst_precious => 0, 
     cached_src_allowed => 1,
      same_host_allowed => 1,
     ignore_space_limit => 0
  });
  $handler->add($_) for (@list);
  $handler->run;
}

# subroutine definition done
main;
__END__
