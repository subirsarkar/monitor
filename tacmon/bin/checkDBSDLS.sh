#!/bin/sh
# set -o nounset

DEBUG=0
[ $# -gt 0 ] || exit 1
run=$1

type="RECO"
[ $# -gt 1 ] && type=$2

if [ "$type" == "RECO" ]; then
  dset=/TAC-*-120-DAQ-EDM/RECO/CMSSW_*-DIGI-RECO-Run-*$run*
else
  dset=/TAC-*-120-DAQ-EDM/RAW/CMSSW_*-RAW-Run-*$run*
fi

export X509_USER_PROXY=/home/cmstac/cert/proxy.cert
source /afs/cern.ch/cms/LCG/LCG-2/UI/cms_ui_env.sh > /dev/null 2>&1
source /afs/cern.ch/cms/LCG/DLS/dls-client.sh 
export PYTHONPATH=$PYTHONPATH:/data1/Registration/DBS/Clients/PythonAPI

[ $DEBUG -gt 0 ] && echo dataset=$dset
python /home/cmstac/monitor/bin/InspectDBSDLS.py \
      --datasetPath=$dset \
      --DBSAddress=MCGlobal/Writer \
      --DBSURL=http://cmsdbs.cern.ch/cms/prod/comp/DBS/CGIServer/prodquery \
      --DLSAddress=prod-lfc-cms-central.cern.ch/grid/cms/DLS/LFC \
      --DLSType=DLS_TYPE_LFC 
#  --SE=cmsdcache.pi.infn.it

python /home/cmstac/monitor/bin/InspectDBS.py \
      --url=http://cmsdbs.cern.ch/cms/prod/comp/DBS/CGIServer/prodquery \
      --datasetPath=$dset \
      --instance=MCGlobal/Writer \
      --full

exit 0
