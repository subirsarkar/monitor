package dCacheTools::AdminSSH;

use strict;
use warnings;
use Carp;
use Time::HiRes qw/usleep/;

use BaseTools::ConfigReader;
use BaseTools::Util qw/trim getCommandOutput/;

use base 'Class::Singleton';

our $AUTOLOAD;
my %fields = map { $_ => 1 }
  qw/debug
     node
     timeout
     delay
     discard_error/;

sub _new_instance
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $reader = BaseTools::ConfigReader->instance();
  unless (defined $attr->{node}) {
    croak q|Admin node hostname is not specified even in the configuration file!|
      unless defined $reader->{config}{admin}{node};
    $attr->{node} = $reader->{config}{admin}{node};
  }
  # ConfigReader sets defaults value for the rest, in anyway
  $attr->{timeout}       = $reader->{config}{admin}{timeout}       unless defined $attr->{timeout};
  $attr->{delay}         = $reader->{config}{admin}{delay}         unless defined $attr->{delay};
  $attr->{debug}         = $reader->{config}{admin}{debug}         unless defined $attr->{debug};
  $attr->{discard_error} = $reader->{config}{admin}{discard_error} unless defined $attr->{discard_error};

  bless {
              _node => $attr->{node},
           _timeout => $attr->{timeout},
             _delay => $attr->{delay},
             _debug => $attr->{debug},
     _discard_error => $attr->{discard_error},
         _permitted => \%fields
  }, $class;
}

# AUTOLOAD/Carp fallout
sub DESTROY
{
  my $self = shift;
}

sub exec
{
  my ($self, $params) = @_;
  croak q|must specify a valid command in the dictionary!| 
     unless defined $params->{command};

  my $reader = BaseTools::ConfigReader->instance();
  my $ssh = $reader->{config}{SSH} || q|ssh -1|;
  my $script = qq|$ssh -c blowfish -p 22223 -l admin $self->{_node}|; 
  $script .= q| -o BatchMode=yes -o ConnectTimeout=10|; 
  $script .= qq| 2>/dev/null| if $self->{_discard_error}; # the leading space is important
  $script .= qq| <<EOF\nset timeout $self->{_timeout}\n|;
  $script .= (defined $params->{cell}) 
       ? qq|cd $params->{cell}\n$params->{command}|
       : qq|$params->{command}|;
  $script .= qq|\n..\nlogoff| unless $params->{command} =~ /logoff/;
  $script .= qq|\nEOF|;

  print $script, "\n" if $self->{_debug};
  usleep $self->{_delay} if $self->{_delay}>0; # microseconds

  my $ecode = 1;
  my $natt = 0;
  my @result = ();
  while ($ecode) {
    @result = getCommandOutput($script, \$ecode);
    print "\$ecode=$ecode\n" if ($ecode and $self->{_debug});
    last if ++$natt > 2;
  }
  my @output = ();
  for (@result) { 
    next if (/^$/ || length($_)<3 || /Timeout/ || /dmg/ || /admin >/ || /user=admin/);
    push @output, trim($_);
  }
  print join ("\n", @output), "\n" if $self->{_debug};
  $self->{_cellAlive}    = (grep /No Route to cell for packet/, @output) ? 0 : 1;
  $self->{_timedOut}     = (grep /Request timed out/, @output) ? 1 : 0;
  $self->{_hasException} = (grep /Exception/, @output) ? 1 : 0;

  @output;
}

sub cell_alive
{
  my $self = shift;
  $self->{_cellAlive};
}

sub hasException
{
  my $self = shift;
  $self->{_hasException};
}
sub timedOut
{
  my $self = shift;
  $self->{_timedOut};
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
    unless exists $self->{_permitted}{$name};

  if (@_) {
    return $self->{"_$name"} = shift;
  } 
  else {
    return ((defined $self->{"_$name"}) ? $self->{"_$name"} : undef);
  }
}

1;
__END__
package main;
my $admin = dCacheTools::AdminSSH->instance();
my @output = $admin->exec({ cell => q|PoolManager|, command => qq|psu ls pool -l\npsu ls pgroup| });
print join ("\n", @output);

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::AdminSSH - An OO wrapper over the dCache Admin Console, a singleton

=head1 SYNOPSIS

    use dCacheTools::AdminSSH; 
    my $admin = dCacheTools::AdminSSH->instance();
    my @output = $admin->exec({ cell => "PoolManager", command => "psu ls pool -l" });
    print join ("\n", @output);

One can also form a long command string and use it as follows,

    use dCacheTools::AdminSSH; 
    my $admin = dCacheTools::AdminSSH->instance(); 
    my $command = qq|cd cmsdcache1_1\nrep ls\n..\ncd cmsdcache2_1\nrep ls|;
    my @output = $admin->exec({ command => $command });
    print join ("\n", @output);

=head1 REQUIRES

  Carp
  Time::HiRes
  Class::Singleton
  BaseTools::ConfigReader
  BaseTools::Util

=head1 INHERITANCE

  Class::Singleton

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::AdminSSH is an OO interface over the dCache Admin Console which helps automate 
administrative tasks. The interface has been implemented following a Singleton pattern.

As the Admin Console supports only the SSH-v1 protocol each command execution has to connect 
to and disconnect from the admin console. Implementation of C<dCacheTools::AdminSSH> is therefore 
very straight-forward. An implementaiton based on C<Net::SSH::Perl> will be ready for any 
future improvement of the underlying Admin Console. An alternative implementation may try 
to use the Java API via the C<Inline::Java> interface.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * instance ($attr): object reference

Class constructor. Does not connect to the dCache Admin Console but just sets up the environment

    $attr->{node}            - dCache Admin host name
    $attr->{timeout}         - Specify timeout value on the Console
    $attr->{delay}           - when the Admin Console is accessed from within a loop, might be 
                               useful to introduce a delay
    $attr->{debug}           - debug flag
    $attr->{discard_error}   - if enabled redirect stderr to /dev/null

The application wide config file specifies the default value for all the above attributes
which is used in case a attribute is not specified when constructing the Admin object. The default
values are specified in the config file as follows,

    admin => {
                 node => q|cmsdcache|,
              timeout => 300,
                debug => 0,
                delay => 2000, # microseconds
        discard_error => 1
    };

=item * exec ($params): @list

Execute an Admin console command and return the output as a list

    $params->{cell}   - The dCache cell
    $param->{command} - The command to execute

=item * cell_alive (None): boolean

Check if the cell for the last command is alive. Clears the error on look-up.

=item * hasException (None): boolean

Check if the last command succeeded. check for general Exceptions only.
Clears the error on look-up.

=item * node ($node): $node

Set/get the Admin node name

=item * debug ($debug): $debug

Set/get the debug flag

=item * timeout ($timeout): $timeout

Set/get the Admin console command response timeout interval

=item * delay ($interval): $interval

Set/get the delay before execution of a command

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::PoolManager etc.

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Admin.pm,v 1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
