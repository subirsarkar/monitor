condor_q -pool osg-gw-1.t2.ucsd.edu \
      -format "%d." ClusterId \
      -format "%d!" ProcId \
      -format "%d!" JobStatus \
      -format "%s!" Owner \
      -format "%s!" x509userproxysubject \
      -format "%s!" GlobalJobId \
      -format "%d!" QDate \
      -format "%s!" AccountingGroup \
      -format "%d\n" ProcId \
      -constraint 'jobstatus == 1 || jobstatus == 5' \
 -constraint 'SleepSlot =!= TRUE' -global

