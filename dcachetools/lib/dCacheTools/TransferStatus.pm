package dCacheTools::TransferStatus;

use strict;
use warnings;
use Carp;
use Math::BigInt;

use BaseTools::MyStore;
use dCacheTools::PoolManager;
use dCacheTools::Pool;
use dCacheTools::PnfsManager;
use dCacheTools::Mover;

our $AUTOLOAD;
my %fields = map { $_ => 1 }
   qw/moverid
      status1
      status2
      pool
      cell
      domain
      seqid
      bytes
      duration
      lm
      filename/;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|Transfer type not specified| unless defined $attr->{type};
  unless (defined $attr->{dbfile}) {
    my $reader = BaseTools::ConfigReader->instance();
    my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};
    $attr->{dbfile} = qq|$cacheDir/pnfsid2pfn.db|;
  }
  my $self = bless { 
       _dbfile => $attr->{dbfile}, 
         _type => $attr->{type},
    _permitted => \%fields
  }, $class;
  $self->_initialize;
  $self;
}

# AUTOLOAD/Carp fallout
sub DESTROY
{
  my $self = shift;
}
sub _initialize
{
  my $self = shift;
  my $transferType = $self->{_type};
  my $dbfile       = $self->{_dbfile};
  $self->{_info} = {};

  my $store = BaseTools::MyStore->new({ dbfile => $dbfile });
  my $pnfsH = dCacheTools::PnfsManager->instance();
  my $pm    = dCacheTools::PoolManager->instance();

  my @poollist = $pm->poollist;
  for my $poolname (@poollist) {
    my $pool = dCacheTools::Pool->new({ name => $poolname });
    next unless ($pool->enabled && $pool->active);
    print ">>> Processing $poolname\n";

    my @output = grep { /$transferType/ } $pool->exec({ command => q|mover ls| });
    next unless $pool->alive;

    foreach my $output (@output) {
      my $mi = dCacheTools::Mover->new($output);
      my $pnfsid = $mi->pnfsid;
      my ($status_ok, $pfn);
      if ( $store->contains($pnfsid) ) {
        $pfn = $store->get($pnfsid);
      }
      else {
        $pfn = $pnfsH->pathfinder($pnfsid);
        $pfn = '?' unless defined $pfn;
      }
      $self->{_info}{$pnfsid}{pool}      = $poolname;
      $self->{_info}{$pnfsid}{moverid}   = $mi->id;
      $self->{_info}{$pnfsid}{status1}   = $mi->status1;
      $self->{_info}{$pnfsid}{status2}   = $mi->status2;
      $self->{_info}{$pnfsid}{cell}      = $mi->door;
      $self->{_info}{$pnfsid}{domain}    = $mi->domain;
      $self->{_info}{$pnfsid}{seqid}     = $mi->seqid;
      $self->{_info}{$pnfsid}{bytes}     = $mi->bytes;
      $self->{_info}{$pnfsid}{duration}  = $mi->duration;
      $self->{_info}{$pnfsid}{lm}        = $mi->lm;
      $self->{_info}{$pnfsid}{filename}  = $pfn;
    } 
  }
}

sub pnfsids
{
  my $self = shift;
  my $info = $self->{_info};
  sort keys %$info;
}

sub show {
  my $self = shift;
  printf qq|%6s %5s %13s %24s %28s %26s %22s %10s %8s %6s %s\n|,
        q|Mover|, 
        q|State|, 
        q|Pool|, 
        q|Pnfsid|, 
        q|Cell|, 
        q|Domain|, 
        q|Seqid|, 
        q|Bytes|, 
        q|Time|, 
        q|lm|, 
        q|Filename|;
  
  for my $id ($self->pnfsids) {
    my $sid = Math::BigInt->new($self->seqid($id));
    printf qq|%6d %5s %13s %24s %28s %26s %22s %10s %8d %6d %s\n|,
             $self->moverid($id),
      	     join(' ', $self->status1($id), $self->status2($id)),
             $self->pool($id),
             $id,
             $self->cell($id),
             $self->domain($id),
             $sid->bstr(),
             $self->bytes($id),
             $self->duration($id),
             $self->lm($id),
             $self->filename($id);
  }
}

sub AUTOLOAD 
{
  my ($self, $pnfsid) = @_;
  croak q|pnfsid must be specified| unless defined $pnfsid;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
    unless exists $self->{_permitted}{$name};

  (exists $self->{_info}{$pnfsid}{$name}
    ? $self->{_info}{$pnfsid}{$name} 
    : undef);
}

1;
__END__
package main;

my $transferType = shift || q|dcap-cmsdcdcap|;
my $obj = dCacheTools::TransferStatus->new({ type => $transferType });
$obj->show;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::TransferStatus - Summarises status of each type of transfer

=head1 SYNOPSIS

  use dCacheTools::TransferStaaus;
  my $transferType = shift || q|dcap-cmsdcdcap|;
  my $obj = dCacheTools::TransferStatus->new({ type => $transferType });
  $obj->show;

=head1 REQUIRES

  BaseTools::MyStore
  dCacheTools::PoolManager
  dCacheTools::Pool
  dCacheTools::PnfsManager

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTool::TransferStatus> loops of over all the pools, executes B<mover ls> and
collects information for a type of transfer, namely dcap, gridftp, RemoteGsiftpTransfer
etc. The information collected here should be combined with that found in individual
doors in case we want to prepare a comprehensive report similar to what is found
on the dCache monitor.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{type}  - type of transfer; Options: dcap, gridftp, RemoteGsiftpTransfer [obligatory]
    $attr->{dbfile} - a cache of pnfsid->pfn mapping

=item * show (None): None

Display the information.

=item *  moverid($pnfsid): $moverid

=item *  status1($pnfsid): $status1

=item *  status2($pnfsid): $status2

=item *     pool($pnfsid): $pool

=item *     cell($pnfsid): $cell

=item *   domain($pnfsid): $domain

=item *    seqid($pnfsid): $seqid

=item *    bytes($pnfsid): $bytes

=item * duration($pnfsid): $duration

=item *       lm($pnfsid): $lm

=item * filename($pnfsid): $filename

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

$Id: TransferStatus.pm,v1.3 2008/12/11 14:03:19 sarkar Exp $

=cut

# --- Documentation ends
