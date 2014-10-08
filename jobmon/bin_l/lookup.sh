#!/bin/sh
#set -o nounset

APPDIR=/opt/jobmon
export JOBMON_CONFIG_DIR=$APPDIR/etc/Collector
if [ -z PERL5LIB ]; then
  export PERL5LIB=$APPDIR/lib:$PERL5LIB
else
  export PERL5LIB=$APPDIR/lib
fi
perl -w lookup.pl $1
exit $?
