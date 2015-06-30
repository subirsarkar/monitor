package dCacheTools::Mover;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use BaseTools::Util qw/trim parseInt/;

our $AUTOLOAD;
my %fields = map { $_ => 1 }
   qw/id
      status1
      status2
      pnfsid
      door
      domain
      seqid
      bytes
      duration
      rate
      lm/;

sub new
{
  my ($this, $ls) = @_;
  my $class = ref $this || $this;
  bless {
        _input => $ls, 
    _permitted => \%fields
  }, $class;
}

sub moverls
{
  my $self = shift;
  if (@_) {
    delete $self->{_info};
    return $self->{_input} = shift;
  } 
  else {
    return $self->{_input};
 }
}
sub _normalize
{
  my ($value, $patt) = @_;
  return -1 unless (defined $value and $value);
  $value =~ s#$patt##;
  parseInt($value);
}
sub _initialize
{
  my $self = shift;
  my $input = $self->{_input};
  my ($id, $st1, $st2, $dinfo, $pnfsid, $sinfo, $bytes, $duration, $lm) 
     = (split /\s+/, trim $input);
  my ($door, $domain, $seqid) = ('?','?',-1);
  if ($dinfo =~ m/{(.*)\@(.*):(-?\d+)}/) {
    ($door, $domain, $seqid) = map { trim $_} ($1,$2,$3);
  }

  $bytes    = parseInt($bytes, 'bytes=');
  $duration = parseInt($duration, 'time/sec=');
  $lm       = parseInt($lm, 'LM=');

  my $rate = ($duration > 0) ? $bytes*1.0/$duration : 0;
  $rate /= 1024;     # convert rate in KB/s
  $self->{_info} = 
  {
          id => $id,
        door => $door,
      domain => $domain,
       seqid => $seqid,
      pnfsid => $pnfsid,
       bytes => $bytes,
    duration => $duration,
          lm => $lm,
        rate => $rate,
     status1 => $st1,
     status2 => $st2
  };
}

# AUTOLOAD/carp fallout
sub DESTROY
{
  my $self = shift;
}

sub _info
{
  my $self = shift;
  $self->_initialize unless exists $self->{_info};  # lazy
  $self->{_info};
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
    unless exists $self->{_permitted}{$name};

  my $info = $self->_info;
  (exists $info->{$name} ? $info->{$name} : undef);
}

sub show
{
  my $self = shift;
  my $info = $self->_info;
  print Data::Dumper->Dump([$info], [qw/info/]);  
}

1;
__END__
package main;
my $input = q|11561 A H {GFTP-cmsdcache7-Unknown-109@gridftp-cmsdcache7Domain:10007} 000800000000000001F79888 h={SU=1682243584;SA=1730150400;S=None} bytes=1680146432 time/sec=6224 LM=0|;
my $obj = dCacheTools::Mover->new($input);
$obj->show;
print $obj->rate, "\n";

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::Mover - Parses the Pool C<mover ls> output for a single C<pnfsid>

=head1 SYNOPSIS

  use dCacheTools::Mover;
  my $input = q|11561 A H {GFTP-cmsdcache7-Unknown-109@gridftp-cmsdcache7Domain:10007} 000800000000000001F79888 h={SU=1682243584;SA=1730150400;S=None} bytes=1680146432 time/sec=6224 LM=0|;
  my $obj = dCacheTools::Mover->new($input);
  $obj->show;

=head1 REQUIRES

  Data::Dumper
  BaseTools::Util

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::Mover is there for convenience. It parses the Pool B<mover ls> command output
and provides setter methods to get individual fields. All the accesssor are AUTOLOADed.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($input): object reference

Class constructor. 

    $input - mover ls output for for each mover (C<pnfsid>)

=item * show (None): None

Display the information.

  print Data::Dumper->Dump([$info], [qw/info/]);

  $info = {
           'bytes' => 1680146432,
           'lm' => 0,
           'duration' => 6224,
           'pnfsid' => '000800000000000001F79888',
           'seqid' => '10007',
           'rate' => '263.619537275064',
           'id' => '11561',
           'domain' => 'gridftp-cmsdcache7Domain',
           'status2' => 'H',
           'door' => 'GFTP-cmsdcache7-Unknown-109',
           'status1' => 'A'
	};

=item * id (None): $id

=item * pnfsid (None): $pnfsid

=item * bytes (None): $bytes

=item * lm (None): $lm

=item * duration (None): $duration

=item * rate (None): $rate

=item * door (None): $door

=item * domain (None): $domain

=item * seqid (None): $seqid

=item * status1 (None): $status

=item * status2 (None): $status

=back 

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::TransferStatus

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Mover.pm,v 1.0 2008/06/19 14:03:00 sarkar Exp $

=cut

# --- Documentation ends
