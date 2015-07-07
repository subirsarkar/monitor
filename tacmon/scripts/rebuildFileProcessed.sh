#!/bin/sh

set -o nounset

DET=$1
mapFile=fileMap.txt
for cfgfile in $(ls -tr1 cfg/*.cfg)
do
  lines=($(grep -e 'EDMProcessed' -e "$DET" $cfgfile | awk '{print $NF}' | sed -e 's/"//g' -e 's/}//' -e 's/file://'))
  n=${#lines[*]}
  [ $n -gt 0 ] || continue
  if [ $n -eq 2 ]; then 
    echo ${lines[1]} ${lines[0]}
  else
    r=$(cat $mapFile | grep ${lines[0]} | awk '{print $NF}' | sort -u)
    [ "$r" != "" ] && echo ${lines[0]} $r
  fi
done

exit 0
