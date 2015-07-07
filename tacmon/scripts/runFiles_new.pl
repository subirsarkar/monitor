#!/usr/bin/env perl

package main;

use strict;
use warnings;

use File::Basename;
use File::Glob ':glob';
use File::stat;
use IO::File;

use lib qw(/home/cmstac/scripts);
use Util qw( _trim );

sub runClosed($$);
sub getFileInfo($);
sub getLatestFile($);
sub getFiles($); 
sub checkLocalFiles($$);
sub readDir($$$);

$ENV{'STAGE_HOST'}         = 'castorcms';
$ENV{'RFIO_USE_CASTOR_V2'} = 'YES';

use constant DEBUG => 1;
use constant TLIMIT => 4 * 60 * 60; # Seconds
use constant EDMTAG => "EDM";

my $vol = shift || die qq(Usage: $0 data_area [det]\n Example: $0 /data3 [TIB]);
my $det = shift || "TIB";

my $baseDir   = qq($vol/EDMProcessed/$det);
my $inputFile = qq($baseDir/fileProcessed.txt);
my $mapFile   = qq($baseDir/fileMap.txt);
my $infoFile  = qq($baseDir/fileInfo.txt);

my $outputDir = qq($baseDir/dbs);
my $lfnDir    = qq(/store/TAC/$det);
my $CASTORDIR = qq(/castor/cern.ch/cms);

sub main 
{
  my $list = {};
  my $fh = new IO::File($inputFile, 'r') 
       or die "Cannot open $inputFile, $!\n";
  while (<$fh>) {
    chomp;
    my ($filename,$status) = split;
    next if ((! -e $filename) || ($status != 2)); # we do clean up disk

    # Nicola wanted a standard naming convention
    my $run = basename $filename;
    if ($run =~ /^EDM/) {
      $run =~ s/EDM(\d+)(?:.*)/$1/;
    }
    else {
      $run =~ s/tif\.(\d+)\.A\.(?:.*)/$1/;
    }
    next if -e $outputDir."/".EDMTAG.$run;

    # Gather File info, does it have events
    my $nevt = getFileInfo($filename);
    next if int($nevt) <= 0;

    print "INFO. Processing $filename\n" if DEBUG;
    print "\thas $nevt events\n" if DEBUG;

    # Now check status on Castor
    my $lfn = $filename;
    $lfn =~ s#$baseDir#$lfnDir#;

    # Check if the file is registered at Castor at all
    chop(my $lfnExists = `rfdir $CASTORDIR/$lfn 2>/dev/null | wc -l`);
    $lfnExists = _trim($lfnExists);
    if (not $lfnExists) {
      print "\tSkipped. not yet copied to Castor!\n";
      next;
    }

    # Is it being transferred now
    chop(my $lfnSize = `rfdir $CASTORDIR/$lfn 2>/dev/null | awk '{print \$5}'`);
    $lfnSize = _trim($lfnSize);
    if (not $lfnSize) {
      print "\tSkipped. being copied to Castor!\n";
      next;
    }

    $list->{$run} .= $lfn.":";
  }
  $fh->close;

  my @runList = sort {int(sprintf("%d",$a)) <=> int(sprintf("%d",$b))} keys %$list;
  die "INFO. No new runs to process!" if !scalar(@runList);
  print join ("\n", "New runs:", @runList), "\n\n" if DEBUG;

  # there might be more files to the last run number
  # that are being processed right now, so install a check
  my $lastRun = $runList[-1];
  my $lastRunFiles = $list->{$lastRun};
  pop @runList if !runClosed($lastRun, $lastRunFiles);

  for my $run (@runList) 
  {
    my $str = $list->{$run};
    my @files = getFiles ($str);
    my $nfiles = scalar @files;
    next if !$nfiles;
    print join ("\n", $run, @files), "\n" if DEBUG; 

    # Second line of defence, check if number of edm/raw files on disk 
    # matches with that of the list obtained
    # This will certainly fail if the clean-up script runs too frequently
    my $aref = checkLocalFiles($run, $files[0]);
    if ($nfiles != $aref->[0] || $nfiles != $aref->[1]) {
      print "Skipped. File number mismatch, run=$run,nfiles=$nfiles,nedm=$aref->[0],nraw=$aref->[1]\n"; 
      next;
    }    

    my $outputFile = $outputDir."/".EDMTAG.$run; 
    my $fh = new IO::File($outputFile, 'w') 
        or die "Cannot open $outputFile for writing, $!\n";
    print $fh join ("\n", @files), "\n";
    $fh->close;
  }
}

