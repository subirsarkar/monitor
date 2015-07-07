#!/bin/sh

set -o nounset

let "nday = 3"
dirtag=edm

# Get the directory where the current bunch of EDM files to go
# Presently, we create a new directory every week, provided
# there are new RU Files
function getDir ()
{
  baseDir=$1
  # Decide if a new directory needs to be created; if so create it
  local createDir=0
  local recentDir=$(ls -ltr $baseDir/ | grep $dirtag | grep "^d" | tail -1 | awk '{print $NF}')
  echo $recentDir

  if [ "$recentDir" == "" ]; then
    createDir=1
  else
    today=$(date "+%s")
    dstr=$(echo $recentDir | sed -e "s#${dirtag}_##" -e "s#_#-#g")
    echo $dstr
    d=$(date --date="$dstr" "+%s")
    echo Before subtraction: $today, $d
    let "today -= $d"
    echo After subtraction: $today seconds
    let "today /= 86400"
    echo Difference: ${today}\+ days

    if [ $today -gt $nday ]; then createDir=1; fi
  fi

  ndir=""
  if [ $createDir -gt 0 ]; then
    ndir=$baseDir/${dirtag}_$(date "+%Y_%m_%d")
  else
    ndir=$baseDir/$recentDir
  fi

  eval "$2=$ndir"
}

dir=""
getDir /data3/EDMProcessed/TIB dir
echo $dir

