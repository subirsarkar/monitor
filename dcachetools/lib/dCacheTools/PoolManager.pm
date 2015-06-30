package dCacheTools::PoolManager;

use strict;
use warnings;
use Data::Dumper;
use Carp;
use List::Util qw/min max/;

use BaseTools::ConfigReader;
use BaseTools::Util qw/trim/;
use base qw/Class::Singleton dCacheTools::Cell/;

sub _new_instance 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $self = $class->SUPER::new({ name => q|PoolManager| });
  my $parse_all = (exists $attr->{parse_all}) ? $attr->{parse_all} : 1;
  my $verbose = $attr->{verbose} || 0;
  $self->{_parse_all} = $parse_all;
  $self->{_verbose}   = $verbose;

  bless $self, $class;
}
sub config
{
  my ($self, $attr) = @_;
  for my $key (sort keys %$attr) {
    $self->{"_$key"} = $attr->{$key};
  }
}
sub _initialize_pool
{
  my $self = shift;
  $self->{_poolinfo} = {};

  # Find the Pool names and acitivity report
  my $command = q|psu ls pool -l|;
  $command .= qq|\ncm ls -r| if $self->{_parse_all};
  my @lines = $self->exec({ command => $command });
  print STDERR join("\n", @lines), "\n" if $self->{_verbose};
  carp q|PoolManager may be dead!| 
    and return unless ($self->alive and not $self->hasException);
  carp qq|Command: $command failed!| and return unless scalar @lines;

  print STDERR qq|Start Parsing PoolManager command output\n| if $self->{_verbose};
  for (@lines) {
    if (/enabled/ and /active/) {
      my ($pool, $data) = (split /\s+/);
      $data =~ m/\((.*)\)/ or next;
      for my $pair ((split /;/, $1)) {
        my ($key, $value) = map { trim $_ } (split /=/, $pair);
        $self->{_poolinfo}{$pool}{$key} = $value;
      }
    }
    elsif ( /^(.*?)={Tag={.*hostname=(.*?)}};size=\d+;SC=(.*?);CC=(.*?);}/ ) {
      my ($pool, $host, $sc, $cc) = map { trim $_ } ($1, $2, $3, $4);
      $self->{_poolinfo}{$pool}{host}       = $host;
      $self->{_poolinfo}{$pool}{space_cost} = $sc;
      $self->{_poolinfo}{$pool}{perf_cost}  = $cc;
    }
    elsif ( /^(.*?)={R={(.*?)};S={(.*?)};M={(.*?)};PS={(.*?)};PC={(.*?)};SP={(.*?)};XM={(.*)};}/ ) {
      my ($pool, $restore, $store, $movers, $p2p_server, $p2p_client, $space, $xm) 
        = map { trim $_ } ($1, $2, $3, $4, $5, $6, $7, $8);
      $xm =~ s#(\d);#$1,#g; 
      my $list = [split /;/, $xm];
      print STDERR join ('/', $pool, @$list), "\n" if $self->{_verbose};
      $self->{_poolinfo}{$pool}{restores}      = $restore;
      $self->{_poolinfo}{$pool}{stores}        = $store;
      $self->{_poolinfo}{$pool}{movers}        = $movers;
      $self->{_poolinfo}{$pool}{p2p_server}    = $p2p_server;
      $self->{_poolinfo}{$pool}{p2p_client}    = $p2p_client;
      $self->{_poolinfo}{$pool}{space}         = $space;
      $self->{_poolinfo}{$pool}{client_movers} = $list;
    }
  }
  # information may still be missing for some pools. What to do?
  # some safeguard is needed
  if ($self->{_parse_all}) {
    for my $pool (sort keys %{$self->{_poolinfo}}) {
      $self->{_poolinfo}{$pool}{host}       = q|?| unless defined $self->{_poolinfo}{$pool}{host};
      $self->{_poolinfo}{$pool}{space_cost} = -1.0 unless defined $self->{_poolinfo}{$pool}{space_cost};
      $self->{_poolinfo}{$pool}{perf_cost}  = -1.0 unless defined $self->{_poolinfo}{$pool}{perf_cost};
    }
  }  
  print STDERR q|Parsing complete ...\n| if $self->{_verbose};
}
sub poolinfo
{
  my $self = shift;
  $self->_initialize_pool unless defined $self->{_poolinfo};
  $self->{_poolinfo};
}
sub show
{
  my $self = shift;
  my $poolinfo = $self->poolinfo; # lazy initialization
  printf qq|%14s %10s %14s %10s %14s %11s %11s\n|, 
      q|Pool|, q|Enabled|, q|Active|, q|Readonly|, q|host|, q|Space Cost|, q|Perf. Cost|;
  for my $pool (sort keys %$poolinfo) {
    my $fmt = ($self->is_enabled($pool) and $self->is_active($pool)) ? qq|%10.5e| : qq|%11.0f|;
    printf qq|%14s %10s %14s %10s %14s $fmt $fmt\n|, 
            $pool, 
            $self->is_enabled($pool),
            $self->is_active($pool),
            $self->is_readonly($pool),
            $self->host($pool),
            $self->space_cost($pool),
            $self->perf_cost($pool);
  }  
}
sub poollist 
{
  my $self = shift;
  my $poolinfo = $self->poolinfo; # lazy initialization
  sort keys %$poolinfo;
}
sub is_enabled 
{
  my ($self, $pool) = @_;
  my $poolinfo = $self->poolinfo; # lazy initialization
  (exists $poolinfo->{$pool}{enabled} and $poolinfo->{$pool}{enabled} eq 'true') ? 1 : 0;
}
sub is_active 
{
  my ($self, $pool) = @_;
  my $poolinfo = $self->poolinfo; # lazy initialization
  exists $poolinfo->{$pool}{active} or return 0;

  my $status = $poolinfo->{$pool}{active};
  $status =~ /\d+/ or return 0;

  my $reader = BaseTools::ConfigReader->instance();
  my $activityMarker = $reader->{config}{PoolManager}{activityMarker};
  ($status < $activityMarker) ? 1 : 0;
}
sub is_readonly 
{
  my ($self, $pool) = @_;
  my $poolinfo = $self->poolinfo; # lazy initialization
  (exists $poolinfo->{$pool}{rdOnly} and $poolinfo->{$pool}{rdOnly} eq 'true') ? 1 : 0;
}
sub host 
{
  my ($self, $pool) = @_;
  my $poolinfo = $self->poolinfo; # lazy initialization
  $poolinfo->{$pool}{host};
}
sub space_cost
{
  my ($self, $pool) = @_;
  my $poolinfo = $self->poolinfo; # lazy initialization
  max 0, $poolinfo->{$pool}{space_cost};
}
sub perf_cost
{
  my ($self, $pool) = @_;
  my $poolinfo = $self->poolinfo; # lazy initialization
  max 0, $poolinfo->{$pool}{perf_cost};
}
sub mover_info 
{
  my ($self, $pool, $type) = @_;
  my $poolinfo = $self->poolinfo; # lazy initialization
  my $info = {};
  if (defined $poolinfo->{$pool}{$type}) {
    my $tmap = 
    {
      a => q|active|,
      m => q|max|,
      q => q|queued|
    };
    if ($type eq 'client_movers') {
      my $list = $poolinfo->{$pool}{$type};
      for my $t (@$list) {
        if ( $t =~ m|(\w+)={\s?a=(-?\d+),m=(-?\d+),q=(-?\d+)\s?}| ) {
          my ($mover_type, $active, $max, $queued) = ($1,$2,$3,$4);
          print STDERR join(', ', $mover_type, $active, $max, $queued), "\n" if $self->{_verbose};
          $info->{$mover_type}{active} = max 0, $active;
          $info->{$mover_type}{max}    = max 0, $max;
          $info->{$mover_type}{queued} = max 0, $queued;
        }
      }
    }
    else {
      for (split /;/, $poolinfo->{$pool}{$type}) {
        my ($key, $value) = (split /=/);
        $info->{$tmap->{$key}} = max 0, $value;
      }
    }
  }
  else {
    carp qq|ERROR. mover_info: data for poolinfo for {$pool}{$type} not available!|;
  }
  $info;
}
sub space_info
{
  my ($self, $pool) = @_;
  my $poolinfo = $self->poolinfo; # lazy initialization
  my $info = {};
  if (defined $poolinfo->{$pool}{space}) {
    my $t = $poolinfo->{$pool}{space};
    $t =~ s/{//; $t =~ s/}//;
    my $tmap = 
    {
        t => q|total|,
        f => q|free|,
        p => q|precious|,
        r => q|recoverable|,
        g => q|gap|,
        b => q|breakeven|,
      lru => q|lru_age|   # least recently used file age
    };
    for (split /;/, $t) {
      my ($key, $value) = split /=/;
      $info->{$tmap->{$key}} = $value;
    }
  }
  else {
    carp qq|ERROR. mover_info: data for poolinfo for {$pool}{space} not available!|;
  }
  $info;
}
sub _initialize_pgroup
{
  my ($self, $pgList) = @_;
  $self->{_pgroupinfo} = {};

  #-readpref=10 -writepref=10 -cachepref=10 -p2ppref=-1
  #cms-link  (pref=10/10/-1/10;;ugroups=2;pools=1)
  for my $group (@$pgList) {
    my @output = $self->exec({ command => qq|psu ls pgroup -l $group| });
    my @links = grep { /(?:\w+)-link/ } @output;
    my $plinks = {};
    if (scalar @links) {
      my ($link, $value) = split /\s+/, $links[0];
      $plinks->{$link} = $value;
    }
    my @pools = grep { /enabled/ or /active/ } @output;
    my $pList = [];
    for (@pools) {
      my $poolname = (split)[0];
      push @$pList, $poolname;
    }
    $self->{_pgroupinfo}{$group}{pools} = $pList;
    $self->{_pgroupinfo}{$group}{links} = $plinks;
  }
}
sub pgroupinfo
{
  my ($self, $group) = @_;
  unless (defined $self->{_pgroupinfo}) {
    my $list = [$self->pgrouplist()];
    $self->_initialize_pgroup($list); 
  }

  (defined $self->{_pgroupinfo}{$group}) 
    ? $self->{_pgroupinfo}{$group}
    : $self->{_pgroupinfo};
}
sub pgrouplist 
{
  my $self = shift;

  # Find the Pool names and acitivity report
  my @poolgroups = $self->exec({ command => q|psu ls pgroup| });
  carp q|PoolManager may be dead!| and return [] unless $self->alive;

  @poolgroups;
}

1;
__END__
package main;
use Data::Dumper;

my $pm = dCacheTools::PoolManager->instance();
$pm->config({ parse_all => 1 });
$pm->show;

my @poolList = $pm->poollist;
for my $pool (@poolList) {
  print join(" ", $pool, $pm->host($pool), $pm->is_enabled($pool), $pm->is_readonly($pool)), "\n";
}

my $info = $pm->mover_info(q|cmsdcache1_2|, q|movers|);
print Data::Dumper->Dump([$info], [qw/movers/]);

$info = $pm->mover_info(q|cmsdcache1_2|, q|client_movers|);
print Data::Dumper->Dump([$info], [qw/client_movers/]);

$info = $pm->space_info(q|cmsdcache1_2|);
print Data::Dumper->Dump([$info], [qw/space/]);

# --- Documentation starts

=pod

=head1 NAME

dCacheTools::PoolManager - A Wrapper over the PoolManager cell

=head1 SYNOPSIS

  use Data::Dumper;
  use dCacheTools::PoolManager;

  my $pm = dCacheTools::PoolManager->instance();
  $pm->config({ parse_all => 1 });
  $pm->show;

  my @poolList = $pm->poollist;
  for my $pool (@poolList) {
    print join(" ", $pool, $pm->host($pool), $pm->is_enabled($pool), $pm->is_readonly($pool)), "\n";
  }

  my $info = $pm->mover_info(q|cmsdcache1_2|, q|movers|);
  print Data::Dumper->Dump([$info], [qw/movers/]);

  $info = $pm->mover_info(q|cmsdcache1_2|, q|client_movers|);
  print Data::Dumper->Dump([$info], [qw/client_movers/]);

  $info = $pm->space_info(q|cmsdcache1_2|);
  print Data::Dumper->Dump([$info], [qw/space/]);

=head1 REQUIRES

  Class::Singleton
  BaseTools::ConfigReader
  BaseTools::Util
  dCacheTools::Cell

=head1 INHERITANCE

  Class::Singleton
  dCacheTools::Cell

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::PoolManager> is Singleton that represents the PoolManager cell which 
collects a lot of useful information which is subsequently used by C<dCacheTools::Pool>

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new (None): object reference

=item * config ($attr): None

Set options

=item * poollist (None): @list

Returns the names of the pools known to the PoolManager as a list. The list may contain 
pools that are I<disabled> or I<inactive>. 

=item * show (None): None

Show a summary of the pool state and propereties

=item * is_enabled ($poolname): boolean

Returns true if $poolname is enabled in the PoolManager, false otherwise.

=item * is_active ($poolname): boolean

Returns true if $poolname is active in the PoolManager, false otherwise.

=item * is_readonly ($poolname): boolean

Returns true if $poolname is read-only in the PoolManager, false otherwise.

=item * host ($poolname): scalar

Returns the nodename that hosts $poolname

=item * space_cost ($poolname): scalar

Returns the current space cost for $poolname as calculated by the Cost Module

=item * perf_cost ($poolname): scalar

Returns the current performance cost for $poolname as calculated by the Cost Module

=item * space_info ($poolinfo): $info

Return the space info about $poolname which is known to the PoolManager.

  my $info = $pm->space_info(q|cmsdcache9_7|);
  print Data::Dumper->Dump([$info], [qw/space/]);
  $space = {
            'gap' => '4294967296',
        'lru_age' => '24046913',
           'free' => '1544911672697',
      'breakeven' => '0.7',
       'precious' => '1989824403616',
          'total' => '3543348019200',
    'recoverable' => '8611942887'
  };

=item * mover_info ($poolname, $type): $info

Return a reference to a hash that contains mover information for a certain type.

  my $info = $pm->mover_info(q|cmsdcache9_7|, 'movers');
  print Data::Dumper->Dump([$info], [qw/movers/]);
  $movers = {
       'max' => '8',
    'active' => '0',
    'queued' => '0'
  };

Available mover types are: 'movers', 'p2p_server', 'p2p_client', 'restore', 'store', 'client_movers'.
If you have separate mover queues for dcap, gridftp etc. $pm->mover_info(q|cmsdcache9_7|, 'client_movers')
will return a structure like the following,

  $client_movers = {
      'default' => {
             'max' => '4',
          'active' => '0',
          'queued' => '0'
      },
      'wan' => {
             'max' => '4',
          'active' => '0',
          'queued' => '0'
      }
  };


=item * pgroupinfo ($group): $info

Returns the underlying container. If no group is specified information for all the pgroups are
returned. 

=item * pgrouplist (None): @list

Returns an array of PoolGroups (name)

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::Pool
dCacheTools::PoolGroup

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: PoolManager.pm,v1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
