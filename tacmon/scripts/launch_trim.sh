#!/bin/sh

DEBUG=1
PROGNAME=$HOME/scripts/trim.sh
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

for path in $(echo /data2:10:20 /data3:6:40)
do
  disk=$(echo $path | awk -F: '{print $1}')
   age=$(echo $path | awk -F: '{print $2}')
  dlim=$(echo $path | awk -F: '{print $3}')

  echo -- Started $path at $(date) --
  $PROGNAME $disk --age $age --limit $dlim ## --verbose
  status=$?
  echo -- Finished $path at $(date) -- with status=$status
done
echo
exit $status
