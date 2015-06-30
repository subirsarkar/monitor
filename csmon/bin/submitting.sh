#!/bin/sh
#set -o nounset

BASEDIR=/afs/cern.ch/cms/LCG/crab/csmon
WEBDIR=/afs/cern.ch/cms/LCG/crab/overview
source $BASEDIR/setup.sh

cd $BASEDIR/bin || { echo Failed to cd to $BASEDIR/bin; exit 1; }
perl -w submitting.pl > ./tasks_submitting.txt
echo >> ./tasks_submitting.txt
echo "Updated at $(date -u) (next update in 10 mins)" >> ./tasks_submitting.txt
cp -p ./tasks_submitting.txt $WEBDIR/
exit $?
