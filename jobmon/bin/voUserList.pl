#!/usr/bin/env perl

use strict;
use warnings;
use LWP::UserAgent;
use Storable qw(nstore retrieve);
use XML::XPath;
use XML::XPath::XMLParser;

use Collector::Util qw/readFile trim/;

use constant DEBUG => 0;

# hard coded configuration. In case you do not want to support 
# all the vo, disable vo-mapping creation for those by setting
# the second element of the array to 0.
our $nodeList = [
  q|soapenv:Envelope/soapenv:Body/getGridmapUsersResponse/getGridmapUsersReturn/item|,
  q|soapenv:Envelope/soapenv:Body/getGridmapUsersResponse/getGridmapUsersReturn/getGridmapUsersReturn|
];
our $vo2server = {
        alice => [ q|voms.cern.ch|,           1, $nodeList->[1] ],
        atlas => [ q|voms.cern.ch|,           1, $nodeList->[1] ],
         argo => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
        babar => [ q|voms.gridpp.ac.uk|,      1, $nodeList->[0] ],
          bio => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
       biomed => [ q|cclcgvomsli01.in2p3.fr|, 1, $nodeList->[0] ],
          cms => [ q|voms.cern.ch|,           1, $nodeList->[1] ],
          cdf => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
    compassit => [ q|voms2.cnaf.infn.it|,     1, $nodeList->[0] ],
     compchem => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
        dteam => [ q|voms.cern.ch|,           1, $nodeList->[1] ],
        egrid => [ q|voms.cnaf.infn.it|,      0, $nodeList->[0] ],
         enea => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
          esr => [ q|voms.grid.sara.nl|,      1, $nodeList->[0] ],
  'glast.org' => [ q|voms2.cnaf.infn.it|,     1, $nodeList->[1] ],
       gridit => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
         inaf => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
     infngrid => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
         ingv => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
         lhcb => [ q|voms.cern.ch|,           1, $nodeList->[1] ],
         libi => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
        magic => [ q|voms.grid.sara.nl|,      1, $nodeList->[0] ],
       pamela => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
       planck => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
     theophys => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
        virgo => [ q|voms.cnaf.infn.it|,      1, $nodeList->[0] ],
         zeus => [ q|grid-voms.desy.de|,      1, $nodeList->[0] ]
};
# -- no need to change anything in the following
sub setEnv
{
  $ENV{HTTPS_CA_DIR} = (defined $ENV{X509_CERT_DIR}) ? $ENV{X509_CERT_DIR}
                                                     : qq|/etc/grid-security/certificates|;
  # ---- GSI Magic to make it work ----
  my $GSIPROXY = (defined $ENV{X509_USER_PROXY}) ? $ENV{X509_USER_PROXY} 
                                                 : qq|/tmp/x509up_u$<|;
  $ENV{HTTPS_CA_FILE}   = $GSIPROXY;
  $ENV{HTTPS_CERT_FILE} = $GSIPROXY;
  $ENV{HTTPS_KEY_FILE}  = $GSIPROXY;
  # ---- End of GSI Magic ----

  # Print SSL Debug stuff (omit this line if not debugging)
  $ENV{HTTPS_DEBUG} = 0;
}
sub retrieveMap
{
  my $file = shift;
  # Read stored info about the DN->VO mapping
  my $info = {};
  eval {
    $info = retrieve $file;
  };
  print qq|Error reading from file, $file: $@| if $@;
  if (DEBUG) {
    for my $dn (keys %$info) {
      print STDERR join ("#", $dn, join( ",", @{$info->{$dn}} )), "\n";
    }
  }
  $info;
}
sub storeMap
{
  my ($info, $file) = @_;
  eval {
    nstore $info, $file;
  };
  print qq|Error writing to file, $file: $@| if $@;
}
sub getParser
{
  my $xmlin = shift;
  my $xp;
  eval {
    $xp = new XML::XPath(xml => $xmlin);
  };
  if ($@) {
    print STDERR qq|Error creating XML::XPath object: $@|;
    undef $xp;
  }
  $xp;
}
sub updateMap
{
  my ($map, $dn, $vo) = @_;
  my $list;
  if (exists $map->{$dn}) {
    $list = $map->{$dn};
    push @$list, $vo unless grep {/$vo/} @$list;
  }
  else {
    $list = [$vo];
  }
  $map->{$dn} = $list;
}
sub parseLocal
{
  my ($map, $local_map) = @_;
  unless (-r $local_map) {
    warn qq|$local_map not readable!|;
    return;
  }

  for (readFile($local_map, 1)) {
    next if /^$/;
    next if /^\s?#/; # comment lines

    my ($dn, @voList) = split /#+/;
    next unless ($dn and scalar @voList);
    updateMap($map, $dn, $_) for @voList;    
  }  
}
sub main
{
  my $baseDir = shift;
  my $local_map = qq|$baseDir/jobmon/data/vomap.local|;
  my $db_file   = qq|mapping.db|;
#  my $db_file   = qq|$baseDir/jobmon/data/mapping.db|;

  # Set the authentication
  setEnv;

  # Retrieve/de-serialize the DN->VO map 
  my $map = retrieveMap($db_file);

  # Instantiate an LWP User Agent to communicate through
  my $agent = new LWP::UserAgent(timeout => 15);
  for my $vo (sort keys %$vo2server) {
    my $server = $vo2server->{$vo}[0];
    my $lookup = $vo2server->{$vo}[1];
    next unless $lookup;
    my $query = qq|https://$server:8443/voms/$vo/services/VOMSCompatibility\?method=getGridmapUsers|;
    print STDERR qq|Processing VO=$vo, QUERY=$query\n|;
    my $response = $agent->get($query);
 
    # Do something with your response
    if ($response->is_success) {
      # change encoding protocol
      my $content = $response->content;
      $content =~ s|encoding="UTF-8"|encoding="ISO-8859-1"|;

      # Now create a new XML::XPath object
      my $xp = getParser($content);
      die qq|Could not create an XML::XPath object successfully, stopped| unless (defined $xp && $xp);

      eval {
        my $node = $vo2server->{$vo}[2];
        my $nodeset = $xp->find($node);
        unless ($nodeset->isa('XML::XPath::NodeSet')) {
          print STDERR qq|Query didn't return a nodeset. Value: |;
          print STDERR $nodeset->value, "\n";

          # Close the parser now
          $xp->cleanup;
          next;
        }
        foreach my $node ($nodeset->get_nodelist) {
          my $dn = $node->string_value;
          # Filter out Robots and Services DNs
          next if ($dn =~ m/OU=Robots/ || $dn =~ m/OU=Services/);
          updateMap($map, $dn, $vo);
        }
      };
      warn qq|Parser failed! $@| if $@;

      # Close the parser now
      $xp->cleanup;
    } 
    else {
      print STDERR qq|query failed because:\n|;
      warn $response->status_line;
    }
  }

  parseLocal($map, $local_map);

  # Store/serialize the updated DN->VO map 
  storeMap($map, $db_file);
}
my $basedir = shift || '/opt';
main($basedir);
__END__
