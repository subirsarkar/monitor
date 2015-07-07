#!/bin/sh

set -o nounset

# Get the directory where the current bunch of EDM files to go
# Presently, we create a new directory every week, provided
# there are new RU Files
function getDirByDate
{
  baseDir=$1
  local dirtag="edm"
  let "nday = 3"
  let "verbose = 1"
  # Decide if a new directory needs to be created; if so create it
  declare -i createDir=0

  # We use the long listing to make sure that we really get hold of a directory
  local recentDir=$(ls -ltr $baseDir/ | grep $dirtag | grep "^d" | tail -1 | awk '{print $NF}')
  echo $recentDir
  if [ "$recentDir" == "" ]; then
    let "createDir = 1"
  else
    today=$(date "+%s")
    dstr=$(echo $recentDir | sed -e "s#${dirtag}_##" -e "s#_#-#g")
    d=$(date --date=$dstr "+%s")
    let "today -= $d"
    let "today /= 86400"
    [ $verbose -gt 0 ] && echo Difference: ${today}\+ days
    [ $today -gt $nday ] && let "createDir = 1"
  fi

  ndir=""
  if [ $createDir -gt 0 ]; then
    ndir=$baseDir/${dirtag}_$(date "+%Y_%m_%d")
  else
    ndir=$baseDir/$recentDir
  fi

  eval "$2=$ndir"
}


dir=
getDirByDate /data3/EDMProcessed/TIB dir
echo $dir
