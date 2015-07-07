use strict;
use warnings;

my $TLIMIT  = 6*60*60;
my $baseDir = "/data3/EDMProcessed/TIB";
my $lfnDir = "/store/TAC/TIB";
sub isRunClosed {
  my $fileList = shift;
  $fileList =~ s#lfnDir#$baseDir#g;
  my @files = split /:/, $fileList;
  my @files = 
    map {$_->[0]}
    sort {$a->[1] <=> $b->[1]}
    map {[$_, -M]}
    @files;
  print join ("\n", @files), "\n";

  my $file = $files[0];
  my $write_secs = (stat($file))[9];
  my $diff = time() - $write_secs;
  $diff -= $TLIMIT;
  print "$file is >= $TLIMIT seconds old\n" if $diff;
}
$_ = 
"/store/TAC/TIB/edm_2007_02_21/tif.00002921.A.testStorageManager_0.4.root:/store/TAC/TIB/edm_2007_02_21/tif.00002921.A.testStorageManager_0.0.root:/store/TAC/TIB/edm_2007_02_21/tif.00002921.A.testStorageManager_0.1.root:/store/TAC/TIB/edm_2007_02_21/tif.00002921.A.testStorageManager_0.2.root:/store/TAC/TIB/edm_2007_02_21/tif.00002921.A.testStorageManager_0.3.root:/store/TAC/TIB/edm_2007_02_21/tif.00002921.A.testStorageManager_0.4.root";
s#$lfnDir#$baseDir#g;

print;
isRunClosed($_);
