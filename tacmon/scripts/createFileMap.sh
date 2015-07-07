#!/bin/sh

set -o nounset

if [ $# -lt 2 ]; then echo Usage: $0 disk det; exit 1; fi

disk=$1
det=$2
inputFile=$disk/EDMProcessed/$det/fileProcessed.txt
for eFile in $(cat $inputFile | awk '{print $1}') 
do 
  bname=$(basename $eFile)
  oName=""
  if echo $bname | grep '^EDM' > /dev/null
  then
    oName=$(echo $bname | sed -e 's#^EDM#RU#')
  else
    oName=$(echo $bname | sed -e 's#root$#dat#')
  fi 
  rFile=$(find $disk/$det -name $oName -type f -print)
  if [ "$rFile" == "" ]; then 
    rFile=$disk/$det/run/$oName
  fi
  echo $eFile $rFile
done

exit 0
