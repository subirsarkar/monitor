#!/usr/bin/perl 
#

# path to clean
$inisource = "/data2/TIB";
#path to compare with
$inidest = "/castor/cern.ch/cms/testbeam/TAC/TIB";
#grace time
$initimewait = 24*3600;

#
# use locking? default = yes
#
$useLocking=1;

$lockingDir = "/data2/locking";

print "Starting ...\n";

RecursiveDelete ($inisource, $inidest, $initimewait);

print "Finished ! \n";

exit(0);
#
#
#

sub RecursiveDelete {
    my($source, $dest, $timewait) = @_;
    my $HANDLE;
#    print "Inside ... $source \n";
    
    open( $HANDLE, "cd $source; ls -1 |" );
    while ($input=<$HANDLE>)  {
	chomp ($input);
#	print "Looping Input $input\n";
	if (-d "$source/$input"){
#	    print "$input is a directory; go recursive\n";
	    RecursiveDelete("$source/$input","$dest/$input",$timewait);
# try and delete the directory on local side
	    system ("echo rm  -f $source/$input");
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
#		print "I can delete this file! \n";
#
# Is that already there
#
		$delete = 0;
# does it exist?
#
		$exist = `rfdir $dest/$input |wc -l`;
		if ($exist>0){
#		    print "The file exists remotely\n";
		    
#		    print "The size is $size\n";
		    $rsize = `rfdir $dest/$input|awk '{print $4}'`;
#			print "Remote size is $rsize\n";
		    $delete = 0;
		    if ($size != $rsize){
#			print " Remote file different length. NOT copying\n";
			print "WARNING File of different size %source/$input\n";
#
# put $delete = 1 if default behavior = DO NOT DELETE
#
			$delete = 0;
		    }else{
			$delete = 1;
		    }
		    
		}else{
		    $delete =  0;
		}
	    }
	    if ($delete == 1){
#		    print "Copying ...";
		system ("echo rf -f  $source/$input");
		#
	    }
	}
    }
    close ($HANDLE);
#    print "Exiting ...\n";
}
