package dCacheTools::Info::PoolGroup;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use List::Util qw/min max/;

use BaseTools::ConfigReader;
use BaseTools::Util qw/getXMLParser/;
use WebTools::Page;

use constant GB2By => 1024**3;

our $AUTOLOAD;
my %fields = map { $_ => 1 }
    qw/total
       free
       used
       precious
       removable
       pools/;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  defined $attr->{name} or croak q|pgroup not specified|;
  unless (defined $attr->{webserver}) {
    my $reader = BaseTools::ConfigReader->instance();
    croak q|webserver is not specified even in the configuration file!| 
      unless defined $reader->{config}{webserver};
    $attr->{webserver} = $reader->{config}{webserver};
  }
  my $self = bless { 
    _pgroup    => $attr->{name}, 
    _webserver => $attr->{webserver},
    _permitted => \%fields
  }, $class;
  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;
  my $name = $self->{_pgroup};
  my $query = sprintf qq|http://%s:2288/info/poolgroups/%s|, $self->{_webserver}, $name;
  my $content = WebTools::Page->Content($query);
  length $content or return;

  # Now create a new XML::XPath object
  my $xp = getXMLParser($content);
  croak qq|Failed to create an XML::XPath object successfully| unless defined $xp;

  my $info = {};
  $info->{_total}     = $xp->findvalue(qq|/dCache/poolgroups/poolgroup[\@name="$name"]/space/metric[\@name="total"]|);
  $info->{_free}      = $xp->findvalue(qq|/dCache/poolgroups/poolgroup[\@name="$name"]/space/metric[\@name="free"]|);
  $info->{_removable} = $xp->findvalue(qq|/dCache/poolgroups/poolgroup[\@name="$name"]/space/metric[\@name="removable"]|);
  $info->{_precious}  = $xp->findvalue(qq|/dCache/poolgroups/poolgroup[\@name="$name"]/space/metric[\@name="precious"]|);
  $info->{_used}      = $xp->findvalue(qq|/dCache/poolgroups/poolgroup[\@name="$name"]/space/metric[\@name="used"]|);
  $info->{$_}         = int($info->{$_}) for (keys %$info);

  foreach my $poolref ($xp->find(qq|/dCache/poolgroups/poolgroup[\@name="$name"]/pools/poolref|)->get_nodelist) {
    my $pname = $poolref->find('@name');
    push @{$info->{_pools}}, $pname;
  }
  $self->{_info} = $info;
}

sub poollist
{
  my $self = shift;
  my $info = $self->info;
  @{$info->{_pools}};
}

sub info
{
  my $self = shift;
  $self->{_info};
}

sub show
{
  my $self = shift;
  my $info = $self->info;
  printf qq|%9s %9s %9s %9s %9s\n|, q|Total|, q|Free|, q|Used|, q|Precious|, q|Removable|;
  printf qq|%9.2f %9.2f %9.2f %9.2f %9.2f\n|, $info->{_total}/GB2By, 
                                              $info->{_free}/GB2By,
                                              $info->{_used}/GB2By,
                                              $info->{_precious}/GB2By,
                                              $info->{_removable}/GB2By;
  print join("\n", @{$info->{_pools}}), "\n";
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
     unless exists $self->{_permitted}{$name};
  return (exists $self->{_info}{"_$name"} ? $self->{_info}{"_$name"} : undef);
}

sub DESTROY 
{
  my $self = shift;
}

1;
__END__
my $obj = new dCacheTools::Info::PoolGroup({ name => qq|cms| });
$obj->show;
