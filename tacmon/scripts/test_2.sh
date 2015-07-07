cd /analysis/sw/StandardAnalysisRelease_DG/CMSSW_1_1_0/src/
eval $(scramv1 runtime -sh)
export CORAL_AUTH_PATH=/home/cmstac/DB/conddb
cd -
cmsRun /data2/EDMProcessed/TEC/cfg/SMtoEDM_tif.00002492.A.testStorageManager_0.1.cfg
