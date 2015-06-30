package BaseTools::FileList;

use strict;
use warnings;
use Carp;
use File::Find;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  croak q|No path specified!| unless defined $attr->{path};
  bless {
          _path => $attr->{path}, 
       _verbose => (exists $attr->{verbose}) ? $attr->{verbose} : 0, 
         _strip => (exists $attr->{strip})   ? $attr->{strip} : 0, 
     _traversed => 0
  }, $class;
}

sub path 
{ 
  my ($self, $value) = @_;
  if (defined $value) {
    $self->{_path}      = $value;
    $self->{_traversed} = 0;
  }
  $self->{_path};
}

sub verbose 
{ 
  my ($self, $value) = @_;
  $self->{_verbose} = $value if defined $value;
  $self->{_verbose};
}

sub strip
{ 
  my ($self, $value) = @_;
  $self->{_strip} = $value if defined $value;
  $self->{_strip};
}

sub traverse
{
  my $self = shift;
  my $path = $self->{_path};
  delete $self->{_info} if exists $self->{_info};
  $self->{_info} = {};
  my $traversal = sub
  {
    my $file = $File::Find::name;
    $file =~ s#$path##i if $self->{_strip};
    -f and $self->{_info}{$file}++;
  };
  find $traversal, $path;
  $self->{_traversed} = 1;
}

sub show
{
  my $self = shift;
  my $files = $self->files;
  print join ("\n", @$files), "\n";
}

sub info
{
  my $self = shift;
  print $self->{_path}, ",", 
        $self->{_traversed}, ",", 
       (exists $self->{_info} ? 1 : 0), "\n" if $self->{_verbose};
  $self->traverse unless (exists $self->{_info} and $self->{_traversed});
  $self->{_info};
}

sub files
{
  my $self = shift;
  my $info = $self->info;
  [sort keys %$info];
}

1;
__END__
my $list = BaseTools::FileList->new({ path => q|/pnfs/pi.infn.it/data/cms/store/users|, verbose => 1 });
$list->show;

$list->path(qq|/pnfs/pi.infn.it/data/cms/store/PhEDEx_LoadTest07|);
$list->show;

# --- Documentation starts

=pod

=head1 NAME

BaseTools::FileList - A frontend to C<File::Find>

=head1 SYNOPSIS

  use BaseTools::FileList;
  my $list = BaseTools::FileList->new({ path => q|/pnfs/pi.infn.it/data/cms/store/users|, verbose => 1 });
  $list->show;

  $list->path(q|/pnfs/pi.infn.it/data/cms/store/PhEDEx_LoadTest07|);
  $list->show;

=head1 REQUIRES

File::Find

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

BaseTools::FileList gathers all the files under a base path recursively using C<File::Find>
and fills a hash with filename as key. We use a hash instead of an array in order to support any 
future development where the value for a key may contains more information about a file.

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{path}    - must be specified
    $attr->{verbose} - debug flag

=item * show (None): None

Dump the filelist

=item * info ($info): $info

Get the underlying hash reference whose keys are the filenames

=item * files ($strip): $files

Returns a reference to an array that holds the files found. One can optionally
strip the base path, important to compare with the PhEDEx list.

=item * traverse (None): None

Use File::Find to traverse the base path and fill the underlying container
with the file list found

=item * path ($path): $path

Set/get base path

=item * verbose ($verbose): $verbose

Set/get verbose mode

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

File::Find

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: FileList.pm,v 1.0 2008/06/17 00:03:19 sarkar Exp $

=cut

# --- Documentation ends
