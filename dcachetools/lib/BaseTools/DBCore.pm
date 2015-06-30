package BaseTools::DBCore;

use strict;
use warnings;
use Carp;
use DBI;

use constant DEBUG => 0;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak qq|dbname not supplied!| unless defined $attr->{dbname};
  my $dbd    = $attr->{dbd}    || qq|Pg|;
  my $host   = $attr->{dbhost} || qq|localhost|;
  my $user   = $attr->{dbuser} || qq|srmdcache|;
  my $passwd = $attr->{dbpass} || qq|srmdcache|;
  my $dbh    = DBI->connect(qq|DBI:$dbd:dbname=$attr->{dbname};host=$host|, 
               $user, $passwd, {RaiseError => 1})
                   or croak qq|Failed to connect to database: | . DBI->errstr;
  bless {
    _dbname => $attr->{dbname}, 
       _dbh => $dbh
  }, $class;
}

sub dbh
{
  my $self = shift;
  $self->{_dbh};
}

sub DESTROY
{
  my $self = shift;
  my $dbh = $self->{_dbh};
  print STDERR qq|Disconnecting from $self->{_dbname}\n| if DEBUG;
  $dbh->disconnect;
}

1;
__END__

# --- Documentation starts

=pod

=head1 NAME

BaseTools::DBCore - (Abstract) Base class for DB Connection

=head1 SYNOPSIS

Here is how a concrete class inherits from BaseTools::DBCore
 
  package CompanionDB;
  use BaseTools::DBCore;
  use base 'BaseTools::DBCore';
  
  sub new
  {
    my $this = shift;
    my $class = ref $this || $this;
    my $self = $class->SUPER::new({ dbname => qq|companion| });
    bless $self, $class;
  }

=head1 REQUIRES

DBI

DBD:Pg

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

BaseTools::DBCore is the base class for Database connection that uses C<DBI>.
It is an abstract class that defines only the constructor and destructor
any daughter class can make use of.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{dbd}    - Pg by default
    $attr->{dbname} - must be specified
    $attr->{dbhost} - DB server 
    $attr->{dbuser} - srmdcache is the default
    $attr->{dbpass} - srmdcache is the default

=item * DESTROY ($info): $info

Destructor that disconnects from the Database.

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::CompanionDB

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: DBCore.pm,v 1.0 2008/06/17 00:03:19 sarkar Exp $

=cut

# --- Documentation ends
