#!/bin/sh

#set -o nounset

filename=$1
if [ ! -e $filename ]; then 
  echo -1
  exit 1
fi
cd $HOME/Registration/CMSSW_1_2_3/src
eval $(scramv1 runtime -sh) 
#cd ../../
result=$(EdmFileUtil -u file:$filename | grep events 2>/dev/null)
if [ $? -eq 0 ]; then
  echo $result | awk '{print $3}'
else
  echo -1
fi

exit 0
