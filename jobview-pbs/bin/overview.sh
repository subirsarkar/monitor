#!/bin/sh
#set -o nounset

BASEDIR=/opt/jobview
source $BASEDIR/setup.sh

cd $BASEDIR/bin || { echo cannot cd $BASEDIR/bin; exit 1; }
perl -w overview.pl
scp $BASEDIR/html/overview.html $BASEDIR/html/jobview.xml gridse.sns.it:/var/www/html/pbs/
scp $BASEDIR/images/rrd/*.png gridse.sns.it:/var/www/html/pbs/images/
exit $?
