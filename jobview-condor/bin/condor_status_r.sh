condor_status -pool  osg-gw-1.t2.ucsd.edu \
       -format "%s!" GlobalJobId \
       -format "%d!" TotalJobRunTime \
       -format "%.3f\n" TotalCondorLoadAvg \
       -constraint 'State=="Claimed" && Activity=="Busy"' \
 -constraint 'iam_sleep_slot==0'

