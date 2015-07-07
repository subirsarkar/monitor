#!/bin/sh

det=$1
run=$2
export X509_USER_PROXY=/home/cmstac/cert/proxy.cert
source /afs/cern.ch/cms/LCG/LCG-2/UI/cms_ui_env.sh
export PYTHONPATH=$PYTHONPATH:/data1/Registration/DBS/Clients/PythonAPI
source /afs/cern.ch/cms/LCG/DLS/dls-client.sh
python /home/cmstac/scripts/InspectDBSDLS.py \
  --datasetPath=/TAC-$det-120-DAQ-EDM/RAW/CMSSW_1_2_0-RAW-Run-000$run \
  --DBSAddress=MCGlobal/Writer \
  --DBSURL=http://cmsdbs.cern.ch/cms/prod/comp/DBS/CGIServer/prodquery \
  --DLSAddress=prod-lfc-cms-central.cern.ch/grid/cms/DLS/LFC \
  --DLSType=DLS_TYPE_LFC 
#  --SE=cmsdcache.pi.infn.it
  
