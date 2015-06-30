package dCacheTools::P2P;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use BaseTools::Util qw/trim parseInt/;
use dCacheTools::Pool;

our $AUTOLOAD;
my %fields = map { $_ => 1 }
    qw/serverid
       clientid
       clientpool
       status1
       status2
       pnfsid
       bytes_transferred
       duration
       rate
       lm
       filesize
       bytes_left
       time_left/;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|Neither the p2p ls input nor a valid pnfsid passed as input!| unless
      (defined $attr->{input} or defined $attr->{pnfsid});

  my $self = bless {
    _permitted => \%fields
  }, $class;

  $self->{_input}  = $attr->{input}  if defined $attr->{input};
  $self->{_pnfsid} = $attr->{pnfsid} if defined $attr->{pnfsid};
  $self->{_server} = $attr->{server} if defined $attr->{server};
  $self->{_client} = $attr->{client} if defined $attr->{client};

  $self->_initialize;
  $self;
}

sub update 
{
  my $self = shift;
  $self->initialize;
}
sub _initialize
{
  my $self = shift;
  my $input; 
  if (defined $self->{_input}) {
    $input = $self->{_input};
  }
  else {
    my $server = $self->{_server};
    my $pnfsid = $self->{_pnfsid};
    my @list = grep { /$pnfsid h=/ } $server->exec({ command => q|p2p ls| });
    croak q|P2P server pool dead!| unless $server->alive;

    carp qq|No valid P2P input found for pnfsid=$pnfsid!| and return unless scalar @list;
    carp qq|Multiple lines for the same pnfsid=$pnfsid, picking the first| if scalar @list > 1;
    $input = $list[0];
  }

  my ($serverid, $st1, $st2, $clientinfo, $pnfsid, $storageinfo, $bytes, $duration, $lm) 
    = (split /\s+/, trim $input);
  my ($clientpool, $domain, $seqid); 
  if ($clientinfo =~ m/{(.*)\@(.*):(\d+)}/) {
    ($clientpool, $domain, $seqid) = map { trim $_ } ($1,$2,$3);
  }
  $bytes    = parseInt($bytes, 'bytes=');
  $duration = parseInt($duration, 'time/sec=');
  $lm       = parseInt($lm, 'LM=');

  my $rate = ($duration > 0 and $bytes > 0) ? $bytes*1.0/$duration : 0;

  $self->{_info}{serverid}   = $serverid;
  $self->{_info}{pnfsid}     = $pnfsid;
  $self->{_info}{duration}   = $duration;
  $self->{_info}{lm}         = $lm;
  $self->{_info}{status1}    = $st1;
  $self->{_info}{status2}    = $st2;
  $self->{_info}{clientpool} = $clientpool;
  $self->{_info}{bytes_transferred} = $bytes;

  # set uninitialised
  $self->{_info}{filesize}   = -1;
  $self->{_info}{bytes_left} = -1;
  $self->{_info}{time_left}  = 10e+04;
  $self->{_info}{rate}       = 0;

  my $size;
  if (defined $self->{_server}) {
    my $server = $self->{_server};
    my $status;
    $size = $server->filesize($pnfsid);
  }
  else {
    # h={SM={a=1453163078;u=1453163078};S=None}
    if (defined $storageinfo and $storageinfo =~ /h={SM={a=(\d+);u=(\d+)};S=(?:.*)}/) {
      $size = $1;
    }
  }
  if (defined $size and $size > -1) {
    my $bytes_left = $size - $bytes;
    my $time_left  = ($rate) ? int($bytes_left/$rate) : 10e+04; 
    $self->{_info}{filesize}   = $size;
    $self->{_info}{bytes_left} = $bytes_left;
    $self->{_info}{time_left}  = $time_left;
  }
  $rate /= 1024;   # convert rate in KB/s
  $self->{_info}{rate} = $rate;

  # Now find the client id
  $self->{_info}{clientid} = -1;
  if (defined $pnfsid) {
    $self->{_client} = dCacheTools::Pool->new({ name => $clientpool }) 
       unless defined $self->{_client};
    my $client = $self->{_client};

    my @ppls = grep { /$pnfsid FSM/ } $client->exec({ command => q|pp ls| });
    if ($client->alive and scalar(@ppls) == 1) {
      my ($clientid) = (split /\s+/, $ppls[0])[0];
      $self->{_info}{clientid} = ($clientid =~ /\d+/) ? $clientid : -1;
    }
  }
}

# AUTOLOAD/carp fallout
sub DESTROY { }

sub waiting
{
  my $self = shift;
  
  carp q|Client pool information is not avialable| unless defined $self->{_client};
  ($self->status1 eq 'W' and $self->bytes_transferred <= 0);
}
sub stuck
{
  my ($self, $max_duration) = @_;
  defined $max_duration or $max_duration = 1200; # 20 minutes
  carp q|Client pool information is not avialable| unless defined $self->{_client};
  ($self->status1 eq 'A' and $self->bytes_transferred <= 0 and $self->duration >= $max_duration);
}
sub _info
{
  my $self = shift;
  $self->_initialize unless defined $self->{_info};  # lazy
  $self->{_info};
}

