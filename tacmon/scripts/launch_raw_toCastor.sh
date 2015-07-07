#!/bin/sh

DEBUG=1
PROGNAME=$HOME/scripts/copy_raw_toCastor.sh
COMMAND=$(basename $PROGNAME)
let "count = $(ps --no-headers -l -C $COMMAND | wc -l)"
if [ "$count" -gt 0 ]; then
  cmdrunning=$(ps --no-headers -C $COMMAND -o cmd)
  if echo $cmdrunning | grep $COMMAND > /dev/null
  then
    echo INFO. $(date '+%F %T') another $COMMAND instance running ... 2>&1
    echo $0 PID: $$ 2>&1
    [ $DEBUG -gt 0 ] && ps --columns 180 --no-headers -fl -C $COMMAND
    exit 1
  fi
fi

source /afs/cern.ch/group/zh/group_env.sh
for path in $(echo /data3:TIBTOB /data1:DQMoutput /data3:TOB /data3:TIB /data3:TIF /data3:Minus /data2:TIBTOB /data2:TIF)
do
  disk=$(echo $path | awk -F: '{print $1}')
   det=$(echo $path | awk -F: '{print $2}')
  echo -- Started $det at $(date) --
  $PROGNAME $disk $det
  status=$?
  echo -- Finished $det at $(date) with status=$status --
done

exit $status
