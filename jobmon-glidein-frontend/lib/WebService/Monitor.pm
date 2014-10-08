package WebService::Monitor;

use strict;
use warnings;

use CGI::Application;
use CGI::Application::Plugin::DBH        qw/dbh_config dbh/;
use CGI::Application::Plugin::ConfigAuto qw/cfg/;
use CGI::Untaint;

use base 'CGI::Application';

use WebService::MonitorUtil qw/parseVOMapFile getTimestamp trim/;
use WebService::MonitorCore;

sub setup
{
  my $self = shift;
  $self->run_modes(
        auth => 'sendAuthInfo',
        list => 'sendJobList',
       list2 => 'sendJobList2',
         tag => 'sendTagList',
     alltags => 'sendCompleteTagList',
      status => 'sendJobStatus',
     summary => 'sendJobInfo',
        load => 'sendCPULoad',
         mem => 'sendMemoryUsage',
          ps => 'sendPSInfo',
         top => 'sendTopInfo',
     workdir => 'sendWorkdirListInfo',
      jobdir => 'sendJobdirListInfo',
         log => 'sendLogInfo',
       error => 'sendErrorInfo',
     localid => 'sendLocalIdInfo',
    tasklist => 'sendTaskList',
    userview => 'sendUserView',
    taskview => 'sendTaskView',
    AUTOLOAD => 'show_error'
  );
  $self->start_mode('auth');
  $self->mode_param('command');
  $self->error_mode('show_error');
}

sub cgiapp_init 
{
  my $self = shift;

  # use the same args as DBI->connect();

  # Access a config hash 
  my $cfg_href = $self->cfg;

  my $dbcfg = $cfg_href->{dbcfg};
  my $dsn = qq|DBI:mysql:monitor;mysql_read_default_file=$dbcfg;mysql_compression=1|;
  $self->dbh_config($dsn, qq||, qq||, {RaiseError => 1});

  # Now create the MonitorCore object; pass the config object
  my $monitor = WebService::MonitorCore->new($cfg_href);
  $self->param( monitor => $monitor );
}
sub cgiapp_prerun
{
  my $self = shift;
  $self->delete('error_message') if defined $self->param('error_message');

  # add the CGI object reference to MonitorCore at this point
  my $monitor = $self->param('monitor');
  $self->param( error_message => q|Failed to retrieve the core monitoring object!| )
    and return unless defined $monitor;

  my $handler = CGI::Untaint->new($self->query->Vars);
  $monitor->setCGI($handler);

  ($self->cfg('debug') >> 4 & 0x1) and __PACKAGE__->printEnv;

  # Find the DN the browser is using
  unless (defined $ENV{'SSL_CLIENT_S_DN'}) {
    my $message = <<"EOD";
Invalid client side subject DN [unavailable]. Access denied!
(a) Forgot to specify https?
(b) Please check the validity of the certificate again
EOD
    $self->param( error_message => $message ); 
    return;
  }
  my $dn = trim $ENV{'SSL_CLIENT_S_DN'};

  # Check the client certificate here and set the VO
  my $vomapfile = $self->cfg('vomapfile');
  $self->param( error_message => qq|$vomapfile not found or not readable!| )
    and return unless -r $vomapfile;

  # Check the DN against the map
  my $map = parseVOMapFile($vomapfile, $self->cfg('debug') >> 4 & 0x1);
  my $admin = $self->isAdmin($dn);
  my $localuser = $monitor->getLocalUser($dn);
  $self->param( error_message => qq|DN=$dn could not be mapped to any VO. Access denied!| )
    and return unless ($admin or defined $localuser or defined $map->{$dn});

  # Allow the admin to see all 
  my $voList = [];
  if ($admin) { # admin is supreme
    push @$voList, q|admin|;
  }
  else { 
    push @$voList, @{$map->{$dn}} if defined $map->{$dn};
    my $lgroup = $monitor->getLocalUserGroup($dn);
    push @$voList, $lgroup 
      if (defined $lgroup and ! grep { $_ eq $lgroup } @$voList);
  }
  $monitor->setDN($dn); 
  $monitor->setVOList($voList); 

  # Well, now it is time to connect to DB
  eval {
    $monitor->setDBH($self->dbh); 
  };
  $self->param( error_message => q|Failed to access the DB handle!| )
    and return if $@;

  if ($self->cfg('debug') > 0) {
    my $timenow = getTimestamp;
    my $vostr = join ',', @$voList;
    print STDERR <<"EOD";
---------------------------------
Access Time: $timenow
DN=$dn#vo=$vostr
QUERY_STRING=$ENV{QUERY_STRING}
EOD

    if ($self->cfg('debug') >> 2 & 0x1) {
      print STDERR <<"EOD";
    REMOTE_ADDR=$ENV{REMOTE_ADDR}
HTTP_USER_AGENT=$ENV{HTTP_USER_AGENT}
EOD
    }
  }
}
# Good to keep this code around
sub printEnv
{
  my $pkg = shift;
  while ( my ($key, $val) = each %ENV ) {
    print STDERR "$key = $val\n";
  }
}
sub isAdmin
{
  my ($self, $dn) = @_;
  defined $dn or return 0;
  my $admins = $self->cfg('admins');
  grep { $_ eq $dn } @{$admins->{site}};
}
sub teardown
{
  my $self = shift;

  # Disconnect when we're done, although DBI usually does this automatically
  $self->dbh->disconnect;
}

