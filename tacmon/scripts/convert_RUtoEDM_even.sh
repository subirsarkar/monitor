#!/bin/sh

set -o nounset

# set -o errexit

# Find all the RU files that were last modified at least 30 mins ago,
# process them and create EDM files. Save the cfg file used for each 
# job in a separate directory. Save also the log of the cmsRun.
#
# Check if the file really needs to be processed. After processing
# a file add a suitable entry in the File catalog file
# Catalog entry code: 0 - not processed/failed
#                     1 - processing started 
#                     2 - finished successfully
#
# Version 1.0 - subir 15/02/2007 - first production version
# Version 1.1 - subir 19/02/2007 - takes care of StorageManager .dat files also
# Version 1.2 - subir 04/03/2007 - optionally process only even/odd runs
#

PROGNAME=$(basename $0)
function usage 
{
  cat <<EOF 
Usage: $0 volume <options>
where options are:
  -d|--detector   Detector  - Detector type that indicates the data area
                              Possible values [TIB (D), TOB, TIBTOB, TEC, TIF etc.]
  -f|--filter     Filter    - Select even/odd Run numbers (
                              Possible values [none(D), even, odd]
  -e|--edmopt     EDM File name convention for SM files
                              Possible values: 
                                 0: just replace .dat by .root (D), 
                              else: Similar to RU->EDM 
  -s|--style      Dir Style - Create new directories using Run number / Date string 
                              Possible values [bydate(D), byrun]
  -v|--verbose                Turn on debug statements (D=false)
  -h|--help       Help      - This message

  example: $0 /data3 --detector TIB --filter odd --style byrun
EOF

  exit 1
}

function error_exit
{
  #-------------------------------------------------
  # Function for exit due to fatal program error
  # Accepts 2 arguments:
  #   1. string containing descriptive error message
  #   2. exit code to be output
  #-------------------------------------------------
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit ${2:-1}
}
function do_next
{
  #-------------------------------------------------
  # Function for exit due to fatal program error
  # Accepts 1 argument:
  #   1. string containing descriptive error message
  #-------------------------------------------------
  local message=${1:-"Unknown Reason"}
  local debug=${2:-1}
  [ $debug -gt 0 ] && echo "${PROGNAME}: ${1:-"Unknown Reason"}, skipping." 1>&2
  continue
}

[ $# -gt 0 ] || usage

# Initialise, get the disk name
partition=$1
shift

# Now handle the options
detector="TIB"
filter="none"
let "edmopt = 0"
style="bydate"
let "verbose = 0"
while [ $# -gt 0 ]; do
    case $1 in
        -d | --detector )       shift
                                detector="$1"
                                ;;
        -f | --filter )         shift
                                filter="$1"
                                ;;
        -e | --edmopt )         shift
                                let "option = $1"
                                ;;
        -s | --style )          shift
                                style="$1"
                                ;;
        -v | --verbose )        let "verbose = 1"
                                ;;
        -h | --help )           usage
                                ;;
        * )                     usage
                                ;;
    esac
    shift
done

inputDir=$partition/$detector
[ -d "$inputDir" ] || error_exit "$LINENO. $inputDir does not exist." 1

baseDir=$partition/EDMProcessed/$detector
[ -d "$baseDir"  ] || error_exit "$LINENO. $baseDir does not exist" 1

# These directories are created by hand
lockDir=$baseDir/lock
[ -d "$lockDir" ] || mkdir $lockDir

cfgDir=$baseDir/cfg
[ -d "$cfgDir" ] || mkdir $cfgDir

logDir=$baseDir/log
[ -d "$logDir" ] || mkdir $logDir

bufferDir=$HOME/buffer
[ -d "$bufferDir" ] || mkdir $bufferDir

fpCatalog=$baseDir/fileProcessed.txt
fpMap=$baseDir/fileMap.txt
fpLock=$lockDir/fileAction.lock

declare -a fileList  # The variable will be treated as an array

function getOutputFile 
{
  local iFile=$1
  local type=$2
  local option=$3
  oFile=""
  if [ "$type" == "RU" ]; then
    oFile=$(echo $iFile | sed -e "s#RU#EDM#")
  elif [ "$type" == "SM" ]; then
    if [ $option -eq 0 ]; then
      # Stick to the old way
      oFile=$(echo $iFile | sed -e "s#\.dat#\.root#")
    else 
      oFile=$(perl -w $HOME/scripts/transform.pl $iFile)
    fi
  fi
  eval "$4=$oFile"
}

