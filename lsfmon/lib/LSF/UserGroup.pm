# find correct group for jobs sumitted using bsub -G
package LSF::UserGroup;

use strict;
use warnings;
use Data::Dumper;
use LSF::Util qw/trim commandFH restoreInfo storeInfo filereadFH/;
use LSF::ConfigReader;

use base 'Class::Singleton';

sub _new_instance
{
  my $this = shift;
  my $class = ref $this || $this;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{verbose} || 0;

  my $groupinfo_file = $config->{group}{groupinfo_file} || qq|$config->{baseDir}/db/group_info.txt|;
  my $groupinfo_db = $config->{group}{groupinfo_db} || qq|$config->{baseDir}/db/groupinfo.db|;
  my $info = (-f $groupinfo_db) ? restoreInfo($groupinfo_db) : {};
  if (-f $groupinfo_file) {
    my $fh = filereadFH($groupinfo_file, $verbose);
    if (defined $fh) {
      while (my $line = $fh->getline) {
        my ($jid, $user, $status, $group) = (split /\s+/, trim($line));
        next if exists $info->{$jid};
        $info->{$jid} = {
                user => $user, 
              status => $status, 
               group => $group
        };
      }
      $fh->close;
    }
  }
  storeInfo($groupinfo_db, $info);
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
my $obj = LSF::UserGroup->instance;
$obj->show;
