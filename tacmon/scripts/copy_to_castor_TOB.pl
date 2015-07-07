#!/usr/bin/perl 
#
# copies files from $source to $dest (on castor) via rfcp
# copies only files which did not change in the last $timewait seconds
# before copying, it checks whether the file is already in place, 
# with the same size. If the file is new, copy it.
# If there is already one with different size, do nothing but issue a warning
# Does it recursively
$inisource = "/data2/TOB";
$inidest = "/castor/cern.ch/cms/testbeam/TAC/TOB";

$initimewait = 40*60;

$ENV{'STAGE_HOST'} = 'castorcms';
$ENV{'RFIO_USE_CASTOR_V2'} = 'YES';

#
# use locking? default = yes
#
$useLocking=1;

$lockingDir = "/data2/locking";

print "Starting ...\n";

RecursiveCopy ($inisource, $inidest, $initimewait);

print "Finished ! \n";

exit(0);
#
#
#

sub RecursiveCopy {
    my($source, $dest, $timewait) = @_;
    my $HANDLE;
#    my ($size,$rsize,$rsizeTMP,$input);
#    print "Inside ... $source \n";
    
    open( $HANDLE, "cd $source; ls -1 |" );
    while ($input=<$HANDLE>)  {
	chomp ($input);
#	print "Looping Input $input\n";
	if (-d "$source/$input"){
#	    print "$input is a directory; go recursive\n";
	    system ("rfmkdir $dest/$input");
	    RecursiveCopy("$source/$input","$dest/$input",$timewait);
#	    print "After recursion \n";
	}else{
	    #
# a file
#
# 1 check if the file is too new
	    open( TESTHANDLE, "$source/$input" );
	    ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,
	     $mtime,$ctime,$blksize,$blocks)= stat(TESTHANDLE);
	    close (TESTHANDLE);
#	    print "TIME $ctime\n";
	    $time = time();
	    $timediff= $time-$mtime;
#	    print "Localtime $time  $timediff\n";
	    if ($timediff >  $timewait){
#		print "I can copy this file! \n";
#
# should I copy it?
#
		$copy = 0;$skip=0;
		#
# does it exist?
#
		if ($useLocking ==1){
		    #
# check for lock
#
		    $lockName = "$source/$input";
		    $lockName =~ s/\//_/g; 
		   # print "LockName $lockName\n";
		    if (-e "$lockingDir/$lockName" ){
			$skip = 1;
#print "Locked $lockName\n";
		    }
		}
		if ($skip ==0){
		    $exist = `rfdir $dest/$input |wc -l`;
		    if ($exist>0){
#		    print "The file exists remotely\n";
			
#			print "The size is $size\n";
			$rsize = `rfdir $dest/$input|awk '{print \$5}'`;
#			($d1,$2,$d3,$d4,$rsize,$d5) = split ("\s+ ",$rsizeTMP);
#			print "Remote size is $rsize\n";
			$copy = 0;
			if ($size != $rsize){
#			print " Remote file different length. NOT copying\n";
			    print "WARNING File exists on REMOTE but of different size $source/$input $size $rsize\n";
#
# put $copy = 1 if default behavior = OVERWRITE 
#
			    if ($size> $rsize){
				print " Since remote size is SMALLER that LOCAL size, I copy it\n";
				$copy = 1;
			    }else{
				$copy = 0;
			    }
			}
		    }else{
			$copy =  1;
		    }
		}
		if ($copy == 1){
		    if ($useLocking == 1){
		    print "Copying $input\n";
			
			system ("touch $lockingDir/$lockName");
		    }
		    $code = system ("rfcp $source/$input $dest/$input");
 if ($code != 0){
     print "Error. Copying of file $input FAILED. Deleting...\n";
			    system ("rfrm $dest/$input");
		    }
		    #
# check size
#
		    $rsize = `rfdir $dest/$input|awk '{print \$5}'`;
#		    print "ECCO $size $rsize \n";
		    if ($rsize != $size) {
			print "Error. Copying of file $input FAILED.\n";
		    }
		    if ($useLocking == 1){
			system ("rm -f $lockingDir/$lockName");
		    }

		}
	    }
	}
    }
    close ($HANDLE);
#    print "Exiting ...\n";
}
