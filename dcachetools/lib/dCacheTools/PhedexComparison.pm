package dCacheTools::PhedexComparison;

use strict;
use warnings;
use Carp;

use IO::File;

use BaseTools::ConfigReader;
use BaseTools::FileList;
use WebTools::PhedexSvc;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  $attr->{verbose}         = 0 unless defined $attr->{verbose};
  $attr->{pnfs_dump}       = q|pnfs_files.txt| unless defined $attr->{pnfs_dump};
  $attr->{pnfsonly_dump}   = q|pnfsonly_files.txt| unless defined $attr->{pnfsonly_dump};
  $attr->{phedex_dump}     = q|phedex_files.txt| unless defined $attr->{phedex_dump};
  $attr->{phedexonly_dump} = q|phedexonly_files.txt| unless defined $attr->{phedexonly_dump};

  my $reader = BaseTools::ConfigReader->instance();
  defined $attr->{pnfsroot} or $attr->{pnfsroot} = $reader->{config}{pnfsroot};
  defined $attr->{node} or $attr->{node} = $reader->{config}{node};

  bless {attr => $attr}, $class;
}

sub compare
{
  my $self = shift;

  # phedex file list
  my $params = { node => $self->{attr}{node} };
  $params->{complete} = $self->{attr}{complete} if defined $self->{attr}{complete};
  my $phsvc = WebTools::PhedexSvc->new({ verbose => $self->{attr}{verbose} });
  $phsvc->options($params);

  my $phedexInfo = $phsvc->files;
  $self->{phedex_info} = $phedexInfo;
  my @phedex_files = sort keys %$phedexInfo;

  # dump in a file
  __PACKAGE__->save(\@phedex_files, $self->{attr}{phedex_dump});

  # dump pnfs file list
  my $pnfsH = BaseTools::FileList->new({ 
                              path => $self->{attr}{pnfsroot}, 
                             strip => 1,
                           verbose => $self->{attr}{verbose} });
  my $pnfsInfo = $pnfsH->info;  
  $self->{pnfs_info} = $pnfsInfo;
  my @pnfs_files = sort keys %$pnfsInfo;

  # dump in a file
  __PACKAGE__->save(\@pnfs_files, $self->{attr}{pnfs_dump});

  # find pnfs only files
  my $list = [];
  for my $file (@pnfs_files) {
    push @$list, $file unless exists $phedexInfo->{$file};
  }
  $self->{pnfsonly} = $list;
  __PACKAGE__->save($list, $self->{attr}{pnfsonly_dump});

  # now find phedex only files
  $list = [];
  for my $file (@phedex_files) {
    push @$list, $file unless exists $pnfsInfo->{$file};
  }
  $self->{phedexonly} = $list;
  __PACKAGE__->save($list, $self->{attr}{phedexonly_dump});
}

sub save 
{
  my ($class, $list, $file) = @_;
  my $fh = IO::File->new($file, 'w');
  croak qq|Failed to open $file, $!| unless ($fh && $fh->opened);
  print $fh join ("\n", @$list), "\n";
  $fh->close;
}

1;
__END__
package main;
my $obj = dCacheTools::PhedexComparison->new({
              node => q|T2_IT_Pisa|,
          pnfsroot => q|/pnfs/pi.infn.it/data/cms|, # cannot go further inside 
         pnfs_dump => q|pnfs_files.txt|,
     pnfsonly_dump => q|pnfsonly_files.txt|,
       phedex_dump => q|phedex_files.txt|,
   phedexonly_dump => q|phedexonly_files.txt|,
           verbose => 0
});
$obj->compare;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::PhedexComparison - Compare PhEDEx subscription list with the files locally
available on pnfs.

=head1 SYNOPSIS

  use dCacheTools::PhedexComparison;
  my $obj = dCacheTools::PhedexComparison->new({
                node => q|T2_IT_Pisa|,
            pnfsroot => q|/pnfs/pi.infn.it/data/cms|, # cannot go further inside
           pnfs_dump => q|pnfs_files.txt|,
       pnfsonly_dump => q|pnfsonly_files.txt|,
         phedex_dump => q|phedex_files.txt|,
     phedexonly_dump => q|phedexonly_files.txt|,
             verbose => 0
  });
  $obj->compare;


=head1 REQUIRES

  IO::File;
  BaseTools::FileList
  WebTools::PhedexFiles

=head1 INHERITANCE

none

=head1 EXPORTS

none.

=head1 DESCRIPTION

C<dCacheTools::PhedexComparison> compares the local (pnfs) file list with
what PhEDEx thinks a site should have. After the analysis several files
are produced that contain the result. 

B<phedexonly_files.txt> contains a list of files that are no longer
available locally but PhEDEx subscription is still valid, this list
of files must be invalidated in TMDB.

B<pnfsonly_files.txt> is a list of files which available locally and
not know to locally. This may also contains files that were long
deleted from PhEDEx but somehow managed to survive locally. One
should check the list carefully and delete the spurious entries
manually.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. The following attributes are used

  $attr->{node}            - PhEDEx node (e.g T2_IT_Pisa)
  $attr->{pnfsroot}        - The basepath of pnfs, list all the files under this path (e.g /pnfs/pi.infn.it/data/cms/store)
  $attr->{verbose}         - debug flag
  $attr->{pnfs_dump}       - complete list of files known to pnfs
  $attr->{pnfsonly_dump}   - file known only locally and not to PhEDEx
  $attr->{phedex_dump}     - complete list of files PhEDEX has record of for a site 
  $attr->{phedexonly_dump} - list of file known to PhEDEx but do not exist locally

=item * compare (None): None

Perform PhEDEx vs pnfs comparison. Save the results in 4 different files for 
further actions to be taken.

=item * save ($class, $list, $file): None

Save the list in a file

  $class - The package name
  $list  - an array reference that contains the list of files
  $file  - output file name

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

BaseTools::FileList, WebTools::PhedexFiles

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: PhedexComparison.pm,v 1.0 2008/06/17 00:03:19 sarkar Exp $

=cut

# --- Documentation ends
