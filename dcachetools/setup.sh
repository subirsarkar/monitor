DCACHETOOLS_BASEDIR=/opt/dcachetools
export DCACHETOOLS_CONFIG_DIR=$DCACHETOOLS_BASEDIR/etc
if [ -n "$PERL5LIB" ]; then
  echo $PERL5LIB | grep $DCACHETOOLS_BASEDIR/lib > /dev/null
  [ $? -eq 0 ] || export PERL5LIB=$DCACHETOOLS_BASEDIR/lib:$PERL5LIB
else
  export PERL5LIB=$DCACHETOOLS_BASEDIR/lib
fi
export CLASSPATH=/opt/d-cache/classes/cells.jar:/opt/d-cache/classes/dcache.jar:/opt/d-cache/classes/log4j/log4j-1.2.15.jar
