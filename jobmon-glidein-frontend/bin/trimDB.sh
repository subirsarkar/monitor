#!/bin/sh
#set -o nounset

APPDIR=/opt/jobmon
export JOBMON_CONFIG_DIR=$APPDIR/etc/Collector
if [ -z PERL5LIB ]; then
  export PERL5LIB=$APPDIR/lib:$PERL5LIB
else
  export PERL5LIB=$APPDIR/lib
fi
cd $APPDIR/bin || { echo cannot cd $APPDIR/bin; exit 1; }
perl -w trimDB_v2.pl
exit $?