sub show_error
{
  my ($self, $error) = @_;
  $self->header_props(  -type => q|text/plain|, 
                      -status => q|404 - Not Found|,
                  -connection => q|close|
  );
  my $timenow = getTimestamp;

  my $message = <<"EOD";
$timenow >>> An error occurred
    REMOTE_ADDR=$ENV{REMOTE_ADDR}
HTTP_USER_AGENT=$ENV{HTTP_USER_AGENT}
Error detail:
$error
EOD

  print STDERR $message, "\n";
  return $message; 
}

sub sendAuthInfo
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->AuthInfo|);  
}

sub sendJobList 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->JobList|);  
}

sub sendJobList2 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->JobList2|);  
}

sub sendTagList 
{
  my $self = shift;
  $self->handler(q|text/xml|, q|$monitor->TagList|);  
}

sub sendCompleteTagList 
{
  my $self = shift;
  $self->handler(q|text/xml|, q|$monitor->CompleteTagList|);  
}

sub sendJobStatus 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->JobStatus|);  
}

sub sendJobInfo 
{
  my $self = shift;
  $self->handler(q|text/xml|, q|$monitor->JobInfo|);  
}

sub sendCPULoad 
{
  my $self = shift;
  $self->handler(q|image/png|, q|$monitor->CPULoad|);  
}

sub sendMemoryUsage 
{
  my $self = shift;
  $self->handler(q|image/png|, q|$monitor->MemoryUsage|);  
}

sub sendPSInfo 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->PSInfo|);  
}

sub sendTopInfo 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->TopInfo|);  
}

sub sendWorkdirListInfo 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->WorkdirListInfo|);  
}

sub sendJobdirListInfo 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->JobdirListInfo|);  
}

sub sendLogInfo 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->LogInfo|);  
}

sub sendErrorInfo 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->ErrorInfo|);  
}

sub sendLocalIdInfo 
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->LocalIdInfo|);  
}

sub sendTaskList
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->TaskList|);  
}

sub sendUserView 
{
  my $self = shift;
  $self->handler(q|text/html|, q|$monitor->UserView|);  
}

sub sendTaskView
{
  my $self = shift;
  $self->handler(q|text/plain|, q|$monitor->TaskView|);  
}

sub handler
{
  my ($self, $type, $method) = @_;
  if (defined $self->param('error_message')) {
    my $message = $self->param('error_message'); 
    die $message;
  }

  my $monitor = $self->param('monitor')
    or die qq|Failed to retrieve the core monitoring object!, $!|;

  $self->header_props(-type    => $type, 
                      -expires => q|-1d|, 
                   -connection => q|close|);
  eval "$method";
}

1;
__END__
