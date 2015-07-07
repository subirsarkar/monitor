#!/bin/sh

PROGNAME=$HOME/bin/ftsmon.sh
COMMAND=`basename $PROGNAME`
count=`ps --no-headers -l -C $COMMAND | wc -l`
if [ "$count" -gt 0 ]; then
  echo INFO. `date '+%F %T'` another $COMMAND instance running ...
  echo $0 PID: $$
  ps --no-headers -l -C $COMMAND
  exit 1
fi

RHOST=fts.cr.cnaf.infn.it
# First of all check if the remote machine is up, if not give up
ping -c 5 $RHOST 1> /dev/null 2> /dev/null
if [ "$?" -ne 0 ]; then
  echo $RHOST does not respond, exiting ....
  exit 2
fi

$PROGNAME
echo -- Finished at `date` --
