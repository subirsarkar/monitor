#!/bin/sh
set -o nounset

appdir=/usr/local/hpc-tools/lsfmon_v2.0.0
webdir=/afs/pi.infn.it/www/servizi/calcolo/hpc-lsfmon/dev

[ -e /etc/profile.d/lsf.sh ] && source /etc/profile.d/lsf.sh
source $appdir/bin/setup_lsfmon

cd $appdir/bin || { echo cannot cd to $appdir/bin; exit 1; }
\rm $appdir/html/accounting.html $appdir/html/l*.html $appdir/images/accounting/*.png
perl -w accounting.pl

echo -- copy accounting.html over to the web server
[ -d $webdir ] || { echo $webdir does not exist!; exit 2; }
cp $appdir/html/accounting.html $appdir/html/l*.html $webdir/
ls -l $webdir/index.html
[ $? -eq 0 ] || ln -s $webdir/accounting.html $webdir/index.html
mkdir -p $webdir/images
cp $appdir/images/accounting/*.png $webdir/images/

exit 0
