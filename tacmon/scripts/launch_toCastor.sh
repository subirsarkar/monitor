#!/bin/sh

DEBUG=1
PROGNAME=$HOME/scripts/edm_to_castor.sh
COMMAND=`basename $PROGNAME`
count=`ps --no-headers -l -C $COMMAND | wc -l`
if [ "$count" -gt 0 ]; then
  cmdrunning=`ps --no-headers -C $COMMAND -o cmd`
  if echo $cmdrunning | grep $COMMAND > /dev/null
  then
    echo INFO. `date '+%F %T'` another $COMMAND instance running ...
    echo $0 PID: $$
    if [ $DEBUG -gt 0 ]; then ps --columns 180 --no-headers -fl -C $COMMAND; fi
    exit 1
  fi
fi


for DET in TIB TOB TEC ; do
  echo -- Started $DET at `date` --
  $PROGNAME $DET
  status=$?
  echo "-- Finished $DET at `date` --";
done

exit $status
