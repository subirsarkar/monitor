#!/bin/sh

source ./setup_lsfmon
perl -w create_rrd.pl
perl -w create_vo_rrd.pl

exit
