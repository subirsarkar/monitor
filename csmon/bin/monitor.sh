#!/bin/sh
#set -o nounset

BASEDIR=/afs/cern.ch/cms/LCG/crab/csmon
WEBDIR=/afs/cern.ch/cms/LCG/crab/server
source $BASEDIR/setup.sh

cd $BASEDIR/bin || { echo Failed to cd to $BASEDIR/bin; exit 1; }
perl -w monitor.pl
cp -p $BASEDIR/db/*.json $WEBDIR/rrd/
cp -p $BASEDIR/db/*.rrd $WEBDIR/rrd/
cp -p $BASEDIR/images/rrd/*.png $WEBDIR/images/
exit $?