sub show
{
  my $self = shift;
  my $info = $self->_info;
  print Data::Dumper->Dump([$info], [qw/info/]);
}

sub stop
{
  my $self = shift;
  $self->cancel;
}

sub cancel
{
  my $self = shift;

  my $server = $self->{_server};
  my $client = $self->{_client};
  carp q|Server/Client Pool object reference not found!| and return unless ($server and $client);

  my $serverid = $self->serverid;
  my $clientid = $self->clientid;

  my $spool = $server->name;
  my $cpool = $client->name;
  carp qq|Invalid Server/Client IDs - $spool:$serverid, $cpool:$clientid!| 
    and return unless ($serverid>0 and $clientid>0);

  $client->exec({ command => qq|pp remove $clientid| });
  $server->exec({ command => qq|p2p kill $serverid -force| });
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
  (exists $info->{$name}) ? $info->{$name} : undef;
}

1;
__END__
package main;
use Math::BigInt;
my $input = q|1917 W H {cmsdcache13_26@cmsdcache13Domain:0} 0008000000000000098C51D0 h={SM=null;S=None} bytes=-1 time/sec=1288337196 LM=493|;
#my $input = q|1003 A H {cmsdcache14_18@cmsdcache14Domain:0} 000800000000000003B53B08 h={SM={a=1239331881;u=1239331881};S=None} bytes=831770220 time/sec=686 LM=686|;

my $obj = dCacheTools::P2P->new({ input => $input });
$obj->show;
print "isWaiting: ", ($obj->waiting ? 'yes' : 'no'), "\n";
print "  isStuck: ", ($obj->stuck ? 'yes' : 'no'), "\n";

my $bytes_left = $obj->bytes_left;
printf qq|Avg. Rate=%.2f KB/sec, remaining=%s bytes, approx. time left=%d sec\n|,
          $obj->rate,
          (Math::BigInt->new($bytes_left))->bstr,
          $obj->time_left;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::P2P - Parses the Pool C<p2p ls> and C<pp ls> output and combines them for a single P2P process

=head1 SYNOPSIS

  use dCacheTools::P2P;
  my $input = q|2122 W H {cmsdcache3_1@cmsdcache3Domain:0} 000800000000000001EB36A0 h={SM=null;S=None} bytes=-1 time/sec=0 LM=0|;
  my $obj = dCacheTools::P2P->new($input);
  $obj->show;

=head1 REQUIRES

  Data::Dumper
  BaseTools::Util
  dCacheTools::Pool

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::P2P> parses the Pool B<p2p ls> command output. It optionally
parses the client pool B<pp ls> output as well in order to associate 
transfers id on the server pool with that on the client pool. One can
then look at the information stored to decide if a P2P transfer is
(1) yet to start (2) going as expected (3) stuck and take an action
accordingly. All the accesssors are AUTOLOADed.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. There are two different sets of input that may be used to create an object. 
The first set is
   
    $attr->{input}  - p2p ls output for each transfer
    $attr->{server} - reference to the server pool object. Required if you want to stop a P2P process

while the second one is
    
    $attr->{pnfsid} - pnfsid of the file involved in the p2p transfer
    $attr->{server} - reference to the server pool object
    $attr->{client} - reference to the client pool object

=item * show (None): None

Display the information.

  print Data::Dumper->Dump([$info], [qw/info/]);

  $info = {
          'lm' => 0,
          'duration' => 0,
          'pnfsid' => '000800000000000001EB36A0',
          'rate' => '0',
          'clientid' => -1,
          'serverid' => '2122',
          'clientpool' => 'cmsdcache3_1',
          'bytes_transferred' => -1,
          'status1' => 'W'
        };

=item * waiting (None): boolean

Return true if the transfer is yet to start, false otherwise

=item * stuck (None): boolean

Return true if the transfer started but did not manage to move data, false otherwise

=item * cancel (None): None

Cancel the p2p transfer from both server and client sides

=item * stop (None): None

An alias to C<cancel> (for compatibility)

=item * serverid (None): $id

=item * clientid (None): $id

=item * pnfsid (None): $pnfsid

=item * bytes_transferred (None): $bytes

Bytes transferred so far.

=item * lm (None): $lm

=item * duration (None): $duration

The time span the transfer is on.

=item * rate (None): $rate

Transfer rate in KB/s.

=item * status1 (None): $status

=item * status2 (None): $status

=item * clientpool (None): $poolname

Client pool name

=item * Filesize (None): $size

File size at the source pool

=item * bytes_left (None): $bytes

Bytes still left to be transferred

=item * time_left (None): $time

Time left to completion of the transfer

=back 

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::Mover

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: P2P.pm,v 1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
