#!/bin/sh

if [ $# -lt 1 ]; then
  echo Usage: $0 data_disk [Det]
  echo Example $0 /data3 [TIF]
  exit 1
fi
PARTITION=$1

DETECTOR=TIB
[ $# -gt 1 ] && DETECTOR=$2

perl -w $HOME/scripts/copy_edm_to_castor_new.pl $PARTITION $DETECTOR
perl -w $HOME/scripts/runFiles_new.pl $PARTITION $DETECTOR

exit 0
