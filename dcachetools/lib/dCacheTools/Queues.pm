package dCacheTools::Queues;

use strict;
use warnings;
use Carp;

use WebTools::Page;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  unless (defined $attr->{webserver}) {
    my $reader = BaseTools::ConfigReader->instance();
    croak q|webserver is not specified even in the configuration file!|
      unless defined $reader->{config}{webserver};
    $attr->{webserver} = $reader->{config}{webserver};
  }
  bless {
    _webserver => $attr->{webserver}
  }, $class;
}

sub _initialize
{
  my $self = shift;
  $self->{_info} = {};
  my $query = sprintf qq|http://%s:2288/queueInfo|, $self->{_webserver};
  my $rows = WebTools::Page->Table({ url => $query });
  if (scalar @$rows) {
    # Now convert the array info a useful dictionary
    splice @$rows, 1, 1;
    splice @$rows, -3, 3;
    my $h = shift @$rows;
    splice @$h, 0, 2;

    splice @{$rows->[0]}, 1, 0, "allDomain";
    for my $row (@$rows) {
      my $pool = $row->[0];
      splice @$row, 0, 2;
      for my $type (@$h) {   # Movers Restores Stores P2P-Server P2P-Client default wan
        for my $state (qw/Active Max Queued/) {
          $self->{_info}{$pool}{$type}{$state} = splice @$row, 0, 1;
        }
      }
    }
  }
}

sub _info
{
  my $self = shift;
  $self->_initialize unless defined $self->{_info};
  $self->{_info};
}

sub movers
{
  my ($self, $params) = @_;
  return -1 unless (defined $params->{pool} 
                 && defined $params->{type} 
                 && defined $params->{state});
  my $pool  = $params->{pool};
  my $type  = $params->{type};
  my $state = ucfirst $params->{state};
  my $info = $self->_info; # lazy initialization
  $info->{$pool}{$type}{$state};
}

sub show
{
  my $self = shift;
  my $info = $self->_info; # lazy initialization
  for my $pool (sort keys %$info) {
    my $typeList = $info->{$pool};
    printf "%14s %6s %6s %6s\n", $pool, "Active", "Max", "Queued";
    for my $type (sort keys %$typeList) {
      printf "%14s %6d %6d %6d\n", $type, 
        $self->movers({ pool => $pool, type => $type, state => q|Active| }), 
        $self->movers({ pool => $pool, type => $type, state => q|Max| }), 
        $self->movers({ pool => $pool, type => $type, state => q|Queued| });
    }
  }
}

1;
__END__
package main;
my $obj = dCacheTools::Queues->new({ webserver => q|cmsdcache| });
$obj->show;
print $obj->movers({ pool => q|cmsdcache8_1|, type => q|default|, state => q|Active|}), "\n";

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::Queues - Parses the dCache B<Pool Mover Queues> table 

=head1 SYNOPSIS

  use dCacheTools::Queues;
  my $obj = dCacheTools::Queues->new({ webserver => q|cmsdcache| });
  $obj->show;
  print $obj->movers({ pool => q|cmsdcache8_1|, type => q|default|, state => q|Active|}), "\n";

=head1 REQUIRES

  WebTools::Page

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::Queues parses the dCache B<Pool Mover Queues> table embedded in
http://webserver:2288/queueInfo and stores in a data structure
that can be easily used by other tools. The same information can be extracted from the PoolManager cell also
parsing the B<cm ls -r> output.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{webserver}  - dCache web server host

=item * show (None): None

Display the information.

=item * movers ($params): scalar

Returns the number of movers assigned to a particular type and state of transfer. 
The types are  I<Movers>, I<Restores>, I<Stores>, I<P2P-Server>, I<P2P-Client> etc. 
while the states are I<Active>, I<Max> and I<Queued>

   $params->{pool}  - Pool name
   $params->{type}  - transfer/mover type
   $params->{state} - state of the transfer

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Queues.pm,v 1.0 2008/06/17 00:03:19 sarkar Exp $

=cut

# --- Documentation ends
