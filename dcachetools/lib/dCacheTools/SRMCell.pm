package dCacheTools::SRMCell;

use strict;
use warnings;

use BaseTools::ConfigReader;
use BaseTools::Util qw/trim/;
use base 'dCacheTools::Cell';

sub new {
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  unless (defined $attr->{srmnode}) {
    my $reader = BaseTools::ConfigReader->instance();
    $attr->{srmnode} = $reader->{config}{admin}{node} 
  }
  my $self = $class->SUPER::new({ name => q|SRM-|.$attr->{srmnode} });
  bless $self, $class;
}

sub _initialize
{
  my $self = shift;
  $self->{_info} = {};
  my @result = $self->exec({ command => q|info -l| });
  return unless $self->alive;

  for (@result) {
    my @pair = map { trim $_ } (split /=/);
    next unless scalar @pair == 2;
    my $key   = $pair[0];
    my $value = $pair[1];
    next if $key =~ /!!!/;
    $key = join '_', (split /\s+/, $key);
    $self->{_info}{$key} = $value;
  }
}

sub info
{
  my $self = shift;
  $self->_initialize unless defined $self->{_info};
  $self->{_info};
}

sub show
{
  my $self = shift;
  my $info = $self->info;
  print Data::Dumper->Dump([$info], [qw/info/]);
}

sub summarise
{
  my $self = shift;
  my $info = $self->info; # lazy initialization
  my @keyw = ('totalSpace',
              'usedSpace',
              'availableSpace');

  use constant TB2BY => 1024**4;
  my $FORMAT = "%13s%13s%13s\n";
  printf $FORMAT, 'Total', 'Used','Free';
  my @coll;
  for my $key (@keyw) {
    my $value = $info->{$key};
    $value = (split /\s+/, $value)[0];
    $value /= TB2BY; # Byte to TB
    $value = sprintf "%8.1f TB", $value;
    push @coll, $value;
  }
  printf $FORMAT, @coll;
}

1;
__END__

package main;

use strict;

my $obj = dCacheTools::SRMCell->new;
$obj->summarise;
$obj->show;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::SRMCell - parses the dCache SRM cell B<info -l> command

=head1 SYNOPSIS

  my $obj = dCacheTools::SRMCell->new;
  $obj->summarise;
  $obj->show;

=head1 REQUIRES

  BaseTools::ConfigReader
  BaseTools::Util

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::SRMCell> parses the dCache SRM cell B<info -l> command

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{srmnode} - specify in case the srmnode is different from the admin node

=item * info (None): $info

Return the underlying hash that holds all the information

=item * summarise (None): None

Display the summary information as the following

        Total         Used         Free
   53456.9 GB   14216.3 GB   39549.6 GB

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

$Id: SRMCell.pm,v1.0 2008/06/17 00:03:19 sarkar Exp $

=cut

# --- Documentation ends
