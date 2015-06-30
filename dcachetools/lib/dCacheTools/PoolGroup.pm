package dCacheTools::PoolGroup;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Term::ProgressBar;
use List::Util qw/min max/;

use BaseTools::ConfigReader;
use dCacheTools::PoolManager;
use dCacheTools::Pool;

use constant GB2BY => 1.0*(1024**3);

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  defined $attr->{name} or croak q|pgroup not specified|;
  my $verbose = $attr->{verbose} || 0;
  bless { 
       _name => $attr->{name}, 
    _verbose => $verbose
  }, $class;
}

sub _initialize
{
  my $self = shift;
  my $name = $self->{_name};

  my $pm = dCacheTools::PoolManager->instance();
  my $info  = $pm->pgroupinfo($name);
  my @pools = @{$info->{pools}};
  $self->{_info}{$_} = dCacheTools::Pool->new({ name => $_ }) for @pools;
}

sub poollist
{
  my $self = shift;
  my $info = $self->info;
  sort keys %$info;
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

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $mover_types = $config->{mover_types} || ['default','wan'];

  my @poollist = sort keys %$info;
  my $npools = scalar @poollist;
  my $ipool = 0;
  my $next_update = -1;
  my $progress = Term::ProgressBar->new({ name => sprintf (qq|Pools: %d, processed|, $npools), 
                                         count => $npools, 
                                        remove => 1, 
                                           ETA => 'linear' });
  $progress->minor(0);
  my ($g_total, $g_free, $g_precious) = (0,0,0);
  my $dict = {};
  my $it = max 1, int($npools/100);
  for my $pname (@poollist) {
    unless ((++$ipool)%$it) {
      $next_update = $progress->update($ipool) if $ipool >= $next_update;
    }
    my $pool = $info->{$pname};
    ($pool->enabled and $pool->active) or next;

    my $space_info = $pool->space_info;
    $g_total    += $space_info->{total};
    $g_free     += $space_info->{free};
    $g_precious += $space_info->{precious};
    $dict->{$pname} = [$pool->summary($mover_types)];
  }
  $progress->update($ipool) if $ipool > $next_update;
  printf qq/%51s|%43s|%32s|%22s|\n/, 
                                "---------------------- Pools ----------------------", 
                                "-------------------- Space -----------------", 
                                "------------- Movers ------------",
                                "--------- Cost --------";
  my $FORMAT = qq/%14s %-22s %8s %4s| %7s %7s %13s %13s| %9s %9s %6s %5s| %11s %11s\n/;
  my @headers = ('Name', 'Base directory', 'Mode', 'Stat', 'Totl(G)', 'Free(G)', 
               'Used(G|%)', 'Precious(G|%)', 'Lan', 'Wan', 'p2p-s', 'p2p-c', 'Space', 'Perf');
  printf $FORMAT, @headers;
  print @{$dict->{$_}}, "\n" for (sort keys %$dict);

  my $g_used = $g_total - $g_free;
  print "-----------------\nTotal\n-----------------\n";
  printf qq/%9s %9s %9s %9s\n/, "Totl(G)", "Free(G)", "Used(G)", "Prec(G)";
  printf qq/%9.1f %9.1f %9.1f %9.1f\n/, 
       $g_total/GB2BY,
       $g_free/GB2BY,
       $g_used/GB2BY,
       $g_precious/GB2BY;
}

1;
__END__
package main;

my $obj = dCacheTools::PoolGroup->new({ name => 'cms' });
$obj->show;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::PoolGroup - Collects information about a Pool Group

=head1 SYNOPSIS

  use dCacheTools::PoolGroup;
  my $obj = dCacheTools::PoolGroup->new({ name => 'cms'});
  $obj->show;

=head1 REQUIRES

  Carp
  Data::Dumper
  dCacheTools::PoolManager
  dCacheTools::Pool

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::PoolGroup> collect information about a Pool Group. It is  
built upon C<dCacheTools::PoolManager> and C<dCacheTools::Pool>.
The current implementation is incomplete in the sense that it only 
holds the space information but nothing about the links, ugroup etc.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{name} - Pool Group name

=item * info (None): $info

Returns the underlying container which is a hash reference

=item * show (None): None

Displays the information for the Pool Group a la poolinfo (style).

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::PoolManager
dCacheTools::Pool
dCacheTools::Space

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: PoolGroup.pm,v1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
