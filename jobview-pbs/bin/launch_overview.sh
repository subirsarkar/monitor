#!/bin/sh
set -o nounset

dir=$(dirname $0)
let "DEBUG = 1"
PROGNAME=$dir/overview.sh
COMMAND=$(basename $PROGNAME)
let "count = $(ps --no-headers -l -C $COMMAND | wc -l)"
if [ "$count" -gt 0 ]; then
  cmdrunning=$(ps --no-headers -C $COMMAND -o cmd)
  if echo $cmdrunning | grep $PROGNAME > /dev/null
  then
    if [ $DEBUG -gt 0 ]; then
      echo Time: $(date '+%D-%T') Caller: $(basename $0) - $COMMAND already running ...
      ps --columns 180 --no-headers -fl -C $COMMAND
    fi
    exit 1
  fi
fi

echo -- Started at $(date) --
$PROGNAME
status=$?
echo -- Finished at $(date) with status=$status --
exit $status
