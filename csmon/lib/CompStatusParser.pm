package CompStatusParser;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Util qw/trim/;
use WebTools::Page;

our $AUTOLOAD;
my %fields = map { $_ => 1 }
   qw/created
      not_handled
      handled
      failed
      output_requested
      in_progress
      processed/;

sub new 
{
  my ($this, $attr) = @_;
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
  my $rows = WebTools::Page->Table({ url => $attr->{url}, count => 1, verbose => ($attr->{verbose} || 0) });  
  my $info = {};
  for my $row (@$rows) {
    my ($tag, $value) = ($row->[0], $row->[1]);
    next unless defined $value;
    $tag =~ s/\&nbsp;//g;
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
my $obj = CompStatusParser->new({ url => q|http://glidein-2.t2.ucsd.edu:8888/compstatus| });
$obj->show;
