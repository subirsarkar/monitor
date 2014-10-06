package LSF::Groups;

use strict;
use warnings;
use Data::Dumper;
use LSF::Util qw/trim commandFH/;

use base 'Class::Singleton';

sub _new_instance
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;
  my $verbose = $attr->{verbose} || 0;

  my $info = {};
  my $command = q|bugroup -w|;
  my $fh = commandFH($command, $verbose);
  if (defined $fh) {
    $fh->getline; # ignore header line
    while (my $line = $fh->getline) {
      my ($group, @users) = (split /\s+/, trim($line));
      for (@users) {
        my $list = [];
        if (exists $info->{$_}) {
          $list = $info->{$_};
        }
        push @$list, $group; 
        $info->{$_} = $list;        
      }
    }
    $fh->close;
  }
  bless {
    _info => $info
  }, $class;
}
sub info
{
  my $self = shift;
  $self->{_info};
}

sub show
{
  my $self = shift;
  my $info = $self->info;
  print Data::Dumper->Dump([$info], [qw/info/]); 
}

1;
__END__
package main;
my $obj = LSF::Groups->instance({ verbose => 1 });
$obj->show;
