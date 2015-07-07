#!/usr/bin/env perl 
#
# copies files from $source to $dest (on castor) via rfcp
# copies only files which did not change in the last $timewait seconds
# before copying, it checks whether the file is already in place, 
# with the same size. If the file is new, copy it.
# If there is already one with different size, do nothing but issue a warning
# Does it recursively

use strict;
use warnings;

use IO::File;

use lib qw(/home/cmstac/scripts);
use Util qw( _trim );

$ENV{'STAGE_HOST'} = 'castorcms';
$ENV{'RFIO_USE_CASTOR_V2'} = 'YES';

sub doCopy($$$$$$);
sub setLock($);
sub removeLock($);
sub RecursiveCopy($$$);
sub correctType($);

use constant DEBUG => 1;
use constant MB2BY => 1024**2;

my $vol = shift || die qq[Usage: $0 data_area [det]\n Example: $0 /data3 [TIF]];
my $det = shift || "TIB";

my $inisource  = qq[$vol/EDMProcessed/$det];
my $inidest    = qq[/castor/cern.ch/cms/store/TAC/$det];
my $timewait   = 30*60;
my $lockingDir = qq[$inisource/lock];
my $useLocking = 1;            # use locking? default = yes
my $overwrite  = 0;
my $skipinvalid  = 0;

print "Starting $det...\n";
RecursiveCopy ($inisource, $inidest, $timewait);
print "Finished ! \n";
exit(0);

sub RecursiveCopy ($$$) {
  my ($source, $dest, $timewait) = @_;
  my $lockName;
  local *HANDLE;
  my @args;
  open HANDLE, qq(cd $source; ls -1 |) or die qq(Cannot list directory; $!);
  while (my $input=<HANDLE>)  {
     chomp($input);
     my $srcEntry = $source."/".$input;
     my $dstEntry = $dest."/".$input;

     next if -l $srcEntry;       # ignore symbolic links
     if (-d $srcEntry) {         # a directory
       print "Entering Source directory: $srcEntry\n" if DEBUG;  

       # Don't try to create a Destination directory on Castor over and over again
       @args = ("rfstat $dstEntry >/dev/null 2>&1"); 
       if (system(@args) != 0) {
         print "Non-zero status, $?, Create directory $dstEntry\n";
         @args = ("rfmkdir", qq/$dstEntry/); 
         system(@args) or warn "system @args failed; $?";
       }
       RecursiveCopy($srcEntry, $dstEntry, $timewait);
     }
     else {   # a file
       # Is it an EDM file?
       # Must consider both RU->EDM and SM->EDM
       next if not correctType($input);

       # If the file size is rather small, see if there are events, if not 
       # do not copy to Castor
       if ($skipinvalid) {
         my $fsize = -s $srcEntry;
         if (int($fsize) < 10*MB2BY) {
           my $nevents = -1;
           chop(my $info = `$ENV{HOME}/scripts/fileInfo.sh $srcEntry 2>/dev/null`);
           $nevents = (split /\s+/, $info)[2] if ($info ne '');
           if (int($nevents)<2) {
             print "Skipping $srcEntry, size=$fsize bytes, nevents=$nevents\n" if DEBUG;
             next;
           }
         }
       }
       # Check if the file is being created now
       my $edmLockFile = $inisource."/lock/".$input;
       $edmLockFile =~ s/\.root$/\.lock/;
       next if -e $edmLockFile;

       # Check if the file is too new
       my ($size, $mtime) = (stat($srcEntry))[7,9];

       my $time = time();
       my $timediff = $time - $mtime;
       if ($timediff > $timewait) {
         # should I copy it?
         my $copy = 0;
         my $skip = 0;

         # does it exist?
         if ($useLocking) {
           # check for lock
           $lockName = $srcEntry;
           $lockName =~ s/\//_/g; 
           $skip = 1 if -e "$lockingDir/$lockName";
         }
         if ($skip == 0) {
           chop(my $exist = `rfdir $dstEntry 2>/dev/null | wc -l`);
           $exist = _trim($exist);
           if ($exist > 0) {
             chop(my $rsize = `rfdir $dstEntry | awk '{print \$5}'`);
             $rsize = _trim($rsize);

             if ($size != $rsize) {
                print "WARNING File exists on REMOTE but of different size $srcEntry $size $rsize\n";
                # put $copy = 1 if default behavior = OVERWRITE 
                if ($overwrite && $size > $rsize) {
                  print " Since remote size is SMALLER that LOCAL size, I copy it again\n";
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
         doCopy ($input, $srcEntry, $dstEntry, $lockName, $useLocking, $size) if $copy;
      }
    }
  }
  close HANDLE;
}

sub correctType ($) {
  my $filename = shift;
  return 1 if ($filename =~ /^EDM(?:.*)\.root$/ or $filename =~ /(?:.*)StorageManager(?:.*)\.root$/);
  return 0;
}

sub doCopy ($$$$$$) {
  my ($input, $srcEntry, $dstEntry, $lockName, $useLocking, $size) = @_;
  print "Copying $input\n";

  setLock($lockName) if $useLocking;  # set up a lock

  # Now copy to Castor
  my @args = ("rfcp", qq/$srcEntry/, qq/$dstEntry/);
  print join (" ", @args), "\n" if DEBUG; 
  if (system(@args) != 0) {
    removeLock($lockName) if $useLocking;  # Clear the lock if copy fails
    #
    # Tommaso: nel caso che rimanga sporco il NS
    my @args = ("rfrm", qq/$dstEntry/);
    system(@args) == 0 or warn "system @args failed; $?";

    return;
  }

  # Check if the copy failed for some reason
  chop(my $rsize = `rfdir $dstEntry 2>/dev/null | awk '{print \$5}'`);
  $rsize = _trim($rsize);
  if ($rsize != $size) {
    print "Error. Copying of file $input FAILED. removing ...\n"; 
    my @args = ("rfrm", qq/$dstEntry/);
    system(@args) == 0 or warn "system @args failed; $?";
  }

  removeLock ($lockName) if $useLocking;  # in due course
}

sub setLock($) {
  my $lockName = shift;
  my $lockFile = $lockingDir."/".$lockName; 
  print "Create a lock as $lockFile ...\n" if DEBUG;
  my @args = ("touch", qq/$lockFile/);
  system(@args) == 0
   or die "system @args failed; $?";
}

sub removeLock($) {
  my $lockName = shift;
  my $lockFile = $lockingDir."/".$lockName; 
  print "Releasing the lock $lockFile ...\n" if DEBUG;
  my @args = ("rm", "-f", qq/$lockFile/); 
  system(@args) == 0
    or die "system @args failed; $?";
}
