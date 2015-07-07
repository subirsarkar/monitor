#!/bin/sh
set -o nounset

# Check if enough space is available for backup creation
# Not exact as we zip the files, still ....
space_req=`du -sk $HOME | awk '{print $1}'`
space_avl=`df -k / | awk '{if (NR>1) print $4}'`
let "diff = $space_avl - $space_req"
if [ $diff -le 0 ]; then
  echo ERROR. Not enough space left on / partition, skip; exit 1; 
fi 

# Prepare the backup
bupfile=/tmp/backup_cmstac_cmstkstorage_`date "+%d_%m_%y"`.tgz
cd $HOME
tar -c -z -h --file=$bupfile --ignore-failed-read --exclude="*.root" ./ 
if [ $? -ne 0 ]; then echo ERROR. Backup could not be created; exit 2; fi

# Copy over to Castor
rfcp $bupfile /castor/cern.ch/cms/testbeam/TAC/backup/`basename $bupfile`
status=$?
rm -f $bupfile

echo Finished at `date`
echo ----
exit $status
