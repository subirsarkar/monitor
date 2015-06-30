package dCacheTools::GridftpTransfer;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use BaseTools::ConfigReader;
use BaseTools::Util qw/trim/;
use base 'dCacheTools::Cell';

our $AUTOLOAD;

my %fields = map { $_ => 1 }
  qw/certificate
     remote_host
     local_host
     method
     filename
     queue
     seqid
     pnfsid
     pool
     status
     moverid
     duration/;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|Gridftp transfer door not specified!| unless defined $attr->{name};

  my $self = $class->SUPER::new({ name => $attr->{name} });
  $self = bless $self, $class;  
  $self->{_permitted} = \%fields;
  $self->_initialize;
  $self;
}

sub _initialize
{
  my $self = shift;
  $self->{_info} = {};

  # info
  my @result = map { trim $_ } $self->exec({ command => q|info| });
  ($self->alive and scalar @result) or return;
  shift @result; # the first line is not important

  my $certificate = $result[0];
  my $remote_host = (split /:/, $result[1])[-1];
  my $local_host  = (split /:/, $result[2])[-1];
  $local_host     = (split /\./, $local_host)[0];
  my $last_cmd    = trim((split /:/, $result[3])[-1]);
  my $method      = (split /\s+/, $last_cmd)[0];
  my $filename = '?';
  if ($method =~ /ERET/) {
     $filename = (split /\s+/, $last_cmd)[4];
  }
  elsif ($method =~ /PUT/) {
    $filename = (split /\s+/, $last_cmd)[-1];
    $filename =~ s/path=//;
    $filename =~ s/;?pasv;?//;
  }
  else {
    $filename = (split /\s+/, $last_cmd)[-1];
  }
  my $reader = BaseTools::ConfigReader->instance();
  my $pnfsroot = $reader->{config}{pnfsroot};
  $filename =~ s#//#/#;
  $filename =~ s#$pnfsroot##;
  my $queue  = (split /:/, $result[5])[-1];
  
  $self->{_info}{certificate} = $certificate;
  $self->{_info}{remote_host} = $remote_host;
  $self->{_info}{local_host}  = $local_host;
  $self->{_info}{method}      = $method;
  $self->{_info}{filename}    = $filename;
  $self->{_info}{queue}       = $queue;

  my ($seqid, $pnfsid, $pool, $status, $moverid, $duration) = (-1,'?','?','?',-1,-1);

  # door info
  @result = $self->exec({ command => q|get door info| });
  $self->alive or return;
  scalar @result or return;
  
  if (scalar @result > 1) {
    my ($rhost, $msg);
    ($seqid, $pnfsid, $rhost, $pool, $msg, $duration) = map { trim $_} (split /;/, $result[-1]);
    eval {
      $duration /= 1000; # convert to seconds
    };
    $duration = -1 if $@;
    ($moverid, $status) = map { trim $_ } (split /:/, $msg);
    $moverid =~ s#mover\s+##;;
  }
  $self->{_info}{seqid}    = $seqid;
  $self->{_info}{pnfsid}   = $pnfsid;
  $self->{_info}{pool}     = $pool;
  $self->{_info}{status}   = $status;
  $self->{_info}{moverid}  = $moverid;
  $self->{_info}{duration} = $duration;
}

sub header
{
  my $pkg = shift;
  printf qq#%26s|%12s|%6s|%6s|%24s|%13s|%6s|%10s|%9s|%72s|%-s|\n#,
     q|RemoteHost|, 
     q|LocalHost|, 
     q|Method|, 
     q|Seqid|, 
     q|Pnfsid|, 
     q|Pool|, 
     q|Mover|, 
     q|Duration/s|, 
     q|Status|, 
     q|Certificate|, 
     q|Filename|;
}

sub _info
{
  my $self = shift;
  $self->{_info};
}

sub dump 
{
  my $self = shift;
  my $info = $self->_info;
  print Data::Dumper->Dump([$info], [qw/info/]);
}

sub show {
  my $self = shift;
  printf qq#%26s|%12s|%6s|%6d|%24s|%13s|%6d|%10d|%9s|%72s|%-s|\n#,
           $self->remote_host,
           $self->local_host,
           $self->method,
           $self->seqid,
           $self->pnfsid,
           $self->pool,
           $self->moverid,
           $self->duration,
           $self->status,
           $self->certificate,
           $self->filename;
}

sub AUTOLOAD 
{
   my $self = shift;
   my $type = ref $self or croak qq|$self is not an object|;

   my $name = $AUTOLOAD;
   $name =~ s/.*://;   # strip fully-qualified portion

   croak qq|Failed to access $name field in class $type| 
     unless exists $self->{_permitted}->{$name};

   my $info = $self->_info;
   (exists $info->{$name}) ? $info->{$name} : undef;
}

# AUTOLOAD/Carp fallout
sub DESTROY
{
  my $self = shift;
}

1;
__END__
package main;

my $door = shift || q|GFTP-cmsdcache1-Unknown-2368|;
my $obj = dCacheTools::GridftpTransfer->new({ name => $door });
dCacheTools::GridftpTransfer->header();
$obj->show;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::GridftpTransfer - A wrapper for individual Gridftp transfer door

=head1 SYNOPSIS

  my $door = shift || q|GFTP-cmsdcache1-Unknown-2368|;
  my $obj = dCacheTools::GridftpTransfer->new({ name => $door });
  dCacheTools::GridftpTransfer->header();
  $obj->show;

=head1 REQUIRES

  BaseTools::ConfigReader;
  BaseTools::Util
  dCacheTools::Cell

=head1 INHERITANCE

  dCacheTools::Cell

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::GridftpTransfer is a simple wrapper over an single Gridftp transfer door
which parses and combines the door C<info> and C<get door info> command output.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{name} - the Gridftp door name [obligatory]

=item * show (None): None

Display the door information.

=item * certificate (None): $certificate

=item * remote_host (None): $remote_host

=item * local_host  (None): $local_host

=item * method (None): $method

=item * filename (None): $filename

=item * queue (None): $queue

=item * seqid (None): $seqid

=item * pnfsid (None): $pnfsid

=item * pool (None): $pool

=item * status (None): $status

=item * moverid (None): $moverid

=item * duration (None): $duration

=item * dump (None): None

Dump the underlying data structure with

    print Data::Dumper->Dump([$info], [qw/info/]);  

    $info = {
          'local_host' => 'cmsdcache5',
          'remote_host' => 'lcgfts01.gridpp.rl.ac.uk',
          'status' => 'receiving',
          'certificate' => '/C=IT/O=INFN/OU=Personal Certificate/L=Sns/CN=Federico Calzolari',
          'duration' => '683.261',
          'pnfsid' => '00080000000000000208B030',
          'seqid' => '11434',
          'moverid' => '11571',
          'filename' => '/cms/store/PhEDEx_LoadTest07/LoadTest07_Debug_RAL/Pisa/140/LoadTest07_RAL_1B_GIXxuSqPenUyer4A_140',
          'pool' => 'cmsdcache9_4',
          'method' => 'STOR',
          'queue' => 'wan'
	  };


=item * header (None): None

A static method that provides a header for I<show>

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::GridftpCell

=head1 AUTHORS

  Sonia Taneja (sonia.taneja@pi.infn.it)
  Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: GridftpTransfer.pm,v 1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
