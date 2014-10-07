#!/bin/sh
#set -o nounset

WEBDIR=/var/www/html/glidein_frontend
appdir=/opt/jobview
source $appdir/bin/setup.sh

cd $appdir/bin || { echo cannot cd $appdir/bin; exit 1; }
perl -w overview.pl
cp $appdir/html/overview.html $WEBDIR/
cp $appdir/images/rrd/*.gif $WEBDIR/images/
exit $?
