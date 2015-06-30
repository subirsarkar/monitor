package TaskGraphParser;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Util qw/trim/;
use WebTools::Page;

our $AUTOLOAD;
my %fields = map { $_ => 1 }
     ('ended',
      'submitted',
      'submitting',
      'partially_killed',
      'not_submitted');

sub new 
{
  my $this = shift;
  my $class = ref $this || $this;

  bless {
          info => {},
    _permitted => \%fields

  }, $class;
}
sub parse
{
  my ($self, $attr) = @_;
  croak qq|URL missing| unless defined $attr->{url};
  my $rows = WebTools::Page->Table({ url => $attr->{url}, count => 0, verbose => ($attr->{verbose} || 0) });  
  my $info = {};
  for my $row (@$rows) {
    my ($tag, $value) = ($row->[0], $row->[1]);
    next unless defined $value;
    $tag =~ s/\&nbsp;//g;
    $tag =~ s/\s+/_/g;
    $info->{$tag} = $value;
  }
  $self->{info} = $info;
}
sub show
{
  my $self = shift;
  my $info = $self->{info};
  print Data::Dumper->Dump([$info], [qw/table/]);  
}

sub DESTROY
{
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
      unless exists $self->{_permitted}{$name};

  my $info = $self->{info};
  (exists $info->{$name} ? $info->{$name} : undef);
}

1;
__END__
package main;
my $obj = TaskGraphParser->new;
$obj->parse({ url => q|http://crab1.ba.infn.it:8888/taskgraph/?tasktype=All&length=12&span=hours&type=list| });
$obj->show;
