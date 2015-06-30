package BaseTools::ConfigReader;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Class::Singleton;

use base 'Class::Singleton';

my $configFile = (exists $ENV{DCACHETOOLS_CONFIG_DIR}) 
           ? qq|$ENV{DCACHETOOLS_CONFIG_DIR}/config.pl| 
           : qq|etc/config.pl|;

sub _new_instance
{
  my $this = shift;
  my $class = ref $this || $this;

  # read the configuration file
  my $config;
  unless ($config = do $configFile) {
    croak qq|Failed to parse $configFile: $@| if $@;
    croak qq|Failed to do $configFile: $!| unless defined $config;
    croak qq|Failed to run $configFile| unless $config;
  }
  # this will avoid croak-ing in case the config file does not have all the information
  $config->{admin}{timeout}       = 300 unless exists $config->{admin}{timeout};
  $config->{admin}{delay}         =  -1 unless exists $config->{admin}{delay};
  $config->{admin}{debug}         =   0 unless exists $config->{admin}{debug};
  $config->{admin}{discard_error} =   1 unless exists $config->{admin}{discard_error};

  bless {config => $config}, $class;
}

sub show
{
  my $self = shift;
  my $config = $self->{config};
  print Data::Dumper->Dump([$config], [qw/cfg/]); 
}

sub config
{
  my $self = shift;
  $self->{config};
}

1;
__END__

package main;

my $reader = BaseTools::ConfigReader->instance();
$reader->show;

# -- Documentation starts

=pod

=head1 NAME

C<BaseTools::ConfigReader> - A singleton object that makes it easy for other 
classes to access the application wide configuration.

=head1 SYNOPSIS

  use BaseTools::ConfigReader;
  my $reader = BaseTools::ConfigReader->instance();
  my $admin_node = $reader->{config}{admin}{node};
  # show the content
  $reader->show;

=head1 REQUIRES

Data::Dumper

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<BaseTools::ConfigReader> is a singleton class that reads the application wide 
configuration file which is written in Perl itself and holds the hash reference 
that contains the configuraiton information. The configuration file should return 
the hash reference as the last line like in the following example,

  our $cfg =
  {
      admin => {
                 node => qq|cmsdcache|,
              timeout => 300,
                debug => 0,
                delay => 2000,
        discard_error => 1
      }
  };
  $cfg->{PoolManager} =
  {
    activityMarker => 1000
  };
  $cfg;

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * instance (None): object reference

Access the singleton object reference using this static (package level) method. The 
first time it is accessed in an application the object is created and subsequently 
the same object is accessed. Since it is supposed to be a read-only object even 
simultaneous access does not require any special requirement.

=item * show (None): None

Dump the configuration information.

=back 

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

L<dCacheTools::Admin>, L<dCacheTools::PoolManager>

=head1  AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: ConfigReader.pm,v1.3 2008/12/11 14:03:19 sarkar Exp $

=cut

# --- Documentation ends
