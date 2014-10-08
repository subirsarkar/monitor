#!/bin/sh
#set -o nounset

appdir=/opt/jobmon
cd $appdir/bin || { echo cannot cd $appdir/bin; exit 1; }
perl -w trimDB.pl 30
exit $?

