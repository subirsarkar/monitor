#!/bin/sh
#set -o nounset

appdir=/usr/local/hpc-tools/lsfmon_v2.0.0
webdir=/afs/pi.infn.it/www/servizi/calcolo/hpc-lsfmon/dev

source $appdir/bin/setup_lsfmon

[ -e /etc/profile.d/lsf.sh ] && source /etc/profile.d/lsf.sh

cd $appdir/bin || { echo cannot cd to $appdir/bin; exit 1; }
./user_group.exe $appdir/db/group_info.txt
perl -w overview.pl

[ -d $webdir ] || { echo $webdir not found locally!; exit 2; }
echo -- copy over to the web server
cp $appdir/html/overview.html $webdir/
cp $appdir/html/overview.queue.html $webdir/
mkdir -p $webdir/images
cp $appdir/images/rrd/*.png $webdir/images/

[ -e $appdir/html/overview.xml ]  && cp $appdir/html/overview.xml  $webdir/
[ -e $appdir/html/overview.json ] && cp $appdir/html/overview.json $webdir/
[ -e $appdir/html/jobview.xml ] && cp $appdir/html/jobview.xml $webdir/

exit 0