function getPattern 
{
  type=$1
  pattern=""
  if [ "$type" == "RU" ]; then
    pattern='RU*.root'
  elif [ "$type" == "SM" ]; then
    pattern='*StorageManager*.dat'
  fi
  eval "$2=$pattern"
}

function getRun 
{
  filename=$1
  type=$2
  run=""
  if [ "$type" == "RU" ]; then
    run=$(echo $filename | perl -ne 'm/RU(\d+)(?:.*)/;printf "%d", $1')
  elif [ "$type" == "SM" ]; then
    run=$(echo $filename | perl -ne 'm/tif\.(\d+)\.A\.(?:.*)/;printf "%d", $1')
  fi
  eval "$3=$run"
}

function getExtension 
{
  filename=$1
  ext=$(echo $filename | awk -F\. '{print $NF}')
  eval "$2=$ext"
}

function getFlag {
  oFile=$1
  flag=
  d=
  count=$(cat $fpCatalog | grep $oFile | wc -l)
  if [ $count -gt 1 ]; then
    flag=$(cat $fpCatalog | grep $oFile | head -1 | awk '{if (NF>1) {print $NF} else {print ""}}')
    d=$(cat $fpCatalog | grep $oFile | head -1 | awk '{if (NF>0) {print $1} else {print ""}}')
  elif [ $count -eq 1 ]; then
    flag=$(cat $fpCatalog | grep $oFile | awk '{if (NF>1) {print $NF} else {print ""}}')
    d=$(cat $fpCatalog | grep $oFile | awk '{if (NF>0) {print $1} else {print ""}}')
  else
    flag=""
    d=""
  fi
  [ "$d" != "" ] && d=$(dirname $d)
  eval "$2=$flag"
  eval "$3=$d"
}

