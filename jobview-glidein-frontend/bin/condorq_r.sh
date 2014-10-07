condor_q -pool glidein-collector.t2.ucsd.edu -constraint 'jobstatus == 2' \
      -format "ClusterId:=%d!" ClusterId \
      -format "ProcId:=%d!" ProcId \
      -format "GlobalJobId:=%s!" GlobalJobId \
      -format "Owner:=%s!" Owner \
      -format "JobStatus:=%d!" JobStatus \
      -format "QDate:=%d!" QDate \
      -format "RemoteHost:=%V!" RemoteHost \
      -format "JobCurrentStartDate:=%V!" JobCurrentStartDate \
      -format "CompletionDate:=%V!" CompletionDate \
      -format "RemoteWallClockTime:=%V!" RemoteWallClockTime \
      -format "RemoteUserCpu:=%V!" RemoteUserCpu \
      -format "ImageSize_RAW:=%V!" ImageSize_RAW \
      -format "DiskUsage:=%V!" DiskUsage \
      -format "AccountingGroup:=%V!" AccountingGroup \
      -format "x509userproxysubject:=%V!" x509userproxysubject \
      -format "x509UserProxyFQAN:=%V!" x509UserProxyFQAN \
      -format "DESIRED_Gatekeepers:=%V\n" DESIRED_Gatekeepers \
      -format "ExitStatus:=%d!" ExitStatus \
      -format "Cmd:=%V!" Cmd \
      -format "EnteredCurrentStatus:=%d\n" EnteredCurrentStatus \
 -global
