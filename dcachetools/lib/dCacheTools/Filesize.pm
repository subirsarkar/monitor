package dCacheTools::Filesize;

use strict;
use warnings;
use Carp;

use BaseTools::ConfigReader;
use BaseTools::MyStore;
use dCacheTools::PnfsManager;

our $AUTOLOAD;
my %fields = map { $_ => 1 }
   qw/pnfsid
      pfn
      pnfssize
      storedsize
      replicas/;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|Must specify the fileid parameter (pnfsid or pfn)| 
    unless defined $attr->{fileid};
  my $self = bless {
       _fileid => $attr->{fileid}, 
     _usecache => $attr->{use_cache} || 0,
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
  my $pnfsH = dCacheTools::PnfsManager->instance();

  my $reader = BaseTools::ConfigReader->instance();
  my $cacheDir = $reader->{config}{cache_dir} || $ENV{PWD};
  my $dbfile = qq|$cacheDir/pnfsid2pfn.db|;
  my $store = BaseTools::MyStore->new({ dbfile => $dbfile });

  my ($pnfsid, $pfn);
  if ($self->{_fileid} =~ m#^/pnfs/#) {
    $pfn = $self->{_fileid};
    $pnfsid = dCacheTools::PnfsManager->pfn2id($pfn);
    croak qq|Error. pfn2id failed for $pfn!| unless defined $pnfsid;
  }
  else {
    $pnfsid = $self->{_fileid};
    if ( $self->{_usecache} and $store->contains($pnfsid) ) {
      $pfn = $store->get($pnfsid);
    }
    else {
      $pfn = $pnfsH->pathfinder($pnfsid);
      defined $pfn or $pfn = '?';
    }
  }
  croak qq|Error. invalid PNFSID format $pnfsid!| unless $pnfsid =~ /^[0-9A-F]{24,}$/;

  my $size_stored = $pnfsH->stored_filesize($pnfsid);
  defined $size_stored or $size_stored = -1;

  my $size_pnfs = $pnfsH->pnfs_filesize({ pnfsid => $pnfsid });
  defined $size_pnfs or $size_pnfs = -1;

  my $replicas = {};
  for my $pool ($pnfsH->pools($pnfsid)) {
    my $size_repl = $pnfsH->replica_filesize({ pool => $pool, pnfsid => $pnfsid });
    defined $size_repl or $size_repl = -1;
    $replicas->{$pool} = $size_repl;
  }
  $self->{_info} = {
        pnfsid => $pnfsid,
           pfn => $pfn,
    storedsize => $size_stored,
    pnfssize   => $size_pnfs,
    replicas   => $replicas
  };    
}

sub info
{
  my $self = shift;
  $self->{_info};
}

sub show
{
  my $self = shift;
  my $output = q|Size:|;

  $output .= sprintf qq| stored=%D|, $self->storedsize;
  $output .= sprintf qq| pnfs=%D|, $self->pnfssize;

  my $replicas = $self->replicas;
  for my $pool (sort keys %$replicas) {
    $output .= qq| $pool=$replicas->{$pool}|;
  }
  print join(' ', $output, $self->pnfsid, $self->pfn), "\n";
}

sub AUTOLOAD 
{
  my $self = shift;
  my $type = ref $self or croak qq|$self is not an object|;

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  croak qq|Failed to access $name field in class $type| 
    unless exists $self->{_permitted}{$name};

  (exists $self->{_info}{$name}) ? $self->{_info}{$name} : undef;
}

1;
__END__
package main;

my $fileid = shift || q|00080000000000000114F9A8|;
my $obj    = dCacheTools::Filesize->new({ fileid => $fileid });
$obj->show; 

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::Pool - Find the size of a file in all possible ways known to dCache

=head1 SYNOPSIS

  use dCacheTools::Filesize;
  my $fileid = shift; # must be a valid pnfsid/pfn
  my $obj    = dCacheTools::Filesize->new({ fileid => $fileid });
  $obj->show; 

=head1 REQUIRES

  BaseTools::MyStore
  dCacheTools::PnfsManager

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::Filesize is a class that holds all the information about the size of a pnfsid/pfn.
This includes the size stored in the PnfsManager, the various pool replica size and the one 
known to pnfs. 

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. Requires a hash reference that must contain a C<fileid> parameter.

=item * pnfssize (None): $size

Returns filesize known to pnfs

=item * storedsize (None): $size

Returns filesize known to the PnfsManager

=item * replicas (None): $replicas

Returns a hash reference that contains the pool replica size.

  $replicas = {
              'cmsdcache2_4' => 24953011,
              'cmsdcache9_6' => 24953011
            };

=item * show (None): None

Formats and dumps all the above information in a single line.

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::PnfsManager

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Filesize.pm,v 1.3 2008/12/11 14:00:00 sarkar Exp $

=cut
# --- Documentation ends