sub checkLocalFiles($$)
{
  my ($run, $eFile) = @_;
  $eFile =~ s#$lfnDir#$baseDir#g;  # point to EDM location

  my @a = readDir(dirname($eFile), $run, 0);
  my $nedm = scalar @a;

  # Get the corresponding raw file
  my $rFile = '';
  my $fh = new IO::File($mapFile, 'r') 
    or die "Cannot open $mapFile, $!\n";
  while (<$fh>) {
    if (/$eFile/) {
      my @fields = split;
      $rFile = $fields[-1] if scalar(@fields)>1;
      last;
    }
  }
  $fh->close;
  return [$nedm, -1] if $rFile eq '';

  my @b = readDir(dirname($rFile), $run, 1);
  my $nraw = scalar @b;

  [$nedm, $nraw];
}

sub readDir($$$)
{
  my ($dir, $run, $index) = @_;
  print "dir=$dir,run=$run,index=$index\n" if DEBUG;
  # /RU0\{0,7\}${run}_[0-9]*.root"
  # /[a-zA-Z]*.0\{0,8\}${run}.A.[a-zA-Z0-9_.]*.dat"

  opendir(DIR, $dir) || die "Can't open directory $dir, $!\n";
  my @a = readdir(DIR); 
  if ($index > 0) {
    @a = grep { /(?:RU|tif\.)(?:.*)$run(?:.*)\.(?:root|dat)$/ } @a;
  }
  else {
    @a = grep { /(?:EDM|tif\.)(?:.*)$run(?:.*)\.(?:root|dat)$/ } @a;
  }
  closedir(DIR);
  @a;
}

sub getFiles ($)
{
  my $str = shift;
  split /:/, substr($str, 0, length($str)-1);
}

sub runClosed ($$)
{
  my ($run, $fileList) = @_;
  $fileList =~ s#$lfnDir#$baseDir#g;
  my @files = getFiles($fileList);
  my $nEDMFiles = scalar @files;
  return 0 if !$nEDMFiles;  # should not happen though

  # The most recent edm file
  my $eFile = getLatestFile(\@files);

  # Get the corresponding raw file
  my $rFile = '';
  my $fh = new IO::File($mapFile, 'r') 
    or die "Cannot open $mapFile, $!\n";
  while (<$fh>) {
    if (/$eFile/) {
      my @fields = split;
      $rFile = $fields[-1] if scalar(@fields)>1;
      last;
    }
  }
  $fh->close;
  return 0 if $rFile eq '';

  # Check the timestamp of the raw file and if it is old enough, return true
  my $mtime = stat($rFile)->mtime;

  # Is that the last raw file for that run?
  my $d = dirname $rFile;
  my @a = readDir($d, $run, 1);
  @a = map {$d."/".$_} @a;
  my $nRawFiles = scalar @a;
  return 0 if (!$nRawFiles || $nEDMFiles < $nRawFiles);

  my $lrFile = getLatestFile (\@a);
  my $lrtime = stat($lrFile)->mtime;
  return 0 if ($lrtime > $mtime);   

  # All the tricks failed; Now check if the last file is at least n hours old
  my $age = time() - $mtime;
  $age -= TLIMIT;
  return 1 if $age;

  return 0;
}

sub getLatestFile($)
{
  my $aref = shift;
  # do lots of stuff at a time
  my @files = 
    map {$_->[0]}
    sort {$a->[1] <=> $b->[1]}
    map {[$_, -M]}
    @$aref;
  $files[0];
}

sub getFileInfo($)
{
  my $filename = shift;

  my $nevents = -1;
  if ( -e $infoFile ) {
    my $mode = 'r';
    my $fh = new IO::File($infoFile, $mode) or die "Cannot open $infoFile as $mode, $!\n";
    while (<$fh>) {
      chomp;
      if ((index $_, $filename) > -1) {
        $nevents = (split)[2];
        last;
      }
    }
    $fh->close;
  }

  return $nevents if ($nevents != -1);

  chop(my $info = `$ENV{HOME}/scripts/fileInfo.sh $filename 2>/dev/null`);
  if ($info ne "") {
    $nevents = (split /\s+/, $info)[2];
    $filename =~ s#$baseDir#$lfnDir#;

    my $mode = 'a';
    $mode = 'w' if (! -e $infoFile);
    my $fh = new IO::File($infoFile, $mode) or die "Cannot open $infoFile as $mode, $!\n";
    print $fh join (" ", $info, $filename), "\n";
    $fh->close;
  }

  $nevents;
}

# Go
main;

__END__
