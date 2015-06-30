package dCacheTools::GridftpCell;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use BaseTools::Util qw/trim/;
use dCacheTools::GridftpTransfer;
use base 'dCacheTools::Cell';

our $AUTOLOAD;
my %fields = map { $_ => 1 }
  qw/logins_created
     logins_failed
     logins_denied
     logins_active
     logins_max/;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|Must specify the Gridftp Cell!| unless defined $attr->{name};
  my $verbose = $attr->{verbose} || 0;

  my $self = $class->SUPER::new({ name => $attr->{name} });
  $self = bless $self, $class;
  $self->{_permitted} = \%fields;
  $self->{_verbose} = $verbose;
  $self->_initialize;
  $self;
}

# AUTOLOAD/carp fallout
sub DESTROY { 
  my $self = shift;
}

sub _initialize
{
  my $self = shift;

  $self->{_info} = {};
  my @output = grep { /Logins/ } $self->exec({ command => q|info| });
  return unless $self->alive;
  
  my $logins_created = (split /:/, $output[0])[-1];
  my $logins_failed  = (split /:/, $output[1])[-1];
  my $logins_denied  = (split /:/, $output[2])[-1];
  my ($logins_active_str, $logins_max) = (split /\//, (split /:/, $output[3])[-1]);
  my $logins_active = (split /\(/, $logins_active_str)[0];
  $self->{_info}{logins_created} = trim $logins_created;
  $self->{_info}{logins_failed}  = trim $logins_failed;
  $self->{_info}{logins_denied}  = trim $logins_denied;
  $self->{_info}{logins_active}  = trim $logins_active;
  $self->{_info}{logins_max}     = trim $logins_max;

  # store the children cell name
  my @children = $self->exec({ command => q|get children| });
  $self->{_info}{children} = (scalar @children) ? \@children : [];

  print Data::Dumper->Dump([$self->{_info}], [qw/info/]) if $self->{_verbose};
}

sub info
{
  my $self = shift;
  $self->{_info};
}

sub header
{
  my $pkg = shift;
  print "------------------------\n\tLogins\n------------------------\n";
  printf "%18s %7s %6s %6s %6s %6s\n",
     "Domain", "Created", "Failed", "Denied", "Active", "Max";
}

sub showLogin 
{
  my $self = shift;
  my $cell = $self->name;

  printf "%18s %7d %6d %6d %6d %6d\n",
      (split /@/, $cell)[0],
      $self->logins_created,
      $self->logins_failed,
      $self->logins_denied,
      $self->logins_active,
      $self->logins_max;
}

sub showChildren 
{
  my $self  = shift;
  my $children = $self->{_info}{children};
  for my $door (@$children) {
    my $obj = dCacheTools::GridftpTransfer->new({ name => $door });
    next unless $obj->alive;
    printf "%29s|", $door;
    $obj->show;
  }
}

sub show
{
  my $self = shift;
  $self->showLogin;
  $self->showChildren;
}

# Reference to the children cell name array
sub children
{
  my $self = shift;
  (exists $self->{_info}{children}) ? $self->{_info}{children} : [];
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion
  exists $self->{_permitted}{$name} 
    or croak qq|Failed to access $name field in class $type|;

  my $info = $self->info;
  (exists $info->{$name} ? $info->{$name} : undef);
}

1;
__END__
package main;

my @objectList = ();
my $lb = dCacheTools::Cell->new({ name => q|LoginBroker| });
my @gftpList = grep {/GFTP/} $lb->exec({ command => q|ls| });
die unless $cell->alive;

for (@gftpList) {
  my $cell = (split /;/)[0];
  my $obj = dCacheTools::GridftpCell->new({ name => $cell });
  next unless $obj->alive;
  push @objectList, $obj;
}
# First the logins
dCacheTools::GridftpCell->header;
for my $obj (@objectList) {
  $obj->showLogin;
}
# Now the children
for my $obj (@objectList) {
  $obj->showChildren;
}

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::GridftpCell - A wrapper for a Gridftp cell

=head1 SYNOPSIS

  use dCacheTools::GridftpCell;
  
  my @objectList = ();
  my $lb = dCacheTools::Cell->new({ name => q|LoginBroker| });
  my @gftpList = grep {/GFTP/} $lb->exec({ command => q|ls| });
  die q|LoginBroker cell dead! stopped| unless $lb->alive;

  for (@gftpList) {
    my $cell = (split /;/)[0];
    my $obj = dCacheTools::GridftpCell->new({ name => $cell });
    next unless $obj->alive;
    push @objectList, $obj;
  }
  # First the logins
  dCacheTools::GridftpCell->header;
  for my $obj (@objectList) {
    $obj->showLogin;
  }
  # Now the children
  for my $obj (@objectList) {
    $obj->showChildren;
  }

=head1 REQUIRES

  BaseTools::Util
  dCacheTools::Cell
  dCacheTools::GridftpTransfer

=head1 INHERITANCE

  dCacheTools::Cell

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::GridftpCell> is a simple wrapper over a single Gridftp Cell and holds
summary as well as detailed information about all the children doors.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{name}  - the Gridftp cell name generally of the form GFTP-cmsdcache5@gridftp-cmsdcache5Domain [obligatory]

=item * info (None): None

Return the underlying data structure which is a hash reference. If appropriate, gathers the information
before sending back. Here is an example of the content of the hash:

    $info = {
          'logins_denied' => '0',
          'logins_max' => '100',
          'logins_active' => '12',
          'logins_failed' => '0',
          'children' => [
                          'GFTP-cmsdcache10-Unknown-1782',
                          'GFTP-cmsdcache10-Unknown-1815',
                          'GFTP-cmsdcache10-Unknown-1819',
                          'GFTP-cmsdcache10-Unknown-1777',
                          'GFTP-cmsdcache10-Unknown-1816',
                          'GFTP-cmsdcache10-Unknown-1817',
                          'GFTP-cmsdcache10-Unknown-1814',
                          'GFTP-cmsdcache10-Unknown-1770',
                          'GFTP-cmsdcache10-Unknown-1818',
                          'GFTP-cmsdcache10-Unknown-1780',
                          'GFTP-cmsdcache10-Unknown-1820',
                          'GFTP-cmsdcache10-Unknown-1813'
                        ],
          'logins_created' => '1719'
      };

=item * showLogin (None): None

Display client login information as shown below 

  ------------------------
        Logins
  ------------------------
            Domain Created Failed Denied Active    Max
   GFTP-cmsdcache5    1664      0      0      2    100

=item * header (None): None

A static method that provides a header for I<showLogin>

=item * showChildren (None): None

Loops over the Children B<GridftpTransfer> doors and calls the child show method

=item * show (None): None

Show both login information and transfer details of the children

=item * children (None): @list

Return a list of children door names

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::GridftpTransfer

=head1 AUTHORS

  Sonia Taneja (sonia.taneja@pi.infn.it)
  Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: GridftpCell.pm,v 1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
