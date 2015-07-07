#!/usr/bin/env perl 

use vars qw/$lockName $disk $det $inisource $inidest $lockingDir $timewait $useLocking/;
use vars qw/$rsize $mapFile/;

use strict;
use warnings;
use IO::File;

# copies files from $source to $dest (on castor) via rfcp
# copies only files which did not change in the last $timewait seconds
# before copying, it checks whether the file is already in place, 
# with the same size. If the file is new, copy it.
# If there is already one with different size, do nothing but issue a warning
# Does it recursively

$ENV{'STAGE_HOST'} = 'castorcms';
$ENV{'RFIO_USE_CASTOR_V2'} = 'YES';

$disk = shift || die qq[Usage: $0 data_area [det]\n Example: $0 /data3 [TIF]];
$det = shift || "TIF";

$inisource   = qq[$disk/$det];
$inidest     = qq[/castor/cern.ch/cms/testbeam/TAC/$det];
$lockingDir  = qq[$disk/locking];
$initimewait = 40*60;
$mapFile = qq[/analysis/monitor/raw2CastorMap.txt];

# use locking? default = yes
$useLocking = 1;

print "Starting ...\n";
RecursiveCopy ($inisource, $inidest, $initimewait);
print "Finished ! \n";
exit(0);

sub RecursiveCopy {
  my($source, $dest, $timewait) = @_;
  local *HANDLE;
  open HANDLE, qq[cd $source; ls -1 |] or die qq(Cannot list directory; $!);
  while (my $input=<HANDLE>)  {
    chomp ($input);
    if (-d "$source/$input") {  # Directory
      system ("rfmkdir $dest/$input");
      RecursiveCopy("$source/$input", "$dest/$input", $timewait);
    }
    else {  # a file
      # 1 check if the file is too new
      open TESTHANDLE, "$source/$input";
      my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,
              $mtime,$ctime,$blksize,$blocks)= stat(TESTHANDLE);
      close TESTHANDLE;

      my $time = time();
      my $timediff = $time - $mtime;
      if ($timediff > $timewait) {
        # should I copy it?
        my $copy = 0; 
        my $skip = 0;

        # does it exist?
        if ($useLocking == 1) {
          # check for lock
          $lockName = "$source/$input";
          $lockName =~ s/\//_/g; 
          $skip = 1 if (-e "$lockingDir/$lockName" );
        }
        if ($skip == 0) {
          chop(my $exist = `rfdir $dest/$input | wc -l`);
          if (defined($exist) && $exist > 0) {
            chop ($rsize = `rfdir $dest/$input | awk '{print \$5}'`);
    	    $copy = 0;
      	    if ($size != $rsize) {
      	      print "WARNING File exists on REMOTE but of different size $source/$input $size $rsize\n";
              # put $copy = 1 if default behavior = OVERWRITE 
      	      if ($size > $rsize) {
      	        print " Since remote size is SMALLER that LOCAL size, I copy it\n";
                $copy = 1;
      	      } 
              else {
      	        $copy = 0;
      	      }
      	    }
          }
          else {
      	    $copy = 1;
      	  }
        }
        if ($copy == 1) {
      	  if ($useLocking == 1) {
      	    print "Copying $input\n";
      	    system ("touch $lockingDir/$lockName");
      	  }
      	  my $code = system ("rfcp $source/$input $dest/$input");
          if ($code != 0) {
            print "Error. Copying of file $input FAILED. Deleting...\n";
      	    system ("rfrm $dest/$input");
      	  }

          # check size
      	  chop($rsize = `rfdir $dest/$input | awk '{print \$5}'`);
    	  print "Error. Copying of file $input FAILED.\n" if ($rsize != $size);

          # Append the local and Castor file name
          if ($input =~ /^RU(?:.*).root$/ || $input =~ /^tif(?:.*).dat$/) {
            open OUTPUT, ">>$mapFile" or die qq[Cannot open $mapFile for writing!, $!];
            print OUTPUT qq[$source/$input], " ", qq[$dest/$input], "\n";
            close OUTPUT; 
          }
   
    	  system ("rm -f $lockingDir/$lockName") if ($useLocking == 1);
        }
      }
    }
  }
  close HANDLE;
}
