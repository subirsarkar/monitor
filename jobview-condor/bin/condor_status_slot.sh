#!/bin/bash
set -o nounset
condor_status -pool osg-gw-1.t2.ucsd.edu \
    -format "%s!" Name \
    -format "%s!" State \
    -format "%s!" GlobalJobId \
    -format "%d!" TotalMemory \
    -format "%f!" TotalLoadAvg \
    -format "%d\n" MyCurrentTime \
    -constraint 'State != "Owner"' \
 -constraint 'iam_sleep_slot==0'
