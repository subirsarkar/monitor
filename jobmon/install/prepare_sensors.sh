#!/bin/sh
set -o nounset

# prepare the various bash scripts 
# v1.1 11/07/2009 - Subir

PROGNAME=$(basename $0)
DIRNAME=$(dirname $0)

source $DIRNAME/common.sh

function usage
{
  cat <<-EOF
Usage: $PROGNAME installtype <options>
installtype: ce,wn - must be specified

where options are:
  -b|--basedir       Base directory(D=/opt)
  -v|--verbose       Turn on debug statements (D=false)
  -h|--help          This message

  example: $PROGNAME wn --verbose
EOF

  exit 1
}

[ $# -gt 0 ] || usage

# Initialise, get the disk name
installtype=$1
shift

echo $installtype | grep "^-" >/dev/null
[ $? -gt 0 ] || usage

basedir=/opt
let "verbose = 0"
while [ $# -gt 0 ]; do
  case $1 in
    -b | --basedir )        shift
                            basedir=$1
                            ;;
    -v | --verbose )        let "verbose = 1"
                            ;;
    -h | --help )           usage
                            ;;
     * )                    usage
                            ;;
  esac
  shift
done

lrms=; parseConfig LRMS $basedir lrms

declare -a list
if [ "$installtype" == "wn" ]; then
  list=(nodesensor_daemon.sh)
elif [ "$installtype" == "ce" ]; then
  list=(gridinfoCache_daemon.sh jobinfoCache_daemon.sh jobsensor_daemon.sh)
fi 
# -----------------------------------------
# First create the scripts in the bin area
# ----------------------------------------
for script in ${list[*]}
do
  name=$(echo $script | awk -F\. '{print $1}')
  path=$basedir/jobmon/bin/$script
  cat > $path <<EOF
#!/bin/sh
#set -o nounset

# Update Perl library path
APPDIR=$basedir/jobmon
EOF

  # switch off parameter substitution
  cat >> $path <<'EOF'
export JOBMON_CONFIG_DIR=$APPDIR/etc/Collector
if [ -n "$PERL5LIB" ]; then
  export PERL5LIB=$APPDIR/lib:$PERL5LIB
else
  export PERL5LIB=$APPDIR/lib
fi
EOF

  # LSF only
  if [ "$lrms" == "lsf" ]; then
    cat >> $path <<EOF
[ -r /etc/profile.d/lsf.sh ] && source /etc/profile.d/lsf.sh
EOF
  fi

  # If Grid related information asked for
  if [ "$name" == "gridinfoCache_daemon" ]; then
    cat >> $path <<EOF
[ -r /etc/profile.d/grid-env.sh ] && source /etc/profile.d/grid-env.sh
EOF
  fi

  # Finally the executable name
  cat >> $path <<EOF

# Now the executable
program=\$APPDIR/bin/$name.pl
EOF
  # switch off parameter substitution
  cat >> $path <<'EOF'
[ -r $program ] && perl $program

exit $?
EOF
  echo chmod 755 $path
  chmod 755 $path
done

# ------------------------------------------
# the start/stop scripts for the collectors
# -----------------------------------------
if [ "$installtype" == "wn" ]; then
  list=(nodesensor)
elif [ "$installtype" == "ce" ]; then
  list=(gridinfoCache jobinfoCache jobsensor)
fi 
tmpl=$basedir/jobmon/install/sensor.tmpl
for name in ${list[*]}
do
  file=$basedir/jobmon/bin/$name
  sed -e "s#INSTALL_DIR#$basedir#g" \
      -e "s#SENSOR#$name#g" \
        $tmpl > $file
  echo chmod 755 $file
  chmod 755 $file
done

exit 0
