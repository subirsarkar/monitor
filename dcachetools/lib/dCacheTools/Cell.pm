package dCacheTools::Cell;

use strict;
use warnings;
use Carp;

use BaseTools::ConfigReader;
use dCacheTools::Admin;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|Expected a dCache Cell name!| unless defined $attr->{name};
  bless {
                  _name => $attr->{name},
                 _alive => 1,
              _timedOut => 0,
          _hasException => 0, 
     _hasCacheException => 0, 
         _commandFailed => 0
  }, $class;
}
sub exec
{
  my ($self, $params) = @_;
  my @output = ();
  carp q|No valid command passed in the argument!| and return @output
    unless defined $params->{command};
  my $command = $params->{command};
  $command .= qq| $params->{arg}| if defined $params->{arg};
 
  my $name  = $self->{_name};
  my $admin = dCacheTools::Admin->instance();

  my $reader = BaseTools::ConfigReader->instance();
  my $interface = $reader->{config}{admin}{proto} || q|API|;
  if ($interface eq 'SSH') {
    my $loop = (defined $params->{retry}) ? $params->{retry} : 1;
    my $natt = 0;
    until (scalar @output) {
      @output = $admin->exec({ cell => $name, command => $command });
      last unless ($loop && ++$natt<3);
    }
  }
  else {
    @output = $admin->exec({ cell => $name, command => $command });
  }
  $self->{_alive}             = $admin->cell_alive;
  $self->{_timedOut}          = $admin->timedOut;
  $self->{_hasException}      = $admin->hasException;
  $self->{_hasCacheException} = grep /CacheException/, @output;
  $self->{_commandFailed}     = grep /$params->{command} failed/, @output;

  @output;
}
# usually checked immediately after an exec
sub name 
{
  my $self = shift;
  $self->{_name};
}
sub alive
{
  my ($self, $params) = @_;
  $self->exec({ command => q|info| }) if defined $params->{refresh};
  my $ret = $self->{_alive};
  $self->{_alive} = 1 if defined $params->{reset};
  $ret;
}
sub timedOut
{
  my ($self, $params) = @_;
  $self->exec({ command => q|info| }) if defined $params->{refresh};
  my $ret = $self->{_timedOut};
  $self->{_timedOut} = 1 if defined $params->{reset};
  $ret;
}
sub hasException
{
  my ($self, $params) = @_;
  my $ret = $self->{_hasException};
  $self->{_hasException} = 0 if defined $params->{reset};
  $ret;
}
sub hasCacheException
{
  my ($self, $params) = @_;
  my $ret = $self->{_hasCacheException};
  $self->{_hasCacheException} = 0 if defined $params->{reset};
  $ret;
}
sub commandFailed
{
  my ($self, $params) = @_;
  my $ret = $self->{_commandFailed};
  $self->{_commandFailed} = 0 if defined $params->{reset};
  $ret;
}

1;
__END__
package main;
my $lb = dCacheTools::Cell->new({ name => q|LoginBroker| });
my @list = $lb->exec({ command => q|ls -l| });
print join ("\n", @list), "\n";
print $lb->name, "\n";
# --- Documentation starts
=pod

=head1 NAME

dCacheTools::Cell - Implements a basic dCache Cell

=head1 SYNOPSIS

  use dCacheTools::Cell;
  my $lb = dCacheTools::Cell->new({ name => q|LoginBroker| });
  my @list = $lb->exec({ command => q|ls -l| });
  print join ("\n", @list), "\n";

=head1 REQUIRES

  Carp
  dCacheTools::Admin

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::Cell> forms the basis of most of the cell, handles the admin command execution, 
checks if the cell is alive and defines exceptions. C<dCacheTools::Cell> ensures that the admin 
commands are retried if output is expected but for some reason the first attempt did not 
execute successfully.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{name} - Cell name which executes the command (e.g PoolManager, PnfsManager, Pool etc.)

=item * exec ($params): @list

Execute an Admin console command and return the output as a list; if necessary retry. The input
parameters are

    $params->{command} - admin command (may or may not have the arguments)
    $params->{arg}     - admin command argument
    $params->{retry}   - If enabled, (re)tries upto 3 times if output list is empty, usually for 'get' operation 

Execution of the command also sets flag if the pool was responsive, had exceptions etc.
Before parsing/analysing the command output one should check the following:

   $cell->alive - pool responded
   $cell->hasCacheException - e.g 'rep ls pnfsid' failed
   $cell->hasException - other exceptions
   $cell->commandFailed - if the last command failed

=item * name (None): $name

Returns the name of this cell

=item * alive ($params): boolean

Returns true if the cell responded to the command, false otherwise. 
Pass C<{refresh => 1}> in order to execute a cell command to check if the 
cell responds, otherwise return the status of the pool when the last
command was executed. Pass C<{reset => 1}> in order to reset the state
(alive = 1).

=item * hasException (None): boolean

Returns true if the command execution comes across a general Exception, false otherwise.
Pass C<{reset => 1}> in order to reset the error.

=item * hasCacheException (None): boolean

Returns true if the command execution comes across a CacheException, false otherwise.
This usually happens with pool commands like C<rep ls pnfsid> when the pool does not 
actually host the pnfsid. Pass C<{reset => 1}> in order to reset the error.

=item * commandFailed (None): boolean
Pass C<{reset => 1}> in order to reset the error.

Returns true if the last command failed (relevant for the PnfsManager), false otherwise

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

The following are the known daughter classes of C<dCacheTools::Cell>

  dCacheTools::PoolManager
  dCacheTools::PnfsManager
  dCacheTools::Pool
  dCacheTools::GridftpCell
  dCacheTools::GridftpTransfer

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Cell.pm,v1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
