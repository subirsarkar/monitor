#!/bin/bash
set -o nounset

BASEURL=http://sarkar.web.cern.ch/sarkar/dcachetools/
PERLDOC=perldoc.html
touch perldoc.html
echo "<html>"$'\n'"<body>" > $PERLDOC

for file in $(ls lib/*/*.pm)
do
  html=$(echo $file | sed -e s#lib#doc# -e s#.pm#.html#)
  echo pod2html --infile=$file --outfile=$html
       pod2html --infile=$file --outfile=$html
  echo "<a href=$BASEURL/$html>$html</a><br/>" >> $PERLDOC  
done
echo "</body>"$'\n'"</html>" >> $PERLDOC
exit 0
