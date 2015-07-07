#!/bin/sh
set -o nounset

DEBUG=1
DRYRUN=1

dbsdir=/data2/EDMProcessed/TIB/dbs
swdir=/home/cmstac/Registration

for File in `ls $dbsdir`
do
  run=`echo $File | sed -e 's/^EDM//'`
  if [ $DEBUG -gt 0 ]; then echo "File is $File and Run is $run"; fi
  
  if [ -e "$swdir/logs/processing_$File" ] || [ -e "$swdir/logs/processed_$File" ]
  then
    echo "Skipping $File because it is processing or already processed"
  else 
    if [ $DEBUG -gt 0 ]
    then
      echo "Processing Run $run; executing "
      echo "perl $swdir/RegisterRunInDBSDLS.pl --file=$dbsdir/$File --dataset=/TEST-TAC-120-DAQ/RAW/CMSSW_1_2_0-RAW-Run-$run"
    fi
    if [ $DRYRUN -lt 1 ]; then
      perl $swdir/RegisterRunInDBSDLS.pl --file=$dbsdir/$File --dataset=/TEST-TAC-120-DAQ/RAW/CMSSW_1_2_0-RAW-Run-$run
      if [ $? -gt 0 ]; then echo Could not Register Run to DBS/DLS; exit 1; fi
      sleep 5
    fi
  fi
done

exit 0
