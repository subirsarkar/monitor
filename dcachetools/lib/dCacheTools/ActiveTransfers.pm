package dCacheTools::ActiveTransfers;

use strict;
use warnings;
use Carp;
use Data::Dumper;

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
  my $query = sprintf qq|http://%s:2288/context/transfers.html|, $attr->{webserver};
  my $h = WebTools::Page->Table({ url => $query });
  bless { _rows => $h }, $class;
}
sub rows
{
  my $self = shift;
  $self->{_rows};
}
sub show
{
  my $self = shift;
  my $rows = $self->rows;
  print Data::Dumper->Dump([$rows], [qw/rows/]);
}

1;
__END__
package main;
my $obj = dCacheTools::ActiveTransfers->new({ webserver => 'cmsdcache'});
$obj->show;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::ActiveTransfers - Parses the B<Active Transfer> table on the dCache web monitor

=head1 SYNOPSIS

  use dCacheTools::ActiveTransfers;
  my $obj = dCacheTools::ActiveTransfers->new({ webserver => 'cmsdcache'});
  $obj->show;

=head1 REQUIRES

  Carp
  WebTools::Page

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::ActiveTransfers parses the dCache B<Active Transfers> table embedded in
http://<webserver>:2288/context/transfers.html and stores in a data structure that 
can be easily used by other tools. This information can be used to calculate transfer 
rates for dcap, gridftp etc. for individual pools which serves as a very useful 
diagnostic tool. This is also a very efficient way to access such information as 
the Admin Console is not used.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

  $attr->{webserver} - dCache web server host

=item * rows (None): $rows

Return the underlying container which is a hash reference

=item * show (None): None

Display the information.

  print Data::Dumper->Dump([$rows], [qw/rows/]);

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

$Id: ActiveTransfers.pm,v 1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
