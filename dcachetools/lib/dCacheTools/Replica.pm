package dCacheTools::Replica;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use BaseTools::Util qw/parseInt/;

our $AUTOLOAD;
my $fields = 
{
       cached => [ 1, 'C'],
     precious => [ 2, 'P'],
  from_client => [ 3, 'C'],
   from_store => [ 4, 'S'],
    to_client => [ 5, 'c'],
     to_store => [ 6, 's'],
    b_removed => [ 7, 'R'],
  b_destroyed => [ 8, 'D'],
       pinned => [ 9, 'X'],
      inError => [10, 'E'],
       locked => [11, 'L']
};

sub new
{
  my ($this, $ls) = @_;
  my $class = ref $this || $this;
  bless {
        _input => $ls, 
    _permitted => $fields
  }, $class;
}
sub repls
{
  my $self = shift;
  if (@_) {
    return $self->{_input} = shift;
  } 
  else {
    return $self->{_input};
  }
}
# AUTOLOAD/Carp fallout
sub DESTROY
{
  my $self = shift;
}

sub pnfsid
{
  my $self = shift;
  (split /\s+/, $self->{_input})[0];
}
sub status
{
  my $self = shift;
  (split /\s+/, $self->{_input})[1];
}

sub status_bit
{
  my ($self, $pos, $label) = @_;
  my $mode = substr $self->status, $pos, 1;
  ($mode eq $label) ? 1 : 0;
}
sub lock_time
{
  my $self = shift;
  return $1 if $self->status =~ m/<.*\((.*)\).*]>/;
  return -1;
}
sub client_count
{
  my $self = shift;
  return $1 if $self->status =~ m/<.*\[(.*)\]>/;
  return -1;
}
sub size
{
  my $self = shift;
  my $size = (split /\s+/, $self->{_input})[2];
  parseInt($size);
}
sub storage_class
{
  my $self = shift;
  my $sc = (split /\s+/, $self->{_input})[-1];
  return $1 if $sc =~ m/si={(.*)}/;
  return '?';
}
sub vo
{
  my $self = shift;
  (split /:/, $self->storage_class)[0];
}
sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  exists $self->{_permitted}{$name} or croak qq|Failed to access $name field in class $type|;
  $self->status_bit($self->{_permitted}{$name}[0], $self->{_permitted}{$name}[1]);
}

sub show
{
  my $self = shift;
  my $info = 
  {
           cached => $self->cached,
         precious => $self->precious,
      from_client => $self->from_client,
       from_store => $self->from_store,
        to_client => $self->to_client,
         to_store => $self->to_store,
        b_removed => $self->b_removed,
      b_destroyed => $self->b_destroyed,
           locked => $self->locked,
          inError => $self->inError,
           pinned => $self->pinned,
       locak_time => $self->lock_time,
     client_count => $self->client_count,
             size => $self->size,
    storage_class => $self->storage_class,
               vo => $self->vo
  };
  print Data::Dumper->Dump([$info], [qw/info/]);  
}

1;
__END__
package main;
my $obj = dCacheTools::Replica->new(q|000800000000000001F13420 <--C-------L(0)[1]> 2676334281 si={cms:alldata}|);
$obj->show;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::Replica - Parses the Pool B<rep ls pnfsid> output. 

=head1 SYNOPSIS

  use dCacheTools::Replica;
  my $input = q|000800000000000001F13420 <--C-------L(0)[1]> 2676334281 si={cms:alldata}|;
  my $obj = dCacheTools::Replica->new($input);
  $obj->show;

=head1 REQUIRES

  Data::Dumper
  BaseTools::Util

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::Replica is there for convenience. It parses the Pool B<rep ls pnfsid> command 
output and provides getters to get individual fields. All the methods are AUTOLOADed.
Consult http://trac.dcache.org/trac.cgi/wiki/manuals/RepLsOutput for a detailed
discussion of all the fields.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($input): object reference

Class constructor. 

  $input - rep ls pnfsid output for a single entry

=item * show (None): None

Display the information.

  print Data::Dumper->Dump([$info], [qw/info/]);
  $info = {
            'locked' => 1,
         'to_client' => 0,
     'storage_class' => 'cms:alldata',
      'client_count' => '1',
        'from_store' => 0,
       'from_client' => 1,
          'to_store' => 0,
              'size' => 2676334281,
            'pinned' => 0,
           'inError' => 0,
       'b_destroyed' => 0,
          'precious' => 0,
         'lock_time' => '0',
         'b_removed' => 0,
            'cached' => 0
  };

=item * locked (None): boolean

=item * precious (None): boolean

=item * from_client (None): boolean

=item * from_store (None): boolean

=item * to_client (None): boolean

=item * to_store (None): boolean

=item * b_removed (None): boolean

=item * b_destroyed (None): boolean

=item * pinned (None): boolean

=item * inError (None): boolean

=item * locked (None): boolean

=item * lock_time (None): $time

=item * client_count (None): $count

=item * size (None): $size

=item * storage_class (None): $storage_class

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::Pool

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Replica.pm,v 1.0 2008/06/19 14:03:00 sarkar Exp $

=cut

# --- Documentation ends
