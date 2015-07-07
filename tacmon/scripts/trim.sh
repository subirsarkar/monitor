#!/bin/sh
set -o nounset

# Remove old .root and .dat files from a volume. These files should 
# already exist on Castor. Optionally, skip content of some 
# directories hardcoded, as well as files listed in keepFile.list in the
# respective directories
#
# v0.7 12/02/2007 - Subir 
# v1.0 05/03/2007 - Removes the SM .dat files also. It is recommended that we
#                   do not use the .dat extension for other useful files to be
#                   retained. keepFile.dat changed to keepFile.list 

export STAGE_HOST=castorcms
export RFIO_USE_CASTOR_V2='YES'

PROGNAME=$(basename $0)

function usage
{
  cat <<EOF
Usage: $0 volume <options>
where options are:
  -a|--age        File age (D=30 days)
  -l|--limit      Trigger clean-up beyond the limit (D=80%)
  -v|--verbose    Turn on debug statements (D=false)
  -d|--dryrun     Show which files will be removed but do not take the action (D=false)
  -h|--help       This message

  example: $0 /data3 --age 10 --limit 70 --dryrun
EOF

  exit 1
}

[ $# -gt 0 ] || usage

# Initialise, get the disk name
partition=$1
shift

let "ndays = 30"
let "disklim = 80"
let "verbose = 0"
let "dryrun = 0"
while [ $# -gt 0 ]; do
    case $1 in
        -a | --age )            shift
                                let "ndays = $1"
                                ;;
        -l | --limit )          shift
                                let "disklim = $1"
                                ;;
        -v | --verbose )        let "verbose = 1"
                                ;;
        -d | --dryrun )         let "dryrun = 1"
                                ;;
        -h | --help )           usage
                                ;;
        * )                     usage
                                ;;
    esac
    shift
done

function do_next
{
  #-------------------------------------------------
  # Function for exit due to fatal program error
  # Accepts 1 argument:
  #   1. string containing descriptive error message
  #-------------------------------------------------
  [ $verbose -gt 0 ] && echo "${PROGNAME}: ${1:-"Unknown Reason"}, skipping." 1>&2
  continue
}

DIRTOSKIP=(
$partition/EDMProcessed/TIB/dbs
$partition/EDMProcessed/TIBTOB/dbs
$partition/EDMProcessed/TOB/dbs
$partition/EDMProcessed/TEC/dbs
)
ndir=${#DIRTOSKIP[@]}
let "ndir -= 1"

filekeeper="keepFile.list"
let "GB2BY = 1024**3"

# Check the overall usage
usage=$(df $partition | tail -1 | awk '{print substr($5,1,length($5)-1)}')
if [ "$usage" -lt "$disklim" ]; then
  printf "INFO. No need to remove old files from %s, disk usage = %d%% [reqd. %d%%]" \
     $partition $usage $disklim
  exit 2
fi

echo ----------------------------------
echo - Remove files \>= $ndays days old
echo - $(date '+%F %T')
echo ----------------------------------

let "xt = $ndays*24*60"
let "recvol = 0"
printf "The following files will be deleted (file size in bytes)\n"
for file in $(find $partition -mmin +$xt -type f -print)
do
  [ $verbose -gt 0 ] && echo Processing $file
  # Skip if not a Root file
  # Check the filename extension
  ext=$(basename $file | awk -F\. '{print $NF}')
  if [[ ( "$ext" != "root" ) && ( "$ext" != "dat" ) ]]; then 
    [ $verbose -gt 0 ] && echo INFO. Not a file of interest: $file, ext=$ext
    continue 
  fi

  # Check Filetype
  file $file | grep -e 'ROOT file' -e 'SVR2 pure executable' > /dev/null
  [ $? -eq 0 ] || do_next "$LINENO. Not a Root file by file type: $file"

  # Skip relevant files 
  dir=$(dirname $file)
  let "toskip = 0"
  for i in $(seq 0 $ndir)
  do
    if [ "$dir" == "${DIRTOSKIP[$i]}" ]; then 
      let "toskip = 1"
      break
    fi
  done
  [ $toskip -eq 1 ] && continue

  # Retain files irrespective of the timestamp if they are
  # listed in 'keepFile.list' in respective directories
  # DON'T try an exact match (grep -x)
  if [ -e $dir/$filekeeper ]; then 
    if cat $dir/$filekeeper | grep $file > /dev/null 
    then 
      [ $verbose -gt 0 ] && echo skipping $file
      continue
    fi
  fi

  # Now check the file status in Castor before removing
  # If the local file is newer that the one in Castor or if the size is different
  # do not remove
  castordir=/castor/cern.ch/cms/testbeam/TAC
  baseDir=$partition
  if echo $dir | grep "$partition/EDMProcessed" > /dev/null
  then
    castordir=/castor/cern.ch/cms/store/TAC
    baseDir=$partition/EDMProcessed
  fi
  castorfile=$(echo $file | sed -e s#$baseDir#$castordir#)
  [ $verbose -gt 0 ] && echo $file, $castorfile

  rfstat $castorfile > /dev/null 2>&1
  [ $? -eq 0 ] || do_next "$LINENO. $castorfile not found on Castor"

  # if the file on tape?
  nsls -l $castorfile | grep '^mrw' > /dev/null 2>&1
  [ $? -eq 0 ] || do_next "$LINENO. $file is being migrated to tape on Castor!"

  csize=$(rfdir $file 2>/dev/null | awk '{print $5}')    # File size on Castor
  [ $? -eq 0 ] || continue

  lsize=$(stat -c%s $file 2>/dev/null)                   # file size locally
  [ $? -eq 0 ] || continue

  let "diff = $csize - $lsize"
  if [ $diff -ne 0 ]; then
    if [ $verbose -gt 0 ]; then
      echo INFO. Castor File does to agree with the local fine in size, skipping ...
      echo INFO. Local  file: $file, size: $lsize
      echo INFO. Castor file: $castorfile, size: $csize
    fi
    continue
  fi 

  # Now calculate how much we would recover after the clean-up
  let "recvol += $lsize"

  # Mark the file
  timestamp=$(ls -l --time-style="+%Y%m%d-%T" $file | awk '{print $6}')
  printf "%15s%20s %s\n" $lsize $timestamp $file 
  
  # All set to remove
  [ $dryrun -gt 0 ] && continue
  rm -f $file
done

let "recvol /= $GB2BY"
echo Space Recovered: $recvol GB

exit 0
