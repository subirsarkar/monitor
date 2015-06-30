package dCacheTools::Pool;

use strict;
use warnings;
use Carp;

use BaseTools::Util qw/trim/;
use dCacheTools::PoolManager;
use dCacheTools::Replica;
use base 'dCacheTools::Cell';

use constant GB2BY => 1.0*(1024**3);

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|No pool name specified| unless defined $attr->{name};

  my $self = $class->SUPER::new({ name => $attr->{name} });
  bless $self, $class;
}

sub exec
{
  my ($self, $params) = @_;
  $params->{retry} = 0 unless defined $params->{retry};
  $self->SUPER::exec($params);
}
sub info
{
  my $self = shift;
  $self->{_info} = {};
  my @result = $self->exec({ command => q|info -l|, retry => 1 });
  return unless $self->alive;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $mover_types = $config->{mover_types} || ['default','wan'];
  my $tlan = $mover_types->[0];
  my $twan = $mover_types->[1];

  for my $line (@result) {
    if ($line =~ /Mover\s+Queue\s+\($tlan\)/) {
      $line = __PACKAGE__->_movers($line, "Movers(lan)", "%2d|%2d|%3d"); 
    }
    elsif ($line =~ /Mover\s+Queue\s+\($twan\)/) {
      $line = __PACKAGE__->_movers($line, "Movers(wan)", "%d|%d|%d"); 
    }
    elsif ($line =~ /P2P\s+Queue/) {
      $line = __PACKAGE__->_movers($line, "Movers(p2p)", "%d|%d|%d"); 
    }
    elsif ($line =~ /Max\s+Active/) {
      $line = join(":", "Movers(pp)", (split /:/, $line)[-1]); 
    }
    my @pair = map { trim $_ } (split /:/, $line);
    next if scalar(@pair) != 2;
    $self->{_info}{$pair[0]} = $pair[1];
  }
}

