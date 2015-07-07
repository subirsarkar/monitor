#!/bin/sh
set -o nounset

function error_exit
{
  echo "$1" 1>&2
  exit $2
}

function check_space
{ 
  # Check if enough space is available for backup creation
  # Not exact as we zip the files, still ....
  space_req=$(du -sk $HOME | awk '{print $1}')
  space_avl=$(df -k / | awk '{if (NR>1) print $4}')
  let "diff = $space_avl - $space_req"
  [ $diff -le 0 ] &&  error_exit "echo ERROR. Not enough space left on / partition, skip" 2
}

function prepare_backup
{
  # Prepare the backup
  bupfile=/tmp/backup_${LOGNAME}_$(hostname)_$(date "+%d_%m_%y").tgz
  cd $HOME || error_exit "Cannot change directory! Aborting"
  tar -c -z -h --file=$bupfile --ignore-failed-read --exclude="*.root" ./
  [ $? -ne 0 ] && errot_exit "echo ERROR. Backup could not be created" 2
}

function backup 
{
  # Copy over to Castor
  rfcp $bupfile /castor/cern.ch/cms/testbeam/TAC/backup/$(basename $bupfile)
  status=$?
  rm -f $bupfile
  return $status
}

# functions ready

check_space
prepare_backup
backup
status=$?
echo Finished at `date` with status=$status
echo ----
exit $status
