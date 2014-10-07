#!/bin/sh
#set -o nounset

appdir=/opt/jobview_t2
webdir=/var/www/html/ucsd

source $appdir/setup_jobview

cd $appdir/bin || { echo cannot cd to $appdir/bin; exit 1; }
perl -w overview.pl

[ -d $webdir ] || { echo $webdir not found locally!; exit 2; }
echo -- copy over to the web server
cp $appdir/html/overview.html $webdir/
cp $appdir/images/rrd/*.png $webdir/images/

[ -e $appdir/html/overview.xml ]  && cp $appdir/html/overview.xml  $webdir/
[ -e $appdir/html/overview.json ] && cp $appdir/html/overview.json $webdir/
[ -e $appdir/html/jobview.xml ] && cp $appdir/html/jobview.xml $webdir/

exit 0