sub summary
{
  my ($self, $moverList) = @_;

  my $reader = BaseTools::ConfigReader->instance();
  my $config = $reader->{config};
  my $mover_types = $config->{mover_types} || ['default','wan'];

  my @info = (
     sprintf (qq/%14s/,   $self->{_name}), 
     sprintf (qq/ %-22s/, $self->path), 
     sprintf (qq/ %8s/,   $self->mode), 
     sprintf (qq/ %4s|/,  $self->status),
  );

  my $space_info = $self->space_info;
  push @info, q|--- Failed to collect further information for pool |. $self->name . q| ---|
    and return @info unless scalar(keys %$space_info);

  my $totl_space = $space_info->{total} / GB2BY;
  my $free_space = $space_info->{free}  / GB2BY;
  my $used_space = $space_info->{total} - $space_info->{free};
  $used_space /= GB2BY;
  my $prec_space = $space_info->{precious} / GB2BY;
  my $used_frac  = $used_space*100.0/$totl_space;
  my $prec_frac  = ($used_space) ? $prec_space*100.0/$used_space : 0;
  push @info, 
     sprintf (qq/ %7.1f %7.1f %6.1f[%5.1f] %6.1f[%5.1f]|/, 
         $totl_space, $free_space, $used_space, $used_frac, $prec_space, $prec_frac);

  my $mover_info = $self->mover_info('client_movers');
  for my $m (@$moverList) {
    next unless  defined $mover_info->{$m};    
    my $active = $mover_info->{$m}{active};
    my $max    = $mover_info->{$m}{max};
    my $queued = $mover_info->{$m}{queued};
    my $wd = ($m eq $mover_types->[1]) ? 9 : 10; 
    push @info, sprintf(qq|%10s|, sprintf(qq# %d/%d/%d|#, $active, $max, $queued));
  }
  my $ps_info = $self->mover_info('p2p_server');
  my $pc_info = $self->mover_info('p2p_client');
  push @info, sprintf (qq# %d/%d/%d|#, $ps_info->{active}, $ps_info->{max}, $ps_info->{queued}),
              sprintf (qq# %d/%d/%d|#, $pc_info->{active}, $pc_info->{max}, $pc_info->{queued}),
              sprintf (qq# %5.3e#, $self->space_cost),
              sprintf (qq# %5.3e#, $self->perf_cost);
  @info;
}

sub online
{
  my $self = shift;
  ($self->enabled and $self->active);
}
sub mode
{
  my $self = shift;
  ($self->enabled) ? 'enabled' : 'disabled';
}

sub status
{
  my $self = shift;
  ($self->readonly) ? 'ro' : 'rw';
}

sub enabled 
{
  my $self = shift;
  my $pool = $self->{_name};
  my $pm   = dCacheTools::PoolManager->instance();
  $pm->is_enabled($pool);
}

sub active
{
  my $self = shift;
  my $pool = $self->{_name};
  my $pm   = dCacheTools::PoolManager->instance();
  $pm->is_active($pool);
}

sub readonly
{
  my $self = shift;
  my $pool = $self->{_name};
  my $pm   = dCacheTools::PoolManager->instance();
  $pm->is_readonly($pool);
}

sub host
{
  my $self = shift;
  my $pool = $self->{_name};
  my $pm   = dCacheTools::PoolManager->instance();
  $pm->host($pool);
}

sub space_cost 
{
  my $self = shift;
  my $pool = $self->{_name};
  my $pm   = dCacheTools::PoolManager->instance();
  $pm->space_cost($pool);
}

sub perf_cost
{
  my $self = shift;
  my $pool = $self->{_name};
  my $pm   = dCacheTools::PoolManager->instance();
  $pm->perf_cost($pool);
}

sub space_info
{
  my $self = shift;
  my $pool = $self->{_name};
  my $pm   = dCacheTools::PoolManager->instance();
  $pm->space_info($pool);
}

sub mover_info
{
  my ($self, $type) = @_;
  my $pool = $self->{_name};
  my $pm   = dCacheTools::PoolManager->instance();
  $pm->mover_info($pool, $type);
}

sub path
{
  my $self = shift;
  $self->info unless defined $self->{_info};
  $self->{_info}{'Base directory'} || '?';
}

sub filesize
{
  my ($self, $pnfsid) = @_;
  my @output = $self->exec({ command => qq|rep ls $pnfsid| });
  return undef if ($self->hasCacheException or !scalar(@output));

  (dCacheTools::Replica->new($output[0]))->size;
}

sub precious
{
  my ($self, $pnfsid, $set) = @_;
  $self->exec({ command => qq|rep set precious $pnfsid -force| }) if defined $set;
  return undef if $self->hasCacheException;

  my @output = $self->exec({ command => qq|rep ls $pnfsid| });
  return undef if ($self->hasCacheException or !scalar(@output));

  (dCacheTools::Replica->new($output[0]))->precious;
}

sub _movers
{
  my ($pkg, $line, $tag, $format) = @_;
  my $value = (split /\s+/, $line)[-1];
  $value =~ s#\(#|#;
  $value =~ s#\)/#|#;
  my ($active, $max, $queued) = split /\|/, $value;
  join (':', $tag, sprintf $format, $active, $max, $queued);
}

1;
__END__
package main;

my $pname = shift || q|cmsdcache1_1|;
my $pool = dCacheTools::Pool->new({ name =>  $pname});
print join(' ', $pool->summary(['wan','default'])), "\n";

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::Pool - provides information about a single pool and allows execution of pool commands

=head1 SYNOPSIS

  use dCacheTools::Pool;

  my $pool = dCacheTools::Pool->new({ name => q|cmsdcache1_2| });
  die q|Pool disabled! stopped| unless $pool->enabled;
  $pool->exec({ command => q|info -l| });

=head1 REQUIRES

  BaseTools::Util qw/trim/
  dCacheTools::PoolManager
  dCacheTools::Cell

=head1 INHERITANCE

  dCacheTools::Cell

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::Pool> provides information about a single pool and a hook for pool command
execution. The class uses the information gathered by C<dCacheTools::PoolManager> and provides
an OO interface. For example, the Pool object itself knows if it is enabled and active in
the PoolManager, which are the various movers associated to this Pool, space and performance
costs etc. 

Immediately after executing a pool command one can check if the command failed because
the pool was temporarily unavailable, due to exception etc. All the methods are
described in some detail in the corresponding sections.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. Requires a hash reference that must contain

  $attr->{name} - name of the pool

=item * info

Parses the pool C<info -l> command output and adds the information to the object itself
for further processing. Much of the information obtained this way overlap
with those obtained through the PoolManager.

Access the information as a hash reference as 

  my $info = $pool->{info}

=item * exec ($params): @output

Overrides the parent method so that pool commands are not retried by default.

=item * summary ([@options]): @list

Prepares a summary line for this pool. If separate queues are defined for
dcap and gridftp transfers, the input array reference should provide the names
of the queues. 

Returns an array that contains formatted strings and values which can just be
fed to a C<printf>.

=item * mode (None): $mode

Returns a string saying if a pool is enabled/disabled

=item * status (None): $status

Returns a string saying if a pool is read-only/read-write

=item * enabled (None): boolean

Returns true if this pool is enabled in the PoolManager, false otherwise.

=item * active (None): boolean

Returns true if this pool is active in the PoolManager, false otherwise.

=item * readonly (None): boolean

Returns true if this pool is read-only in the PoolManager, false otherwise.

=item * host (None): $host

Returns the nodename that hosts this pool.

=item * space_cost (None): $cost

Returns the current space cost for this pool as calculated by the Cost Module

=item * perf_cost (None): $cost

Returns the current performance cost for this pool as calculated by the Cost Module

=item * space_info (None): $info

Return the space info about this pool which is known to the PoolManager.

  my $info = $pool->space_info;
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

=item * mover_info ($type): $info

Return a reference to a hash that contains mover information for a certain type.

  my $info = $pool->mover_info('movers');
  print Data::Dumper->Dump([$info], [qw/movers/]);
  $movers = 
  {
       'max' => '8',
    'active' => '0',
    'queued' => '0'
  };

Available mover types are: 'movers', 'p2p_server', 'p2p_client', 'restore', 'store', 'client_movers'.
If you have separate mover queues for dcap, gridftp etc. C<$pool->mover_info('client_movers')>
will return a structure like the following,

  $client_movers = 
  {
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

=item * path (None): $path

Returns the base directory for the pool. The pool command C<info -l> is parsed on demand.

=item * filesize ($pnfsid): tuple

Returns the (status, replica size) tuple for a pnfsid.  
The size is available only if the status is valid.

=item * precious ($pnfsid, $set): boolean

Either set pnfsid as precious or check if a pnfsid is precious

=back

=cut

#------------------------------------------------------------
#                      Private Methods/Functions
#------------------------------------------------------------

=pod

=head2 Private methods

=over 4

=item * _movers

Extracts mover info from 'info -l' output

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::PoolManager

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Pool.pm,v1.3 2008/12/11 16:00:00 sarkar Exp $

=cut

# --- Documentation ends
