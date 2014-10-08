#!/bin/bash

fileLogN=`for i in /opt/condor/local/log/StarterLog.slot? /storage/local/data1/condor/execute/dir_*/glide_*/log/StarterLog ; do tail -30 $i | grep -v "timeout reading \|IO: Failed to read packet" | grep ": $1$" >/dev/null 2>&1 ; if [ $? -eq 0 ] ; then echo $i ; fi ;  done | wc -l | sed 's/ .*//'` 

if [ $fileLogN -eq 1 ] ; then 
  fileLog=`for i in /opt/condor/local/log/StarterLog.slot? /storage/local/data1/condor/execute/dir_*/glide_*/log/StarterLog ; do tail -30 $i | grep -v "timeout reading \|IO: Failed to read packet" | grep ": $1$" >/dev/null 2>&1 ; if [ $? -eq 0 ] ; then echo $i ; fi ;  done`
  pPid=`tail -50 "$fileLog" 2>&1 | grep "Create_Process succeeded" | tail -1 | sed 's/.*=//'`

  if [ ! -z "$pPid" ] ; then 
    pstree -l -p "$pPid" 2>&1 | sed 's!)[^(]*(!\n!g' | sed 's/).*//' | sed 's/.*(//'
  fi
fi  
