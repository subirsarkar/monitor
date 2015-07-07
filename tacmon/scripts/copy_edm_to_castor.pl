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
					     
use constant DEBUG => 1;
					     
my $det = shift(@ARGV) || "TIB";
					     
					     
my $inisource = "/data2/EDMProcessed/$det";
my $inidest   = "/castor/cern.ch/cms/store/TAC/$det";
my $timewait = 30*60;
my $lockingDir = "$inisource/lock";
my $useLocking = 1; # use locking? default = yes
					     
print "Starting $det...\n";
RecursiveCopy ($inisource, $inidest, $timewait);
print "Finished ! \n";
exit(0);
					     
sub RecursiveCopy ($$$) {
  my ($source, $dest, $timewait) = @_;
  my $lockName;
  local *HANDLE;
  #  print " STARING FROM $source \n";
  open HANDLE, qq(cd $source; ls -1 |) or die qq(Cannot list directory; $!);
  while (my $input=<HANDLE>)  {
     chomp($input);
     my $srcEntry = $source."/".$input;
     my $dstEntry = $dest."/".$input;

     next if -l $srcEntry;       # ignore symbolic links

     #    print "AAA $srcEntry  $dstEntry \n"; 
						     
						     if (-d $srcEntry) {         # a directory
							 
							 print "Entering directory: $srcEntry\n" if DEBUG;  
							 # Don't try to create a directory over and over again
#      chop (my $dirFlag = `rfstat $dstEntry 2>/dev/null`);
#      if (not defined $dirFlag) {
							 my @args = ("rfmkdir", qq/$dstEntry/); 
							 print "ARGS @args\n";
							 system(@args);
							 #         or die "system @args failed; $?";
#      }

							 RecursiveCopy($srcEntry, $dstEntry, $timewait);
						     }
						     else {   # a file
							 # Is it an EDM file?
							 next if !($input =~ /^EDM(?:.*)\.root$/);

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

#							     print "ECCO $input $skip $copy\n";

							     if ($skip == 0) {

								 chop(my $exist = `rfdir $dstEntry 2>/dev/null | wc -l`);
								 $exist = _trim($exist);
#								 print "FILE  $dstEntry $exist\n";

								 if ($exist > 0) {
								     chop(my $rsize = `rfdir $dstEntry | awk '{print \$5}'`);
								     $rsize = _trim($rsize);
								     
								     if ($size != $rsize) {
									 print "WARNING File exists on REMOTE but of different size $srcEntry $size $rsize\n";
									 # put $copy = 1 if default behavior = OVERWRITE 
									 if ($size > $rsize) {
									     print " Since remote size is SMALLER that LOCAL size, I copy it\n";
									     $copy = 1;
									 }
									 else {
									     $copy = 0;
									 }
								     }
								     
								 }else {
								     $copy = 1;
								 }
							     }
							     doCopy ($input, $srcEntry, $dstEntry, $lockName, $useLocking, $size) if $copy;
							 }
						     }
						 }
						 close HANDLE;
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
# aggiunto da tommaso, nel caso che rimanga sporco il NS
#
									system ("rfrm $dstEntry");
									die "system @args failed; $?";
								    }

								    # Check if the copy failed for some reason
								    chop(my $rsize = `rfdir $dstEntry 2>/dev/null | awk '{print \$5}'`);
								    $rsize = _trim($rsize);
								    if ($rsize != $size) {
									print "Error. Copying of file $input FAILED. removing ...\n"; 
									my @args = ("rfrm", qq/$dstEntry/);
									system(@args) == 0
									    or warn "system @args failed; $?";
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
