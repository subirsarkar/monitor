#!/bin/sh
#set -o nounset

BASEDIR=/opt/jobview
source $BASEDIR/setup.sh

perl -w create_rrd.pl
perl -w create_vo_rrd.pl

exit $?
