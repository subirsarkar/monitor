#!/bin/sh

set -o nounset

perl -w $HOME/monitor/bin/createRunInfo.pl --force --nrun=20 --skip=3
exit $?
