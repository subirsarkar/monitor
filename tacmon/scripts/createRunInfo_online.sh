#!/bin/sh

set -o nounset

perl -w $HOME/monitor/bin/createRunMap.pl /data*/EDMProcessed/*/fileMap.txt
perl -w $HOME/monitor/bin/createRunInfo.pl --force --nrun=3
exit $?
