package dCacheTools::Info::Pool;

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
    qw/state
       space
       movers/;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  defined $attr->{name} or croak qq|pool name not specified|;
  unless (defined $attr->{webserver}) {
    my $reader = BaseTools::ConfigReader->instance();
    croak qq|webserver is not specified even in the configuration file!| 
      unless defined $reader->{config}{webserver};
    $attr->{webserver} = $reader->{config}{webserver};
  }
  my $self = bless { 
         _pool => $attr->{name}, 
    _webserver => $attr->{webserver},
    _permitted => \%fields
  }, $class;
  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;
  my $name = $self->{_pool};
  my $query = sprintf qq|http://%s:2288/info/pools/%s|, $self->{_webserver}, $name;
  my $content = WebTools::Page->Content($query);
  length $content or return;

  # Now create a new XML::XPath object
  my $xp = getXMLParser($content);
  croak qq|Failed to create an XML::XPath object successfully| unless defined $xp;

  my $info = {};
  # Status
  my $base_path = qq|/dCache/pools/pool[\@name="$name"]|;
  $info->{_state}{enabled}  = ($xp->findvalue(qq|$base_path/metric[\@name="enabled"]|) eq 'true') ? 1 : 0;
  $info->{_state}{readonly} = ($xp->findvalue(qq|$base_path/metric[\@name="read-only"]|) eq 'true') ? 1 : 0;
  $info->{_state}{last_heartbeat} = int($xp->findvalue(qq|$base_path/metric[\@name="last-heartbeat"]|));

  # Space
  $base_path = qq|/dCache/pools/pool[\@name="$name"]/space|;
  $info->{_space}{total}     = $xp->findvalue(qq|$base_path/metric[\@name="total"]|);
  $info->{_space}{free}      = $xp->findvalue(qq|$base_path/metric[\@name="free"]|);
  $info->{_space}{removable} = $xp->findvalue(qq|$base_path/metric[\@name="removable"]|);
  $info->{_space}{precious}  = $xp->findvalue(qq|$base_path/metric[\@name="precious"]|);
  $info->{_space}{used}      = $xp->findvalue(qq|$base_path/metric[\@name="used"]|);
  $info->{_space}{gap}       = $xp->findvalue(qq|$base_path/metric[\@name="gap"]|);
  $info->{_space}{$_}        = int($info->{_space}{$_}) for (keys %{$info->{_space}});

  # Movers
  my $qm = 
  {
    default => 'dcap', 
        wan => 'gridftp'
  };
  for my $type (qw/default wan/) {
    $base_path = qq|/dCache/pools/pool[\@name="$name"]/queues/named-queues/queue[\@name="$type"]|;
    $info->{_movers}{$qm->{$type}}{max}    = $xp->findvalue(qq|$base_path/metric[\@name="max-active"]|);
    $info->{_movers}{$qm->{$type}}{queued} = $xp->findvalue(qq|$base_path/metric[\@name="queued"]|);
    $info->{_movers}{$qm->{$type}}{active} = $xp->findvalue(qq|$base_path/metric[\@name="active"]|);
  }
  $qm = 
  {
    'p2p-clientqueue' => 'p2pc',
          'p2p-queue' => 'p2ps'
  };
  for my $type (keys %$qm) {
    $base_path = qq|/dCache/pools/pool[\@name="$name"]/queues/queue[\@type="$type"]|;
    $info->{_movers}{$qm->{$type}}{max}    = $xp->findvalue(qq|$base_path/metric[\@name="max-active"]|);
    $info->{_movers}{$qm->{$type}}{queued} = $xp->findvalue(qq|$base_path/metric[\@name="queued"]|);
    $info->{_movers}{$qm->{$type}}{active} = $xp->findvalue(qq|$base_path/metric[\@name="active"]|);
  }
  for my $mt (keys %{$info->{_movers}}) {
    $info->{_movers}{$mt}{$_} = int($info->{_movers}{$mt}{$_}) for (keys %{$info->{_movers}{$mt}})
  }
  $self->{_info} = $info;
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
  printf qq|%9.2f %9.2f %9.2f %9.2f %9.2f\n|, $info->{_space}{total}/GB2By, 
                                              $info->{_space}{free}/GB2By,
                                              $info->{_space}{used}/GB2By,
                                              $info->{_space}{precious}/GB2By,
                                              $info->{_space}{removable}/GB2By;
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
my $obj = new dCacheTools::Info::Pool({ name => q|cmsdcache13_1| });
$obj->show;

my $movers = $obj->movers;
print Data::Dumper->Dump([$movers], [qw/movers/]);
print join (' ', $movers->{dcap}{max}, $movers->{dcap}{active}, $movers->{dcap}{queued}), "\n";
