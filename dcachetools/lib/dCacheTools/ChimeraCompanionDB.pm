package dCacheTools::ChimeraCompanionDB;

use strict;
use warnings;
use Carp;

use BaseTools::ConfigReader;
use base 'BaseTools::DBCore';

sub new 
{
  my $this = shift;
  my $class = ref $this || $this;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $dbconfig = 
  {
    dbd    => $config->{dbconfig}{dbd}  || q|Pg|,
    dbname => $config->{dbconfig}{name} || q|chimera|,
    dbhost => $config->{dbconfig}{host} || q|localhost|,
    dbuser => $config->{dbconfig}{user} || q|srmdcache|,
    dbpass => $config->{dbconfig}{pass} || q|srmdcache|
  };
  my $self = $class->SUPER::new($dbconfig);
  bless $self, $class;
}

sub pools
{
  my ($self, $params) = @_;
  my $dbh = $self->dbh;
  my $pnfsid = $params->{pnfsid};
  my $sth = $dbh->prepare(q|SELECT ilocation FROM t_locationinfo WHERE ipnfsid=?|) 
    or croak q|Failed to prepare statement: | . $dbh->errstr;
  $sth->execute($pnfsid) or croak q|Failed to execute statement: | . $sth->errstr;
  my @list = ();
  while (my $aref = $sth->fetchrow_arrayref) {
    push @list, $aref->[0];
  }
  croak qq|Fetch failed due to $DBI::errstr| if $DBI::err;
  $sth->finish;

  @list;
}

1;
__END__
package main;
my $pnfsid = shift || die qq|Usage: $0 pnfsid|;
my $dbc    = dCacheTools::ChimeraCompanionDB->new;
my @pools = $dbc->pools({ pnfsid => $pnfsid });
print join ("\n", @pools), "\n";

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::ChimeraCompanionDB - dCache Companion DB handler. For Chimera, just an emulation

=head1 SYNOPSIS

  use dCacheTools::ChimeraCompanionDB;
  my $pnfsid = shift || die;
  my $dbc   = dCacheTools::ChimeraCompanionDB->new;
  my @pools = $dbc->pools({ pnfsid => $pnfsid });
  print join ("\n", @pools), "\n";

=head1 REQUIRES

  BaseTools::DBCore
  Carp

=head1 INHERITANCE

BaseTools::DBCore

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::ChimeraCompanionDB connects to the dCache Companion Database to retrieve
the list of pools that host a file replica.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new (): object reference

Class constructor. Connects to the dCache Companion Database

=item * pools (params): @list

Returns the list of pools that host a file replica corresponding to a pnfsid

  $params->{pnfsid}  - pnfsid for the file replica;

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

$Id: ChimeraCompanionDB.pm,v 1.0 2010/11/22 11:28:19 sarkar Exp $

=cut

# --- Documentation ends
