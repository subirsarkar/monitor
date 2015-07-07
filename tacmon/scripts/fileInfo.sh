#!/bin/sh

#set -o nounset

filename=$1
[ -e $filename ] || exit 1

function error_exit
{
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit ${2:-1}
}

cd $HOME/Registration/CMSSW_1_2_3/src
eval $(scramv1 runtime -sh) 
cd -

let "size = -1"
let "nevt = 0"
guid='?'
result=$(EdmFileUtil -u file:$filename | grep -e 'events' -e 'UUID' 2>/dev/null)

if echo $result | grep 'events' > /dev/null
then
  nevt=$(echo $result | awk '{print $3}')
  size=$(echo $result | awk '{print $5}')
fi

if echo $result | grep 'events' > /dev/null
then
  guid=$(echo $result | awk '{print $NF}')
fi

csum=$(cksum $filename 2>/dev/null | awk '{print $1}')

printf "%s %d %d %d %s\n" $filename $size $nevt $csum $guid
exit 0
