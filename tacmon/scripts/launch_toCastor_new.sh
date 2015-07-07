#!/bin/sh

DEBUG=1
PROGNAME=$HOME/scripts/edm_to_castor_new.sh
COMMAND=$(basename $PROGNAME)
let "count = $(ps --no-headers -l -C $COMMAND | wc -l)"
if [ "$count" -gt 0 ]; then
  cmdrunning=$(ps --no-headers -C $COMMAND -o cmd)
  if echo $cmdrunning | grep $COMMAND > /dev/null
  then
    echo INFO. $(date '+%F %T') another $COMMAND instance running ...
    echo $0 PID: $$
    if [ $DEBUG -gt 0 ]; then ps --columns 180 --no-headers -fl -C $COMMAND; fi
    exit 1
  fi
fi

source /afs/cern.ch/group/zh/group_env.sh
for path in $(echo /data3:TIF /data3:TIB /data3:TOB /data3:TIBTOB /data3:Minus /data2:TEC /data2:TIB /data2:TOB /data2:TIBTOB /data2:TIF)
do
  disk=$(echo $path | awk -F: '{print $1}')
  det=$(echo $path  | awk -F: '{print $2}')
  echo -- Started $path at $(date) --
  $PROGNAME $disk $det
  status=$?
  echo -- Finished $path at $(date) with status=$status --
done

exit $status