# Find new files
function getNewFiles 
{
  [ $# -gt 1 ] || error_exit "$LINENO. Too few input arguments to getNewFiles" 1
  type=$1

  let "minago = 30"
  local pattern=""
  getPattern $type pattern

  declare -i n=0
  local inputFile
                                                                                   # --no-run-if-empty
  for inputFile in $(find $inputDir -mmin +$minago -type f -name $pattern -print | xargs -r ls -1tr)
  do
    # A file can disappear just in time!
    [ -e $inputFile ] || continue

    # Skip if the file size is 0
    size=$(stat -c%s $inputFile)
    [ "$size" -gt 0 ] || continue

    local iFile=$(basename $inputFile) 

    # Keep even/odd runs
    if [ "$filter" != "none" ]; then
      # Decode the run number from the Filename
      local run
      getRun $iFile $type run

      let "run %= 2"
      if [ $run -gt 0 ]; then
        rt="odd"
      else
        rt="even"
      fi 
      [ "$rt" == "$filter" ] || continue
    fi

    # Construct output filename
    local oFile=""
    getOutputFile $iFile $type $edmopt oFile
    [ "$oFile" != "" ] || continue
 
    # Check if the file has already been processed
    local pFlag=""
    local dr=""
    getFlag $oFile pFlag dr
    [[ ( "$pFlag" != "" ) && ( "$pFlag" != "0" ) ]] && continue

    # Check if a lock file already exists
    local lockFile=$lockDir/$(echo $oFile | sed -e "s#.root#.lock#")
    [ ! -e "$lockFile" ] || do_next "$LINENO. $lockFile exists!" 1

    # Fill the global array with recently produced, fully specified RU file names
    fileList[$n]=$inputFile
    let "n += 1"
  done

  eval "$2=$n"
}

# Get the directory where the current bunch of EDM files to go
# Presently, we create a new directory every week, provided
# there are new RU Files
function getDirByDate 
{
  local dirtag="edm"
  let "nday = 3"

  # Decide if a new directory needs to be created; if so create it
  declare -i createDir=0

  # We use the long listing to make sure that we really get hold of a directory
  local recentDir=$(ls -ltr $baseDir/ | grep $dirtag | grep "^d" | tail -1 | awk '{print $NF}')
  if [ "$recentDir" == "" ]; then
    let "createDir = 1"
  else
    today=$(date "+%s")
    dstr=$(echo $recentDir | sed -e "s#${dirtag}_##" -e "s#_#-#g")
    d=$(date --date=$dstr "+%s")
    let "today -= $d"
    let "today /= 86400"
    [ $verbose -gt 0 ] && echo Difference: ${today}\+ days
    [ $today -gt $nday ] && let "createDir = 1"
  fi

  ndir=
  if [ $createDir -gt 0 ]; then
    ndir=$baseDir/${dirtag}_$(date "+%Y_%m_%d")
    mkdir -p $ndir
  else
    ndir=$baseDir/$recentDir
  fi

  eval "$1=$ndir"
}

# Get the directory where the current bunch of EDM files to go
# Presently, we create a new directory every week, provided
# there are new RU Files
function getDirByRun
{
  [ $# -gt 1 ] || error_exit "$LINENO. Too few input arguments to getDirByRun" 1
  run=$1
  let "maxfiles = 500"
  let "gb2kb = 1024*1024"
  let "maxsize = 500" # GB
  local dirtag="RUN"

  # Decide if a new directory needs to be created; if so create it
  let "createDir = 0"

  # We use the long listing to make sure that we really get hold of a directory
  local recentDir=$(ls -ltr $baseDir/ | grep $dirtag | grep "^d" | tail -1 | awk '{print $NF}')
  local reqDir=${dirtag}${run}
  [ $verbose -gt 0 ] && echo reqDir=$reqDir recentDir=$recentDir
  if [ "$recentDir" == "" ]; then
    let "createDir = 1"
  elif [ "$recentDir" != "$reqDir" ]; then
    local rdir=$baseDir/$recentDir
    nfiles=$(ls -1 $rdir 2> /dev/null | wc -l)
    dirsize=$(du -sk $rdir | awk '{print $1}')
    let "dirsize /= $gb2kb"
    [ $verbose -gt 0 ] && echo nfiles="$nfiles" dirsize="$dirsize"
    [[ ( "$nfiles" -gt $maxfiles ) || ( "$dirsize" -gt $maxsize ) ]] && let "createDir = 1"
  fi

  newdir=""
  if [ $createDir -gt 0 ]; then
    newdir=$baseDir/$reqDir
    mkdir -p $ndir
  else
    newdir=$baseDir/$recentDir
  fi

  eval "$2=$newdir"
}

# Setup the environment
function setCMS 
{
  type=$1
  #CMSSW="CMSSW_1_2_0_pre2"
  CMSSW="CMSSW_1_2_2"
  [ "$type" == "SM" ] && CMSSW="CMSSW_1_1_0"
    
  echo CMS Software Environment: $CMSSW
  cd /analysis/sw/StandardAnalysisRelease_DG/$CMSSW/src/ || error_exit "$LINENO. could not cd to sw directory." 3
  eval $(scramv1 runtime -sh)
  status=$?
  which cmsRun
  export CORAL_AUTH_PATH=$HOME/DB/conddb
  cd $baseDir || error_exit "$LINENO. could not cd to $baseDir." 3

  return $status
}

# Do the RU->EDM conversion
function processFiles 
{
  local outputDir=$1  
  local type=$2
  local nFiles=$3
  local FTAG=${type}toEDM

  for i in $(seq 0 $nFiles)
  do
    local inputFile=${fileList[$i]}
    # Can a file can disappear at this point. why not
    [ -e $inputFile ] || continue

    echo Processing $inputFile, index=$i \(of $nFiles\)

    local iFile=$(basename $inputFile) 
    local bufferFile=$bufferDir/$iFile

    oFile=""
    getOutputFile $iFile $type $edmopt oFile
    [ "$oFile" != "" ] || continue

    # Check if the file has already been processed
    local pFlag=""
    local dr=""
    getFlag $oFile pFlag dr
    [[ ( "$pFlag" == "1" ) || ( "$pFlag" == "2" ) ]] && \
      do_next "== $LINENO. $inputFile already processed or being processed!" $verbose

    # Construct output filename carefully
    local outputFile=$outputDir/$oFile
    [ "$pFlag" == "0" ] && outputFile=$dr/$oFile
  
    # Anchor a lock for fpCatalog
    while [ -e $fpLock ]; do
      echo $PROGNAME: $LINENO. Another process is updating $fpCatalog
      sleep 2
    done
    touch $fpLock

    # Add the entry to the File Catalog before processing start [code=1]
    if [ "$pFlag" == "" ]; then
      echo "$outputFile  1" >> $fpCatalog
    elif [ "$pFlag" == "0" ]; then
      perl -pi.bak -e "s#$outputFile  0#$outputFile  1#" $fpCatalog
    fi

    # Remove the lock against fpCatalog
    rm -f $fpLock

    # Drop a lock file
    local lockFile=$lockDir/$(echo $oFile | sed -e "s#.root#.lock#")
    [ ! -e "$lockFile" ] || do_next "$LINENO. $lockFile already exists!" 1
    touch $lockFile
  
    # Now copy the input file locally
    [ -e $bufferFile ] && rm -f $bufferFile
    cp $inputFile $bufferFile
    [ $? -eq 0 ] || do_next "$LINENO. Copy $inputFile to $bufferFile failed!" 1

    # Prepare the cfg File. Note. use the local copy for efficiency
    local cfgFile=$cfgDir/${FTAG}_$(echo $oFile | sed -e "s#.root#.cfg#")
    sed -e "s#insert_actual_${type}file#$inputFile#" \
        -e "s#insert_${type}file#$bufferFile#" \
        -e "s#insert_EDMfile#$outputFile#" \
          $HOME/scripts/template_$FTAG.cfg > $cfgFile
  
    local logFile=$logDir/${FTAG}_$(echo $oFile | sed -e "s#.root#.log#")
    [ $verbose -gt 0 ] && printf "%s\n%s\n%s\n%s\n%s\n%s\n" \
             $inputFile $bufferFile $outputFile $cfgFile $logFile $lockFile
  
    # Ready to go
    echo cmsRun $cfgFile
    cmsRun $cfgFile > $logFile 2>&1
    status=$?

    # Anchor a lock for fpCatalog; clearly not all that robust
    while [ -e $fpLock ]; do
      echo $PROGNAME: $LINENO. Another process is updating $fpCatalog
      sleep 2
    done
    touch $fpLock

    local code
    if [ $status -eq 0 ]; then 
      echo $outputFile $inputFile >> $fpMap     
      code=2 
    else 
      getFlag $oFile pFlag dir
      echo $LINENO. cmsRun failed, status=$status, pFlag=$pFlag, dir=$dir
      [ -e $outputFile ] && rm -f $outputFile
      code=0 
    fi
    perl -pi.bak -e "s#$outputFile  1#$outputFile  $code#" $fpCatalog

    # Remove the lock against fpCatalog
    rm -f $fpLock

    # Remove the local copy of the input file
    [ -e $bufferFile ] && rm -f $bufferFile

    # Remove the lock 
    [ -e $lockFile ] && rm -f $lockFile
  done

  return
}

# Function defitions are over, the main
[ -e "$fpCatalog" ] || touch $fpCatalog
[ -e "$fpMap" ]     || touch $fpMap

for type in $(echo RU SM)
do
  echo INFO. Processing TYPE $type
  let "nFiles = 0"
  getNewFiles $type nFiles
  [ $nFiles -gt 0 ] || do_next "$LINENO. No new $type files found" $verbose
  echo INFO. Number of files to be processed: $nFiles

  # Well, there are recent files to be processed
  # Set/create the EDM output dir; unnecessarily executed twice!!

  theDir=""
  if [ "$style" == "byrun" ]; then
    theRun=""
    getRun $fileList[0] $type theRun
    [ "$theRun" != "" ] || do_next "$LINENO. Run number empty!" 1
    getDirByRun $theRun theDir
  else
    getDirByDate theDir
  fi
  [ "$theDir" != "" ] || do_next "$LINENO. Destination directory not set" 1
  echo Destination Directory: $theDir

  # Set up analysis environment
  setCMS $type
  [ $? -eq 0 ] || do_next "$LINENO. CMS software environment not set" 1

  # Now process the recent files
  let "nFiles -= 1"
  processFiles $theDir $type $nFiles
done

exit 0
