package dCacheTools::PnfsManager;

use strict;
use warnings;
use Carp;

use File::Basename;

use BaseTools::Util qw/trim readFile/;
use dCacheTools::Pool;

use base qw/Class::Singleton dCacheTools::Cell/;

sub _new_instance
{
  my $this = shift;
  my $class = ref $this || $this;
  my $self = $class->SUPER::new({ name => q|PnfsManager| });
  bless $self, $class;
}
sub pathfinder
{
  my ($self, $pnfsid) = @_;
  my @output = $self->exec({ command => q|pathfinder|, arg => $pnfsid }); 
  return undef unless ($self->alive and scalar @output);
  return undef if $self->hasException;
  trim $output[0];
}
sub pnfsidof
{
  my ($self, $pfn) = @_;
  my @output = $self->exec({ command => q|pnfsidof|, arg => $pfn }); 
  return undef unless $self->alive;
  return undef if $self->commandFailed;
  trim $output[0];
}
# now various ways of finding the file size
# return (status, size)
# if status is false, not point looking at size
sub stored_filesize 
{
  my ($self, $arg) = @_;
  my @output = $self->exec({ command => q|storageinfoof|, arg => $arg }); 
  return undef unless $self->alive;
  return undef if $self->commandFailed;
  my $size = (split /;/, $output[0])[0];
  $size =~ s/size=//; 
  trim $size;
} 
# Does not strictly belong to this class, but if pfn is specified
# we need the PnfsManager/pnfsidof
sub replica_filesize 
{
  my ($self, $params) = @_;
  # is poolname specified?
  carp q|poolname not specified in the input argument!| and return undef
    unless defined $params->{pool};

  # get a pnfsid with valid format 
  carp q|neither pnfsid nor pfn specified in the input argument!| and return undef
    unless (defined $params->{pfn} or defined $params->{pnfsid});

  my $pnfsid = $params->{pnfsid} || $self->pnfsidof($params->{pfn});
  return undef unless $pnfsid =~ /^[0-9A-F]{24,}$/;

  my $poolname = $params->{pool};
  my $pool = dCacheTools::Pool->new({ name => $poolname });
  return undef unless ($pool->enabled and $pool->active and $pool->alive);

  # Now ask the pool for the size
  $pool->filesize($pnfsid);
} 
sub pnfs_checksum
{
  my ($self, $params) = @_;
  $self->pnfs_attr('checksum', $params);
}
sub pnfs_filesize
{
  my ($self, $params) = @_;
  $self->pnfs_attr('size', $params);
}
sub pnfs_attr
{
  my ($self, $option, $params) = @_;

  carp q|neither pnfsid nor pfn specified in the argument!| and return undef
    unless (defined $params->{pfn} || defined $params->{pnfsid});

  # First of all get a pnfsid with valid format 
  my $pfn = $params->{pfn} || $self->pathfinder($params->{pnfsid});
  return undef unless (defined $pfn and $pfn =~ m#^/pnfs#);

  my $basename = basename $pfn;
  my $dir      = dirname $pfn;
  my $file     = sprintf '%s/.(use)(2)(%s)', $dir, $basename;

  my $ecode = 0;
  chomp(my @output = readFile($file, \$ecode));
  return undef if $ecode;

  @output = grep { /l=/ } @output;
  return undef if scalar @output != 1;
  
  #output example
  #2,0,0,0.0,0.0  
  #:al=NEARLINE;rp=CUSTODIAL;c=1:34ba5aea;l=2872293535;h=no;
  #cmsdcache1_2

  my $attr = undef;
  if ($option eq 'size') {
    $attr = (split /l=/, trim $output[0])[-1];
    $attr = (split /;/, $attr)[0];
  }
  elsif ($option eq 'checksum') {
    my $f = (split /;l=/, trim $output[0])[0];
    my @fields = (split /:/, trim $f);
    $attr = $fields[-1] if scalar @fields > 2;
  }
  else {
    warn qq|>>> PnfsManager: $option is not a supported tag!|;
  }
  ((defined $attr) ? trim $attr : $attr);
}
sub pools
{
  my ($self, $arg) = @_;
  my @output = $self->exec({ command => q|cacheinfoof|, arg => $arg }); 
  return () unless ($self->alive and scalar @output);
  return () if $self->commandFailed;
  (split /\s+/, trim $output[0]);
}
# The following are static methods
sub pfn2id
{
  my ($class, $pfn) = @_;
  my $basename = basename $pfn;
  my $dir      = dirname $pfn;
  my $file = sprintf '%s/.(id)(%s)', $dir, $basename;

  my $ecode = 0;
  chop(my $pnfsid = readFile($file, \$ecode));
  return undef if $ecode;
  trim $pnfsid;
}
# this may not be very useful as it shows only the basename
# moreover, you need to be somewhere under pnfs (e.g /pnfs/pi.infn/it/data)
sub id2pfn
{
  my ($class, $pnfsid) = @_;
  my $file = sprintf '.(nameof)(%s)', $pnfsid;

  my $ecode = 0;
  chop(my $pfn = readFile($file, \$ecode));
  return undef if $ecode;
  trim $pfn;
}

1;
__END__
package main;

my $pnfsid = shift || q|0008000000000000005652F8|;
my $pi = dCacheTools::PnfsManager->instance();

my @pools = $pi->pools($pnfsid);
print join (' ', "Pools: ", @pools), "\n";

my $filesize = $pi->stored_filesize($pnfsid);
print join(' ', "Stored Size: ", $filesize), "\n" if defined $filesize;

$filesize = $pi->pnfs_filesize({ pnfsid => $pnfsid });
print join(' ', "Pnfs size: ", $filesize), "\n" if defined $filesize;

for my $pool (@pools) {
  $filesize = $pi->replica_filesize({ pool => $pool, pnfsid => $pnfsid });
  print join(' ', $pool, " Size: ", $filesize), "\n" if defined $filesize;
}

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::PnfsManager - An OO interface over the PnfsManager cell 

=head1 SYNOPSIS

  use dCacheTools::PnfsManager;

  my $obj = dCacheTools::PnfsManager->instance();

  my $filesize = $obj->stored_filesize($pnfsid);
  print join(' ', "Stored Size: ", $filesize), "\n";

  $filesize = $obj->pnfs_filesize({ pnfsid => $pnfsid });
  print join(' ', "Pnfs size: ", $filesize), "\n";

  my @pools = $obj->pools($pnfsid);
  print join (' ', "Pools: ", @pools), "\n";

  for my $pool (@pools) {
    $filesize = $obj->replica_filesize({ pool => $pool, pnfsid => $pnfsid });
    print join(' ', $pool, " Size: ", $filesize), "\n";
  }

=head1 REQUIRES

  Class::Singleton
  dCacheTools::Cell
  dCacheTools::Pool

=head1 INHERITANCE

  Class::Singleton
  dCacheTools::Cell

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::PnfsManager> is a straight-forward wrapper over the PnfsManager cell implemented
as a Singleton. It also provides ways to execute global pnfs commands from Perl.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new (): object reference

Class constructor. 

=item * pathfinder (pnfsid): (pfn)

Given a pnfsid find the fully qualified Physical File name. $pfn is available if and only if
the status is valid. If the pnfsid is not known to the PnfsManager a CacheException is thrown.

=item * pnfsidof (pfn): (pnfsid)

Given a fully qualified Physical File name returns the pnfsid currently associated to it. If the pfn is
not available on pnfs, an exception is thrown from the Admin Console and we return an invalid status
which must be checked before looking at the output.

=item * stored_filesize (arg): (size)

Returns the size of a pfn or pnfsid. If the pfn or the pnfsid is not available returns an invalid
status which must be checked before using the value.

=item * replica_filesize (params): (size)

Returns the pool replica size of a pfn or pnfsid. If the pfn or the pnfsid is not available on the pool
returns an invalid status which must be checked before using the value.

=item * pnfs_filesize (params): (size)

Returns the size of a pfn or pnfsid that is known to pnfs. If the pfn/pnfsid does not exists returns an invalid
status which must be checked before using the value.

=item * pools (arg): string array

Returns a list of pools that hold replica copies of a pfn/pnfsid.

=back

=head2 Public static methods

=over 4

=item * pfn2id (class, pfn): pnfsid

Find the pnfsid associated with a Physical File Name (pfn). Call as

    my $pnfsid = dCacheTools::PnfsManager->pfn2id("/pnfs/pi.infn.it/data/cms/user/test/oneEvt.root");

=item * id2pfn (class, pnfsid): pfn

Find the Physical File Name (pfn) for a given pnfsid. Call as

    my $pfn = dCacheTools::PnfsManager->id2pfn("000800000000000001FC2F60");

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

dCacheTools::Admin

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: PnfsManager.pm,v1.3 2008/12/11 14:00:00 sarkar Exp $

=cut

# --- Documentation ends
