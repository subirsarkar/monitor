#!/bin/sh

typ=$1
run=$2

export PYTHONPATH=$PYTHONPATH:/data1/Registration/DBS/Clients/PythonAPI
python /home/cmstac/scripts/InspectDBS.py \
      --url=http://cmsdbs.cern.ch/cms/prod/comp/DBS/CGIServer/prodquery \
      --datasetPath=/TAC-*-120-DAQ-EDM/$typ/CMSSW_1_2_0-RAW-Run-*$run \
      --instance=MCGlobal/Writer --full
