#!/bin/bash
set -o nounset

# set -o errexit

# Find all the RU files that were last modified at least 30 mins ago,
# process them and create EDM files. Save the cfg file used for each 
# job in a separate directory. Save also the log of the cmsRun.

# Check if the file really needs to be processed. After processing
# a file add a suitable entry in the File catalog file
# Catalog entry code: 0 - not processed/failed
#                     1 - processing started 
#                     2 - finished successfully
#
# Version 1.0 - Subir Sarkar, 15/02/2007
# Version 1.1 - Subir 19/02/2007 - takes care of StorageManager .dat files also


# Initialise
if [ $# -lt 1 ]; then
  echo Usage: $0 data_disk [Det] 
  echo Example $0 /data3 [TIB]
  exit 1
fi
PARTITION=$1

DETECTOR=TIB
if [ $# -gt 1 ]; then DETECTOR=$2; fi

inputDir=$PARTITION/$DETECTOR
baseDir=$PARTITION/EDMProcessed/$DETECTOR
test -d $inputDir || exit 1
test -d $baseDir || exit 1

# These directories are created by hand
lockDir=$baseDir/lock
cfgDir=$baseDir/cfg
logDir=$baseDir/log

fpCatalog=$baseDir/fileProcessed.txt
fpMap=$baseDir/fileMap.txt

dirtag=edm
let "minago = 30"
let "nday = 3"

let "DEBUG = 0"

declare -a fileList  # The variable will be treated as an array

function getOutputFile() {
  iFile=$1
  type=$2
  oFile=""
  if [ "$type" == "RU" ]; then
    oFile=$(echo $iFile | sed -e "s#RU#EDM#")
  elif [ "$type" == "SM" ]; then
    oFile=$(echo $iFile | sed -e "s#\.dat#\.root#")
    #Stick to the old way
    ##oFile=$(perl -w $HOME/scripts/transform.pl $iFile)
  fi
  eval "$3=$oFile"
}

function getPattern() {
  type=$1
  pattern=""
  if [ "$type" == "RU" ]; then
    pattern='RU*.root'
  elif [ "$type" == "SM" ]; then
    pattern='*StorageManager*.dat'
  fi
  eval "$2=$pattern"
}

function getExtension() {
  filename=$1
  ext=`echo $filename | awk -F\. '{print $NF}'`
  eval "$2=$ext"
}

# Find new files
function getNewFiles() 
{
  if [ $# -lt 2 ]; then echo getNewFiles: too few input arguments; exit 1; fi
  type=$1

  local pattern=""
  getPattern $type pattern

  declare -i n=0
  local inputFile
  for inputFile in $(find $inputDir -mmin +$minago -type f -name $pattern -print)
  do
    local iFile=$(basename $inputFile) 
    local oFile=""
    getOutputFile $iFile $type oFile
    if [ "$oFile" == "" ]; then continue; fi
 
    # Check if the file has already been processed
    local pFlag=$(cat $fpCatalog | grep $oFile | awk '{print $NF}')
    if [ "$pFlag" != "" ] && [ "$pFlag" != "0" ]; then 
      continue
    fi

    # Drop a lock file
    local lockFile=$lockDir/$(echo $oFile | sed -e "s#.root#.lock#")
    if [ -e "$lockFile" ]; then
      if [ $DEBUG -gt 0 ]; then echo Strange, $lockFile exists!, skipping the file; fi
      continue
    fi

    # Fill the global array with recently produced, fully specified RU file names
    fileList[$n]=$inputFile
    let "n += 1"
  done

  eval "$2=$n"
}

# Get the directory where the current bunch of EDM files to go
# Presently, we create a new directory every week, provided
# there are new RU Files
function getDir ()
{
  # Decide if a new directory needs to be created; if so create it
  local createDir=0

  # We use the long listing to make sure that we really get hold of a directory
  local recentDir=$(ls -ltr $baseDir/ | grep $dirtag | grep "^d" | tail -1 | awk '{print $NF}')
  if [ "$recentDir" == "" ]; then
    createDir=1
  else
    today=$(date "+%s")
    dstr=$(echo $recentDir | sed -e "s#${dirtag}_##" -e "s#_#-#g")
    d=$(date --date $dstr "+%s")
    let "today -= $d"
    let "today /= 86400"
    if [ $today -gt $nday ]; then createDir=1; fi
  fi

  ndir=""
  if [ $createDir -gt 0 ]; then
    ndir=$baseDir/${dirtag}_$(date "+%Y_%m_%d")
    mkdir -p $ndir
  else
    ndir=$baseDir/$recentDir
  fi

  eval "$1=$ndir"
}

# Setup the environment
function setCMS() 
{
  type=$1
  CMSSW=CMSSW_1_2_0_pre2
  if [ "$type" == "SM" ]; then  
    CMSSW=CMSSW_1_1_0
  fi 
    
  echo CMS Software Environment: $CMSSW
  cd /analysis/sw/StandardAnalysisRelease_DG/$CMSSW/src/
  eval $(scramv1 runtime -sh)
  status=$?
  export CORAL_AUTH_PATH=$HOME/DB/conddb
  cd $baseDir             ###cd -

  return $status
}

# Do the RU->EDM conversion
function processFiles() 
{
  local outputDir=$1  
  local type=$2
  local nFiles=$3
  local FTAG=${type}toEDM

  for i in `seq 0 $nFiles`
  do
    local inputFile=${fileList[$i]}
    echo Processing $inputFile, index=$i

    local iFile=$(basename $inputFile) 
    oFile=""
    getOutputFile $iFile $type oFile
    if [ "$oFile" == "" ]; then continue; fi
    local outputFile=$outputDir/$oFile
  
    # Check if the file has already been processed
    local pFlag=$(cat $fpCatalog | grep $oFile | awk '{print $NF}')
    if [ "$pFlag" == "1" ] || [ "$pFlag" == "2" ]; then
      if [ $DEBUG -gt 0 ]; then echo == $inputFile already processed or being processed!; fi
      continue
    fi
  
    # Add the entry to the File Catalog before processing start [code=1]
    if [ "$pFlag" == "" ]; then
      echo "$outputFile  1" >> $fpCatalog
    elif [ "$pFlag" == "0" ]; then
      perl -pi.bak -e "s#$outputFile  0#$outputFile  1#" $fpCatalog
    fi

    # Drop a lock file
    local lockFile=$lockDir/$(echo $oFile | sed -e "s#.root#.lock#")
    if [ -e "$lockFile" ]; then
      if [ $DEBUG -gt 0 ]; then echo Strange! $lockFile should not already exist, skipping the file; fi
      continue
    fi
    touch $lockFile
  
    local cfgFile=$cfgDir/${FTAG}_$(echo $oFile | sed -e "s#.root#.cfg#")
    sed -e "s#insert_${type}file#$inputFile#" \
        -e "s#insert_EDMfile#$outputFile#" \
          $HOME/scripts/template_$FTAG.cfg > $cfgFile
  
    local logFile=$logDir/${FTAG}_$(echo $oFile | sed -e "s#.root#.log#")
    if [ $DEBUG -gt 0 ]; then
      echo $inputFile 
      echo $outputFile
      echo $cfgFile
      echo $logFile
      echo $lockFile
    fi 
  
    # Ready to go
    echo cmsRun $cfgFile
    cmsRun $cfgFile > $logFile 2>&1
    status=$?
    if [ $status -eq 0 ]; then code=2; else code=0; fi
    perl -pi.bak -e "s#$outputFile  1#$outputFile  $code#" $fpCatalog
    if [ $status -eq 0 ]; then
      echo $inputFile $outputFile >> $fpMap     
    fi

    # Remove the lock 
    rm -f $lockFile
  done

  return
}

# Function defitions are over, the main
if [ ! -e $fpCatalog ]; then touch $fpCatalog; fi
if [ ! -e $fpMap ]; then touch $fpMap; fi

for type in `echo RU SM`
do
  echo INFO. Processing TYPE $type
  let "nFiles = 0"
  getNewFiles $type nFiles
  if [ $nFiles -lt 1 ]; then echo INFO. No new $type files found; continue; fi
  echo INFO. Num of files to be processed: $nFiles

  # Well, there are recent files to be processed
  # Set/create the EDM output dir; unnecessarily executed twice!!
  theDir=""
  getDir theDir
  if [ "$theDir" == "" ]; then echo ERROR. Destination directory not set; continue; fi
 
  echo Destination Directory: $theDir

  # Set up analysis environment
  setCMS $type
  if [ $? -ne 0 ]; then echo ERROR. CMS software environment not set; continue; fi

  # Now process the recent files
  let "nFiles -= 1"
  processFiles $theDir $type $nFiles
done

exit 0
