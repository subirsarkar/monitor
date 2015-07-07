#!/bin/sh

set -o nounset

CASTORDIR=/castor/cern.ch/cms/testbeam/TAC
for path in $(echo TEC/run TEC/RUN TIB/run TIBTOB TIBTOB/run TIF TOB TOB/run)
do
  dir=$CASTORDIR/$path
  rfdir $dir | grep -e 'RU' -e 'StorageManager' | grep -e '.dat' -e '.root' \
      | awk -v ss="$dir" '{$NF=ss"/"$NF;print $0}'
done

exit
