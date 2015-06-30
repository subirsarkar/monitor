#!/bin/sh
#set -o nounset

BASEDIR=/afs/cern.ch/cms/LCG/crab/csmon
WEBDIR=/afs/cern.ch/cms/LCG/crab/overview
source $BASEDIR/setup.sh

cd $BASEDIR/bin || { echo Failed to cd to $BASEDIR/bin; exit 1; }
perl -w crab_overview.pl
cp -p ../html/overview.html $WEBDIR/
cp -p ../images/server/*.png $WEBDIR/images/server/
exit $?
