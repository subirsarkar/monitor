#!/bin/sh

DET=$1
test -z $DET && DET=TIB
perl -w $HOME/scripts/copy_edm_to_castor.pl $DET
perl -w $HOME/scripts/runFiles.pl $DET

exit 0
