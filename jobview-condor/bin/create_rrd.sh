#!/bin/sh
#set -o nounset

BASEDIR=/opt/jobview_t2
source $BASEDIR/setup.sh

perl -w create_rrd.pl
exit $?

