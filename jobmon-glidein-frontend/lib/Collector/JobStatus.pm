package Collector::JobStatus;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use IO::File;
use XML::XPath;
use XML::XPath::XMLParser;
$XML::XPath::SafeMode = 1;  # Enable

use Collector::ConfigReader;
use Collector::GridInfo;
use Collector::GridiceInfo;
use Collector::Util qw/trim getHostname importFields/;
use Collector::DBHandle;

$Collector::JobStatus::VERSION = q|1.0|;

our $AUTOLOAD;
sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this; 
  my $config = Collector::ConfigReader->instance()->config;

  my $xp = __PACKAGE__->getParser;
  croak q|Failed to create an XML::XPath object| unless defined $xp;

  my %fields = importFields;
  my $self = bless {
        dbconn => $attr->{dbconn} || Collector::DBHandle->new,
         xpath => $xp,
        config => $config,
    _permitted => \%fields,
          dict => {}
  }, $class;

  $self->_initialize();
  $self;
}

sub info
{
  my $self = shift;
  $self->{info};
}

sub joblist
{
  my $self = shift;
  my $info = $self->info;
  sort keys %$info;
}

sub getParser
{
  my $pkg = shift;
  my $xp;
  eval
  {
    $xp = XML::XPath->new;
  };
  if ($@)
  {
    print STDERR qq|Error creating XML::XPath object: $@|;
    undef $xp;
  }
  $xp;
}

sub getValue
{
  my ($self, $attr) = @_;

  # First check if the information is available in the cache
  my $jid = $attr->{jid};
  my $tag = $attr->{tag} || q|load|;
  return $self->{dict}{$jid}{$tag} if defined $self->{dict}{$jid}{$tag};

  # Not found in cache, we must now look-up the DB
  my $config  = $self->{config};
  my $verbose = $config->{config} || 0;
  my $value = 0;

  my $host = $attr->{host};
  print STDERR join (":", $host, $jid), "\n" if $verbose; 

  my $name = qq|$host.xml|;
  my $dbh = $self->{dbconn}->dbh;
  my $sth = $dbh->prepare(q|SELECT data FROM wninfo WHERE name=?|);
  $sth->execute($name);

  # Extract the data from the result of the query
  my $blob = $sth->fetchrow;
  $sth->finish;
  carp qq|Failed to retrieve XML information for host=$host,jid=$jid,tag=$tag!| 
    and return $value unless defined $blob;

  # Catalin Dumitrescu got into problems with > 4k jobs on a CE
  # Solution: Remove unnecessary content before passing to XML::XPath. 
  # Alternative could be to use a SAX parser
  $blob =~ s!<((log|error|workdir|jobdir|top|ps))>.*?</\1>!!sg;
  $blob =~ s!\s+! !sg;
  print STDERR $blob, "\n" if $verbose;

  # create the XML parser
  my $xp = $self->{xpath};
  carp qq|XML::XPath object undefined, jid=$jid,host=$host,tag=$tag!| 
    and return $value unless defined $xp;

  my @tagList = qw/load diskusage/;
  eval {
    $xp->set_xml($blob);
    my $nodeset = $xp->find(q|/info/jid|);
    foreach my $node ($nodeset->get_nodelist) {
      print "FOUND\n\n", XML::XPath::XMLParser::as_string($node), "\n\n" if $verbose;

      my $attributes = $node->getAttributes;
      # FIXME. $jobid should be initialised
      my $jobid = $attributes->[0]->getNodeValue if $attributes;
      $self->{dict}{$jobid}{$_} 
         = $xp->getNodeText(qq{/info/jid[\@value="$jobid"]/$_})->value || 0.0 for @tagList;
    }
  };
  carp qq|Ill formatted xml string passed to XML::XPath jid=$jid,host=$host,tag=$tag; $@| if $@;

  # As we are using a single XML::XPath instance, we must take that bit of extra care
  $xp->cleanup;
  $xp->set_context(undef);

  return ($self->{dict}{$jid}{$tag} || 0.0);
}

sub _initialize
{
  my $self = shift;
  my $config = $self->{config};
  my $debug   = $config->{debug}   || 0;
  my $verbose = $config->{verbose} || 0;

  my $fh;
  if ($debug) {
    my $logfile = $config->{logfile} || q|/tmp/qstat_mon.log|;
    $fh = IO::File->new($logfile, 'w');
    croak qq|Failed to open $logfile, $!, stopped| unless (defined $fh and $fh->opened);
  }
  my $obj = Collector::GridiceInfo->new;
  my $info = $obj->info;

  # close log file handle
  $fh->close if (defined $fh and $fh->opened);

  $self->{info} = $info;
}

sub DESTROY
{
  my $self = shift;

  # Close the XML parser
  my $xp = $self->{xpath};
  $xp->cleanup if defined $xp;
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
    unless exists $self->{_permitted}{$name};

  my $jid = shift;
  croak q|JOBID not specified!| unless defined $jid;

  my $info = $self->info;
  if (@_) {
    return $info->{$jid}{$name} = shift;
  } 
  else {
    return ( defined $info->{$jid}{$name} 
           ? trim $info->{$jid}{$name} 
           : undef );
  }
}

1;
__END__
package main;
use Data::Dumper;
my $obj = Collector::JobStatus->new;
my $info = $obj->info;
print Data::Dumper->Dump([$info], [qw/info/]); 
