#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use File::stat;

use BaseTools::ConfigReader;
use BaseTools::Util qw/restoreInfo/;
use dCacheTools::Filemap;
use dCacheTools::PoolGroup;
use dCacheTools::Pool;

# Command line options with Getopt::Long
our $verbose   = '';
our $help      = '';
our $recursive = '';
our $keep_precious_only = '';
our $pnfsroot  = undef;
our $use_cache = '';

use constant GB2BY => 1024**3;
our $cacheLife = 30 * 60; # seconds

sub usage
{
  print <<HEAD;
Find how files in a folder/dataset are distributed over pools. 

The command line options are

-v|--verbose        display debug information (D=false)
-h|--help           show help on this tool and quit (D=false)
-R|--recursive      traverse the path recursively (D=0)
-p|--pnfsroot       pnfs root folder (D: from config)
-o|--precious-only  consider only precious replica (D=false)
-c|--use-cache      use cached replica information(D=false)

Example usage:
perl -w $0 /store/PhEDEx_LoadTest07
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
           'pnfsroot=s' => \$pnfsroot,
         'R|recursive!' => \$recursive,
         'c|use-cache!' => \$use_cache,
     'o|precious-only!' => \$keep_precious_only;

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
  $path = $ENV{PWD} unless defined $path;

  my $fileinfo = dCacheTools::Filemap->new({
        source => q|path|,
          path => $path, 
      pnfsroot => $pnfsroot,
     recursive => $recursive,
      get_size => 1,
       verbose => $verbose
  })->fileinfo;
  my @fileList = sort keys %$fileinfo;

  # collect all the pnfsid from all the pools
  my $rColl = {};
  if ($keep_precious_only) {
    if ($use_cache) {
      my $reader = BaseTools::ConfigReader->instance();
      my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};
      my $dbfile = qq|$cacheDir/replica.db|;
      my $fstat = stat $dbfile or die qq|Failed to stat $dbfile|;
      # last modification time
      my $age = time() - $fstat->mtime;
      $rColl = restoreInfo($dbfile) if $age < $cacheLife;
    }
    unless (scalar %$rColl) {
      my $poolDict = {};
      for my $file (@fileList) {
        my $poolList = $fileinfo->{$file}{pools};
        ++$poolDict->{$_} for @$poolList;
      }
      my $ri = dCacheTools::Replica->new;
      my @list = keys %$poolDict;
      print STDERR q|>>> Number of pools holding the dataset: |. scalar @list . qq|.\n|;
      for my $poolname (@list) { 
        my $pool = dCacheTools::Pool->new({ name => $poolname });
        $pool->online or warn qq|$poolname not enabled/active!| and next;
        my @output = $pool->exec({ command => q|rep ls -l| });
        for (@output) {
          $ri->repls($_);
          $rColl->{$ri->pnfsid}{$poolname}{precious} = $ri->precious;
        }
      }
    }
  }

  my $totalfiles = scalar @fileList;
  my $info = {};
  my $totalspace = 0;
  for my $file (@fileList) {
    my $size = $fileinfo->{$file}{size};
    $totalspace += $size;
    my $poolList = $fileinfo->{$file}{pools};
    next unless scalar @$poolList;

    my $pnfsid = $fileinfo->{$file}{pnfsid};

    # For simplicity we assume only one replica to exist
    for my $poolname (@$poolList) {
      next if (exists $rColl->{$pnfsid}{$poolname}{precious} and 
                  not $rColl->{$pnfsid}{$poolname}{precious});

      my $pool = dCacheTools::Pool->new({ name => $poolname });
      $pool->online or next;

      my $host = $pool->host;
      ++$info->{host}{$host}{entries};
      $info->{host}{$host}{space} += $size;

      ++$info->{pool}{$poolname}{entries};
      $info->{pool}{$poolname}{space} += $size;
    }
  }
  $totalspace /= GB2BY;
  printf qq|Total Files = %d, Size = %8.2f (GB)\n|, $totalfiles, $totalspace;
  for my $tag (qw/host pool/) {
    print qq|=============\nFiles on $tag\n=============\n|;
    printf qq|%20s %6s %7s %9s %7s\n|, $tag, 'files', '[frac]', 'space(GB)', '[frac]';
    for my $key (sort keys %{$info->{$tag}}) {
      my $nfile = $info->{$tag}{$key}{entries};
      my $space = $info->{$tag}{$key}{space}*1.0/GB2BY;
      printf qq|%20s %6d %7.3f %9.2f %7.3f\n|, 
                                 $key, 
                                 $nfile, 
                                 $nfile*1.0/$totalfiles,
                                 $space, 
                                 $space/$totalspace;
    }
  }
}
# subroutine definition done
main;
__END__
