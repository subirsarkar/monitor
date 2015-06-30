package dCacheTools::Space;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use BaseTools::ConfigReader;
use WebTools::Page;

sub new
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  unless (defined $attr->{webserver}) {
    my $reader = BaseTools::ConfigReader->instance();
    croak q|webserver is not specified even in the configuration file!| 
      unless defined $reader->{config}{webserver};
    $attr->{webserver} = $reader->{config}{webserver};
  }
  my $self = bless {
     _webserver => $attr->{webserver}
  }, $class;
  $self->{_pgroup} = $attr->{pgroup} if defined $attr->{pgroup};
  $self;
}

sub webserver
{
  my ($self, $value) = @_;
  $self->{_webserver} = $value if defined $value;
  $self->{_webserver};
}

sub pgroup
{
  my ($self, $value) = @_;
  $self->{_pgroup} = $value if defined $value;
  $self->{_pgroup} || '?';
}

sub reset
{
  my $self = shift;
  delete $self->{_pgroup} if exists $self->{_pgroup};
}

sub _fetch
{
  my $self = shift;
  my ($query, $count);
  if (defined $self->{_pgroup}) {
    $query = sprintf qq|http://%s:2288/pools/list/PoolManager/%s/spaces/|, 
      $self->{_webserver}, $self->{_pgroup};
    $count = 3;
  }
  else {
    $query = sprintf qq|http://%s:2288/usageInfo|, $self->{_webserver};
    $count = 0;
  }
  my $h = WebTools::Page->Table({ url => $query, count => $count });
  $self->{_rows} = $h;
}

sub rows
{
  my $self = shift;
  $self->_fetch; # should be called each time rows are returned
  $self->{_rows};
}

# total usage by a VO
sub getUsage
{
  my $self = shift;
  my @rows = @{$self->rows};
  shift @rows; # remove header
  
  my ($g_total, $g_free, $g_precious) = (0,0,0);
  for my $row (@rows) {
    next unless scalar @$row > 5;
    my $total    = $row->[2];
    my $free     = $row->[3];
    my $used     = $total - $free;
    my $precious = $row->[4];

    $g_total    += $total;
    $g_free     += $free;
    $g_precious += $precious;
  }
  my $g_used = $g_total - $g_free;
  {
       total => $g_total,
       used  => $g_used,
       free  => $g_free,
    precious => $g_precious
  };
}

sub show
{
  my $self = shift;
  my @rows = @{$self->rows};
  shift @rows; # remove header
  
  if (defined $self->{_pgroup}) {
    print "-------------------------------\nSpace info for pgroup $self->{_pgroup}\n-------------------------------\n";
  }
  else {
    print "---------------------\nDisk Space Usage\n---------------------\n";
  }

  use constant GB2MB => 1024.0;
  use constant TB2MB => 1.0*1024**2;
  printf "%16s %20s %9s %9s %9s %11s\n", 
     q|Pool|, q|Domain|, q|Total(G)|, q|Free(G)|, q|Used(G)|, q|Precious(G)|;
  my $FORMAT = qq|%16s %20s %9.1f %9.1f %9.1f %11.1f\n|; 

  my ($g_total, $g_free, $g_precious) = (0,0,0);
  for my $row (@rows) {
    next unless scalar @$row > 5;
    my $poolname = $row->[0];
    my $domain   = $row->[1];
    my $total    = $row->[2];
    my $free     = $row->[3];
    my $used     = $total - $free;
    my $precious = $row->[4];

    $g_total    += $total;
    $g_free     += $free;
    $g_precious += $precious;
    printf $FORMAT, 
       $poolname, $domain, $total/GB2MB, $free/GB2MB, $used/GB2MB, $precious/GB2MB;
  }
  my $g_used = $g_total - $g_free;
  printf $FORMAT, 
    "SUM (TB)", "-", $g_total/TB2MB, $g_free/TB2MB, $g_used/TB2MB, $g_precious/TB2MB;
}

1;
__END__
package main;
my $obj = dCacheTools::Space->new({ webserver => 'cmsdcache' });
$obj->show;

# Now for a Pool group
$obj->pgroup('cms');
$obj->show;

# --- Documentation starts
=pod

=head1 NAME

dCacheTools::Space - Parses the dCache B<Usage Info> tables available on the dCache monitor, 
either for the whole system or for a particular Pool group.

=head1 SYNOPSIS

  use dCacheTools::Space;
  my $obj = dCacheTools::Space->new({ webserver => 'cmsdcache', pgroup => 'cms'});
  $obj->show;

  # reset to global
  $obj->reset;
  $obj->show;

=head1 REQUIRES

  Carp
  WebTools::Page

=head1 INHERITANCE

none.

=head1 EXPORTS

none.

=head1 DESCRIPTION

dCacheTools::Space extracts and parses the dCache B<Usage Info> table embedded in
http://<webserver>:2288/usageInfo or in 
http://<webserver>:2288/pools/list/PoolManager/<pgroup>/spaces/
and stores in a data structure that can be easily used by other tools. 

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=head2 Public methods

=over 4

=item * new ($attr): object reference

Class constructor. 

    $attr->{webserver} - dCache web server host
    $attr->{pgroup}    - Pool Group name

=item * show (None): None

Display the information as a formatted dump,

=item * webserver ($webserver): $webserver

Setter/getter of $webserver. 

=item * pgroup ($pgroup): $pgroup

Setter/getter of $pgroup. 

  my $obj = dCacheTools::Space->new({ webserver => 'cmsdcache' });
  $obj->pgroup('cms');
  $obj->show;

=item * rows (None): $rows

Returns the array reference that holds the table

=back

=cut

#------------------------------------------------------------
#                      Other doc
#------------------------------------------------------------

=pod

=head1 SEE ALSO

WebTools::Page

=head1 AUTHORS

Subir Sarkar (subir.sarkar@cern.ch)

=head1 COPYRIGHT

This software comes with absolutely no warranty whatsoever.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 VERSION

$Id: Space.pm,v 1.0 2008/06/21 00:25:00 sarkar Exp $

=cut

# --- Documentation ends
