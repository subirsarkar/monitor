#!/bin/bash
set -o nounset

# set -o errexit

# Find all the RU files that were last modified at least 30 mins ago,
# process them and create EDM files. Save the cfg file used
# for each job in a separate directory. Save also the log
# of the cmsRun.

# Once should not process the same file more than once.
# Before processing check if the file really needs to
# be processed. After processing
# a file add a suitable entry in the File catalog file
# Catalog entry code: 0 - not processed/failed
#                     1 - processing started 
#                     2 - finished successfully
#
# Version 1.0 - Subir Sarkar, 08/12/2006

# Initialise
DETECTOR=$1
test -z $DETECTOR && DETECTOR=TIB
test -d /data2/$DETECTOR || exit 1
test -d /data2/EDMProcessed/$DETECTOR || exit 1

DEBUG=0
inputDir=/data2/$DETECTOR
baseDir=/data2/EDMProcessed/$DETECTOR
lockDir=$baseDir/lock
cfgDir=$baseDir/cfg
logDir=$baseDir/log
fpCatalog=$baseDir/fileProcessed.txt
minago=30
dirtag=edm
nday=7

#declare -a fileList  # The variable will be treated as an array
fileList=""
pippo=""
# Find new files
function getNewFiles() 
{
  declare -i n=0
  local inputFile
  for inputFile in $(find $inputDir -mmin +$minago -type f -name 'RU*.root' -print )
  do
    local iFile=$(basename $inputFile) 
    local oFile=$(echo $iFile | sed -e "s#RU#EDM#")

    # Check if the file has already been processed
    local pFlag=$(cat $fpCatalog | grep $oFile | awk '{print $NF}')
    if [ "$pFlag" != "" ] && [ "$pFlag" != "0" ]; then 
      continue
    fi

    # Drop a lock file
    local lockFile=$lockDir/$(echo $oFile | sed -e "s#.root#.lock#")
    if [ -e $lockFile ]; then
#      echo Strange, $lockFile exist!, skipping the file
      continue
    fi

    # Fill the global array with recently produced, fully specified RU file names
#    echo OOO ADD $inputFile OOO
    fileList=${fileList}" "${inputFile}
    let "n+=1"
  done
  echo $fileList
#echo $n

  return
}

# Get the directory where the current bunch of EDM files to go
# Presently, we create a new directory every week, provided
# there are new RU Files
function getDir () 
{
  # Decide if a new directory needs to be created; if so create it
  local createDir=0
  local recentDir=$(ls -1tr $baseDir/ | grep $dirtag | grep "^d" | tail -1)
  if [ "$recentDir" == "" ]; then
    createDir=1
  else
    today=$(date "+%d")
    d=$(echo $recentDir | awk -F_ '{print $NF}')
    let "today-=$d"
    if [ "$today" -gt $nday ]; then createDir=1; fi
  fi

  local ndir
  if [ "$createDir" -gt 0 ]; then
    ndir=$baseDir/${dirtag}_$(date "+%Y_%m_%d")
    mkdir -p $ndir
  else
    ndir=$baseDir/$recentDir
  fi
  echo $ndir

  return
}

# Setup the environment
function setCMS() 
{
  cd /analysis/sw/StandardAnalysisRelease_DG/CMSSW_1_2_0_pre2/src/
  eval $(scramv1 runtime -sh)
  export CORAL_AUTH_PATH=/home/cmstac/DB/conddb
  cd -

  return
}

# Do the RU->EDM conversion
function processFiles() 
{
  local outputDir=$1
  local inputFile
  for inputFile in $(echo $pippo)
  do
    echo Processing $inputFile
    #
    local iFile=$(basename $inputFile) 
    local oFile=$(echo $iFile | sed -e "s#RU#EDM#")
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
    if [ -e $lockFile ]; then
      echo Strange! $lockFile should not already exist, skipping the file
      continue
    fi
    touch $lockFile
  
    local cfgFile=$cfgDir/RUtoEDM_$(echo $iFile | sed -e "s#.root#.cfg#")
    sed -e "s#insert_RUfile#$inputFile#" \
        -e "s#insert_EDMfile#$outputFile#" \
          $HOME/scripts/template_RUtoEDM.cfg > $cfgFile
  
    local logFile=$logDir/RUtoEDM_$(echo $iFile | sed -e "s#.root#.log#")
    if [ $DEBUG -gt 0 ]; then
      echo $inputFile 
      echo $outputFile
      echo $cfgFile
      echo $logFile
      echo $lockFile
    fi 
  
    # Ready to go
    echo cmsRun $cfgFile
    time cmsRun $cfgFile | tee $logFile
    if [ $? -eq 0 ]; then code=2; else code=0; fi
    echo ECCO $outputFile $code
    echo ECCO2    perl -pi.bak -e "s#$outputFile  1#$outputFile  $code#" $fpCatalog
    perl -pi.bak -e "s#$outputFile  1#$outputFile  $code#" $fpCatalog
  
    # Remove the lock 
    rm -f $lockFile
  done

  return

}

# Function defitions are over, the main
if [ ! -e $fpCatalog ]; then touch $fpCatalog; fi

#  for pippo in $(find $inputDir -mmin +$minago -type f -name 'RU*.root' -print)
#  do
#    echo $pippo
#  done


pippo=$(getNewFiles)
#if [ $n -lt 1 ]; then echo INFO. No new files found; exit 1; fi
#echo Files: $n

# Well, there are recent files to be processed
# Set/create the EDM output dir
dir=$(getDir)

#echo DIR: $dir

# Set up analysis environment
setCMS

# Now process the recent files
#echo N: $n
echo DIR: $dir
echo FILELIST: $fileList
echo pippo $pippo
processFiles $dir

exit 0
