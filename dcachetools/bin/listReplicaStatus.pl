#!/usr/bin/env perl
package main;

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Time::HiRes qw/usleep/;
use List::Util qw/shuffle/;

use BaseTools::Util qw/trim/;
use dCacheTools::PoolGroup;
use dCacheTools::Replica;
use dCacheTools::Pool;

$| = 1;

# Command line options with Getopt::Long
our $verbose = '';
our $infile  = undef;
our $fix_r   = undef;

sub usage
{
  print <<HEAD;
Find pnfsids with >1 precious replica and with no precious replica at all.
Optionally retains only 1 precious replica in the first case and make others
cached.

This tools should be be only after refreshing the cached filelist.

The command line options are

-v|--verbose  display debug information (D=false)
-h|--help     show help on this tool and quit (D=false)
-f|--file     pnfs entries in a file (no default)
-x|--fix      keep only one precious copy (skip LT files)

Example usage:
perl -w $0 --file=./pnfs_files_without_LoadTest_JobRobot_SAM.txt --verbose
HEAD

  exit 0;
}

sub readOptions
{
  # Extract command line options
  GetOptions 'verbose!' => \$verbose,
                'help!' => \&usage,
                'x|fix' => \$fix_r,
               'file=s' => \$infile;
  warn qq|Input file must be specified!\n\n| and usage unless defined $infile;
}

sub main
{
  readOptions;

  my $reader   = BaseTools::ConfigReader->instance();
  my $config   = $reader->config;
  my $cacheDir = $config->{cache_dir};

  my $pg = dCacheTools::PoolGroup->new({ name => q|cms| });
  my @poollist = $pg->poollist;
  my $filemap = {};
  for my $poolname (@poollist) {
    my $cacheFile = qq|$cacheDir/$poolname.filelist|;
    print qq|>>> Processing $cacheFile\n|;
    open INPUT, $cacheFile || die qq|Failed to open $cacheFile for reading!|;
    while (<INPUT>) {
      my ($pnfsid, $status, $size, $file, $pool) = (split /\s+/)[0,2,3,4,5];
      next unless ($file =~ /\.root$/ and $file =~ /store/);
      next if ($file =~ /unmerged/ or $file =~ /LoadTest07/);
      $file =~ s#^/cms##;  
      push @{$filemap->{$file}}, { 
                                     pnfsid => $pnfsid, 
                                   filesize => $size, 
                                     status => $status, 
                                       pool => $pool 
                                 };
    }
    close INPUT;
  }
  print Data::Dumper->Dump([$filemap], [qw/filemap/]) if $verbose;

  my $ri = dCacheTools::Replica->new;
  open FILE, $infile or die qq|Failed to open $infile for reading|;
  while (my $filename = <FILE>) {
    chop $filename;
    next unless ($filename =~ /\.root$/ and $filename =~ /store/);
    next if ($filename =~ /unmerged/ or $filename =~ /LoadTest07/);

    warn qq|$filename not found in CACHE!| and next unless defined $filemap->{$filename};
    my @rList = @{$filemap->{$filename}};
    next unless scalar @rList > 1;
    my $pnfsid = $rList[0]->{pnfsid};
    my $nprec = 0;
    my @pList = ();
    for my $info (@rList) {
      my $repls = sprintf qq|%s %s %d si={cms:alldata}|, 
        $pnfsid, $info->{status}, $info->{filesize};
      $ri->repls($repls);
      next unless $ri->precious;
      ++$nprec;
      push @pList, $info->{pool};  
    }
    if ($nprec == 0) {
      print qq|File with no precious Replica \n $filename =>\n|;
      for my $info (@rList) {
        printf qq|%32s %d %16s %s\n|, 
          $pnfsid, 
          $info->{filesize}, 
          $info->{pool}, 
          $info->{status};
      }
    }
    elsif ($nprec > 1) {
      print qq|File with > 1 precious Replica \n $filename =>\n|;
      for my $info (@rList) {
        printf qq|%32s %d %16s %s\n|, 
          $pnfsid, 
          $info->{filesize}, 
          $info->{pool}, 
          $info->{status};
      }
      if (defined $fix_r) {
        @pList = shuffle @pList;
        shift @pList; # keep just one precious copy
        for my $p (@pList) {
	  print qq|>>> Extra precious copy in pool $p will be made cached!\n|;
          my $pool = dCacheTools::Pool->new({ name => $p });
          $pool->online or warn qq|Pool $p unavailable!| and next;
          $pool->exec({ command => qq|rep set cached $pnfsid -force| });
          usleep 5000;
        }
      }
    }
  }
  close FILE;
}
main;
__END__
