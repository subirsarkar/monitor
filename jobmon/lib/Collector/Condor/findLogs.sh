#!/bin/bash

fileLogN=`for i in /opt/condor/local/log/StarterLog.slot? /storage/local/data1/condor/execute/dir_*/glide_*/log/StarterLog ; do tail -30 $i | grep -v "timeout reading \|IO: Failed to read packet" | grep ": $1$" >/dev/null 2>&1 ; if [ $? -eq 0 ] ; then echo $i ; fi ;  done | wc -l | sed 's/ .*//'` 

if [ $fileLogN -eq 1 ] ; then 
  fileLog=`for i in /opt/condor/local/log/StarterLog.slot? /storage/local/data1/condor/execute/dir_*/glide_*/log/StarterLog ; do tail -30 $i | grep -v "timeout reading \|IO: Failed to read packet" | grep ": $1$" >/dev/null 2>&1 ; if [ $? -eq 0 ] ; then echo $i ; fi ;  done`
  pLog=`tail -30 "$fileLog" 2>&1 | grep -v "timeout reading \|IO: Failed to read packet" | tail -4 | head -1 | grep "Output file" | sed 's/.*: //'` 

  if [ ! -z "$pLog" ] ; then 
    echo $pLog
  fi
fi  
