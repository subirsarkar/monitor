#!/bin/sh

set -o nounset

for file in `find . -type f -name '*StorageManager*' -print`
do
  bname=`basename $file`
  newfile=`echo $bname | perl -lnae 's/(?:.*)\.(\d+)\.(?:.*)/EDM$1/; print'`
  echo mv $file $newfile
  mv $file $newfile
done

exit 0
