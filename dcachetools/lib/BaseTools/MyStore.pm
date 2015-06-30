package BaseTools::MyStore;

use strict;
use warnings;
use Carp;
use Storable;
use Data::Dumper;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;
  
  my $dbfile = $attr->{dbfile} or croak qq|dbfile not specified|;

  my $info = {};
  if ( -e $dbfile) {
    eval {
      $info = retrieve $dbfile;
    };
    carp qq|Error reading from $dbfile: $@| if $@;
  }
  bless {
       _info => $info, 
     _dbfile => $dbfile
  }, $class;
}

sub info 
{
  my ($self, $info) = @_;
  $self->{_info} = $info if defined $info;
  return $self->{_info};
}

sub contains
{
  my ($self, $key) = @_;
  exists $self->{_info}{$key};
}

sub get
{
  my ($self, $key) = @_;
  $self->{_info}{$key};
}

sub add 
{
  my ($self, $key, $value) = @_;
  $self->{_info}{$key} = $value;
}

sub remove
{
  my ($self, $key) = @_;
  delete $self->{_info}{$key};
}

sub save
{
  my ($self, $params) = @_;
  my $info   = (exists $params->{info})   ? $params->{info}   : $self->{_info};
  my $dbfile = (exists $params->{dbfile}) ? $params->{dbfile} : $self->{_dbfile};
  eval {
    store $info, $dbfile;
  };
  carp qq|Error storing back the $dbfile: $@| if $@;
}

sub show
{
  my $self = shift;
  my $info = $self->{_info};
  print Data::Dumper->Dump([$info], [qw/info/]);
}

1;
__END__
package main;
my $file = shift || die qq|Usage: $0 dbfile|;
my $obj  = BaseTools::MyStore->new({ dbfile => $file });
$obj->show;

# -- Documentation starts

=pod

=head1 NAME

BaseTools::MyStore - A simple wrapper over C<Storable> 

=head1 SYNOPSIS

  use BaseTools::MyStore;
  my $file = q|my.db|;
  my $obj  = BaseTools::MyStore->new({ dbfile => $file });
  $obj->show;

=head1 REQUIRES

  Storable
  Data::Dumper
  Carp

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<BaseTools::MyStore> wraps C<Storable> and can manipulate the underlying data 
structure, usually a hash reference, using C<add()>, C<remove()>, C<contains()>, 
C<get()> and other related methods.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{dbfile} - the file that holds the underlying Storable data structure.

=item * contains ($key): boolean

Check if a key exists in the underlying data structure.

=item * get ($key): $value

Retrieve the value for a given key. The value should preferably be a scalar but there is not strict rule.

=item * add ($key, $value): None

Add a new key/value pair to the underlying C<Storable> data structure.

=item * remove ($key): None

Remove the entry corresponding to the $key passed as argument from the underlying C<Storable> data structure.

=item * save ($params): None

Save the updated information back to the default file. One can optionally specify a new data structure to be saved.
A different file name which should hold the new records can be specified as well.

    $params->{dbfile} - specify in case you want to save the information in a file different from the one specified at construction
    $params->{info}   - you may even opt to store a completely different data structure [rarely needed] 

=item * show (None): None

Show the current content of the C<Storable>. 

  print Data::Dumper->Dump([$info], [qw/info/]);

=item * info ($info): $info

set/get the underlying C<Storable> data structure. Return the data structure in both cases.

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

Storable

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: MyStore.pm,v1.1 2008/12/11 14:03:19 sarkar Exp $

=cut

# --- Documentation ends
