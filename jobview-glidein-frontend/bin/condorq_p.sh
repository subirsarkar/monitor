condor_q -pool glidein-collector.t2.ucsd.edu \
      -format "ClusterId:=%d!" ClusterId \
      -format "ProcId:=%d!" ProcId \
      -format "JobStatus:=%d!" JobStatus \
      -format "Owner:=%s!" Owner \
      -format "GlobalJobId:=%s!" GlobalJobId \
      -format "QDate:=%d!" QDate \
      -format "AccountingGroup:=%V!" AccountingGroup \
      -format "x509UserProxyFQAN:=%V!" x509UserProxyFQAN \
      -format "x509userproxysubject:=%V!" x509userproxysubject \
      -format "MATCH_GLIDEIN_Gatekeeper:=%V\n" MATCH_GLIDEIN_Gatekeeper \
      -constraint 'jobstatus == 1 || jobstatus == 5' \
 -global

