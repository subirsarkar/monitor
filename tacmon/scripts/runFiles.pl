#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;
use IO::File;

use lib qw(/home/cmstac/scripts);
use Util qw( _trim );

use constant DEBUG => 1;

my $det = shift(@ARGV) || "TIB";

my $basedir   = "/data2/EDMProcessed/$det";
my $inputFile = "$basedir/fileProcessed.txt";
my $outputDir = "$basedir/dbs";
my $lfnDir    = "/store/TAC/$det";
my $CASTORDIR = "/castor/cern.ch/cms";

$ENV{'STAGE_HOST'} = 'castorcms';
$ENV{'RFIO_USE_CASTOR_V2'} = 'YES';


sub main {
  my $list = {};
  my $fh = new IO::File($inputFile, 'r') 
       or die "Cannot open $inputFile, $!\n";
  while (<$fh>) {
      my $file = (split)[0];
      print "LOOKING AT $file\n";
      
    my $name = basename $file;
    my $run = (split /_/, $name)[0];
    next if -e $outputDir."/".$run;

    $file =~ s#$basedir##;
      print " FILE $file\n";
    my $lfn = $lfnDir.$file;
    print $lfn, "\n" if DEBUG;

    # Check if the file is registered at Castor at all
    chop(my $lfnExists = `rfdir $CASTORDIR/$lfn 2>/dev/null | wc -l`);
    $lfnExists = _trim($lfnExists);
    next if not $lfnExists;
      print "FILE ESISTE $lfnExists\n";
    # Is it being transferred now
    chop(my $lfnSize = `rfdir $CASTORDIR/$lfn 2>/dev/null | awk '{print \$5}' `);
    $lfnSize = _trim($lfnSize);
    next if not $lfnSize;

    $list->{$run} .= $lfn.":";
  }
  $fh->close;

  my @runList = sort keys %$list;
  pop @runList; # Let's assume there are more files to the last run number
                # that are being processed right now

  for my $run (@runList) 
  {
    print join (":", $run, $list->{$run}), "\n" if DEBUG; 
    my $str = $list->{$run};
    my @files = split /:/, substr($str, 0, length($str)-1);
    my $outputFile = $outputDir."/".$run; 
    open OUTPUT, ">$outputFile" or die "Cannot open $outputFile for writing, $!";
    print OUTPUT join ("\n", @files), "\n";
    close OUTPUT;
  }
}
main;

__END__
