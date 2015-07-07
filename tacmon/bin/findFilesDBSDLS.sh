#!/bin/sh

dset=$1
export X509_USER_PROXY=/home/cmstac/cert/proxy.cert
source /afs/cern.ch/cms/LCG/LCG-2/UI/cms_ui_env.sh
export PYTHONPATH=$PYTHONPATH:/data1/Registration/DBS/Clients/PythonAPI
source /afs/cern.ch/cms/LCG/DLS/dls-client.sh
python /home/cmstac/scripts/InspectDBSDLS.py \
  --datasetPath=$dset \
  --DBSAddress=MCGlobal/Writer \
  --DBSURL=http://cmsdbs.cern.ch/cms/prod/comp/DBS/CGIServer/prodquery \
  --DLSAddress=prod-lfc-cms-central.cern.ch/grid/cms/DLS/LFC \
  --DLSType=DLS_TYPE_LFC 
#  --SE=cmsdcache.pi.infn.it
#  --datasetPath=/TAC-*-120-DAQ-EDM/$typ/CMSSW_1_2_0-RAW-Run-*$run \
  
