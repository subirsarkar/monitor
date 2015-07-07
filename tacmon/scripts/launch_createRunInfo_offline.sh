#!/bin/sh

DEBUG=1
PROGNAME=$HOME/scripts/createRunInfo_offline.sh
COMMAND=$(basename $PROGNAME)
count=$(ps --no-headers -l -C $COMMAND | wc -l)
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

$PROGNAME 
status=$?
echo -- Finished $path at $(date) with status=$status --
exit $status
echo ----


