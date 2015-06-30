#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Time::HiRes qw/usleep/;

use dCacheTools::Filemap;
use dCacheTools::Replica;

# Command line options with Getopt::Long
our $verbose   = '';
our $help      = '';
our $pnfsroot  = undef;
our $dryrun    = undef;
our $recursive = '';

sub usage
{
  print <<HEAD;
Make sure one pool node has only one replica for a file. 

The command line options are

-v|--verbose    display debug information (D=false)
-h|--help       show help on this tool and quit (D=false)
-p|--pnfsroot   pnfs namespace to prepend to filename (D=config)
-d|--dryrun     just show entries which need attention
-R|--recursive  traverse the path recursively (D=false)

Example usage:
perl -w $0 /pnfs/pi.infn.it/data/cms/store/PhEDEx_LoadTest07
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
           'pnfsroot=s' => \$pnfsroot,
          'R|recursive!'=> \$recursive,
               'dryrun' => \$dryrun;

  unless (defined $pnfsroot) {
    my $reader = BaseTools::ConfigReader->instance();
    $pnfsroot = $reader->{config}{pnfsroot};
  }
}

sub main
{
  readOptions;

  # Read the pathname
  my $path = shift @ARGV;
  die q|>>> ERROR. Dataset path undefined!| unless defined $path;

  $path = $pnfsroot . $path unless $path =~ m#^/pnfs#;
  -r $path or die qq|$path is not a valid path!|;

  my $fileinfo = dCacheTools::Filemap->new({
        source => q|path|,
          path => $path, 
      pnfsroot => $pnfsroot,
     recursive => $recursive
  })->fileinfo;
  my $ri = dCacheTools::Replica->new;
  for my $file (keys %$fileinfo) {
    my $pnfsid   = $fileinfo->{$file}{pnfsid};
    my @poolList = @{$fileinfo->{$file}{pools}};
    my $hostmap = {};
    for my $poolname (@poolList) {
      my $pool = dCacheTools::Pool->new({ name => $poolname });
      $pool->online or next;
      my $host = $pool->host;
      push @{$hostmap->{$host}}, $poolname;
    }
    print Data::Dumper->Dump([$hostmap], [qw/hostmap/]) if $verbose;
    for my $host (keys %$hostmap) {
      my @list = @{$hostmap->{$host}};  
      next if scalar @list < 2;
      print qq|>>> pnfsid=$pnfsid, > 1 replica on host=$host, pools=|. join(',', @list), qq|\n|;
      my $pool_rleft = shift @list;
      my $nprec = 0;
      for my $p (@list) {
        my $pool = dCacheTools::Pool->new({ name => $p });
        $pool->online or next;

        # is the file being accessed now? am I removing a precious replica?
        my @result = $pool->exec({ command => qq|rep ls -l $pnfsid| });
        $pool->alive or warn qq|Pool $p did not respond! skipped\n| and next;
        $ri->repls($result[0]);
        warn qq|file $file is in use, skipped| and next if $ri->client_count;
        $ri->precious and ++$nprec;

        # time to remove the redundant replica
        print qq|>>> Removing replica $p\n|;
        my @output = $pool->exec({ command => qq|rep rm $pnfsid -force| }) unless $dryrun;
        usleep 5000;
      }

      # if a precious copy was removed, make the remaining one precious
      $nprec or next;
      my $pool = dCacheTools::Pool->new({ name => $pool_rleft });
      $pool->online or next;

      # no action needed if precious already
      my @result = $pool->exec({ command => qq|rep ls -l $pnfsid| });
      $pool->alive or warn qq|Pool $pool_rleft did not respond! skipped\n| and next;
      $ri->repls($result[0]);
      $ri->precious and next;

      # act
      $dryrun and next;
      $pool->exec({ command => qq|rep set precious $pnfsid -force| });
      usleep 5000;
    }
  }
}

# subroutine definition done
main;
__END__
