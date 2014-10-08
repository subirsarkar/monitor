package WebService::MonitorCore;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use HTTP::Date;
use URI::Escape;

use POSIX qw/strftime/;

use GD;
use GD::Graph::lines;
use GD::Text;

use List::Util qw/min max/;
use JSON;

use WebService::MonitorUtil qw/trim
                               getTime
                               getTimestamp
                               getWriter
                               getParser
                               writeData
                               getXAxisLabel
                               getXAxisLabelFD
                               time2hours/;
use constant SCALE => 1024;
use constant SIX_HOURS => 6 * 60 * 60;
use constant NA => 'n/a';
our $conv =
{
  K => SCALE,
  M => SCALE**2,
  G => SCALE**3
};
our $jobstateS2LMap = 
{
  R => 'Running',
  Q => 'Queued',
  H => 'Held',
  E => 'Finished',
  U => 'Unknown'
};
our $jobstateL2SMap = 
{
    running => 'R',
     queued => 'Q',
       held => 'H',
  completed => 'E',
    unknown => 'U'
};
our %vTags = map { $_ => 1 } 
  qw/subject 
     queue 
     user 
     grid_id
     rb 
     ceid 
     exec_host 
     qtime 
     start 
     ex_st/;

our $esc_map = 
{
       jid => '^A-Za-z0-9.:/\-_',
  jobstate => '^A-Za-z',
   tagname => '^A-Za-z_',
    filter => '^A-Za-z0-9.:/=\-_!\s',
    myjobs => '^A-Za-z',
  diagnose => '^A-Za-z0-9'
};

my $udmap = 
{
      start => NA,
        end => NA,
      ex_st => NA,
  exec_host => NA,
       rank => NA,
   timeleft => '-1[?]'
};

sub new 
{
  my ($this, $cfg) = @_;
  my $class = ref $this || $this; 
  bless {
    config => $cfg,
    voList => []
  }, $class;
}

sub setDBH
{
  my ($self, $dbh) = @_;
  $self->{dbh} = $dbh;
}

sub setCGI
{
  my ($self, $cgi) = @_;
  $self->{cgi} = $cgi;
}

sub _extract 
{
  my ($self, $method, $name, $cset) = @_;

  my $handler = $self->{cgi};
  my $value = $handler->extract( $method => $name );
  $value = uri_escape($value, $cset) if (defined $cset and defined $value);
  print STDERR qq|name=$name,value=$value\n| 
     if (defined $value and $self->{config}{debug} >> 1 & 0x1);
  $value;
}

sub setDN
{
  my ($self, $dn) = @_;
  $self->{dn} = $dn;
}

sub setVOList
{
  my ($self, $voList) = @_;
  $self->{voList} = $voList;
}

sub AuthInfo
{
  my $self = shift;
  my $voList = $self->{voList};
  my $voString = q|[|.join(',', @$voList).q|]|;
  join '#', $self->{dn}, $voString;
}

sub _getSize
{
  my ($param, $dvalue) = @_;
  return $dvalue unless (defined $param and $param =~ /-?\d+/);
  $param = int($param);
  return (($param > 0) ? $param : $dvalue);
}

sub _LB
{
  my $gridid = shift;
  return NA unless defined $gridid;

  $gridid =~ m#^https://([^/]+):(?:.+)#;
  return ((defined $1) ? $1 : NA);
}

sub _validateLB
{
  my ($self, $lb) = @_;
  my $info = $self->_getTagList('grid_id');
  (return ($info->{$lb}) ? 1 : 0);
}

sub LocalIdInfo
{
  my $self = shift;
  my $grid_id = $self->_extract('-as_printable', 'jid', $esc_map->{jid});
  return '?' unless defined $grid_id;

  my $query = qq|SELECT MAX(jid) FROM jobinfo_summary WHERE grid_id=?|;
  $self->_setAccess(\$query); # respect privacy settings

  my $aref = $self->_queryDB({ query => $query, args => [$grid_id] });
  return ((defined $aref->[0]) ? $aref->[0] : '?');
}

sub JobList
{
  my $self = shift;
  my $jidList = $self->_getJobList;
  print STDERR Data::Dumper->Dump([$jidList], [qw/jidList/])
    if $self->{config}{debug} >> 1 & 0x1;  

  my $jsval;
  eval {
    my $json = new JSON(pretty => 1, delimiter => 1, skipinvalid => 1);
    $jsval = ($json->can('encode'))
      ? $json->encode({ 'jids' => $jidList })
      : $json->objToJson({ 'jids' => $jidList });
  };
  $@ and print STDERR qq|JSON Problem likely!!, $@\n|;
  $jsval;
}

sub JobList2
{
  my $self = shift;
  my $jidList = $self->_getJobList;

  my $list = [];
  for (@$jidList) {
    my ($jid, $gid) = split /##/;
    my $dict = {
       jid => $jid, 
       gid => $gid
    };
    push @$list, $dict;
  }
  my $jsval;
  eval {
    my $json = new JSON(pretty => 1, delimiter => 1, skipinvalid => 1);
    $jsval = ($json->can('encode'))
      ? $json->encode({ 'total' => scalar @$list, 'rows' => $list })
      : $json->objToJson({ 'total' => scalar @$list, 'rows' => $list });
  };
  $@ and print STDERR qq|JSON Problem likely!!, $@\n|;
  $jsval;
}

sub UserSummary
{
  my $self = shift;

  my $status = $self->_extract('-as_printable', 'jobstate', $esc_map->{jobstate});
  my $jobstate = (defined $status) ? ($jobstateL2SMap->{$status} || 'U') : 'U';

  # the table content should depend on the job state
  my @tags   = ('Job ID', 'User', 'Queued');
  my @fields = qw/grid_id user qtime/;
  if ($jobstate eq 'Q') {
    push @tags, ('Rank');
    push @fields, qw/rank/;              
    if ($self->{config}{has_jobpriority}) {
      push @tags, ('Priority');
      push @fields, qw/priority/;              
    }
  }
  else {
    push @tags, 'Started';
    push @fields, qw/start/;
    unless ($jobstate eq 'R') {
      push @tags, ('Finished', 'Exit Status');
      push @fields, qw/end ex_st/;
    }
    push @tags, ('CPUtime [hrs]','Walltime [hrs]','Mem [MB]','VMem [MB]','Host');
    push @fields, qw/cputime walltime mem vmem exec_host/;
  }

  my $list = $self->_getUserview($jobstate);

  my $html = q|<thead><tr><th>|.join (q|</th><th>|, @tags). qq|</th></tr></thead>\n|; 
  
  $html .= q|<tbody>|;
  for my $info (@$list) {
    $html .= q|<tr><td>|.join (q|</td><td>|, map { $info->{$_} } @fields). qq|</td></tr>\n|; 
  }
  $html .= q|</tbody>|;
  $html .= q|<tfoot><tr><th>|.join (q|</th><th>|, @tags). qq|</th></tr></tfoot>\n|; 
  print STDERR $html if $self->{config}{debug} >> 3 & 0x1;
  $html;
}

sub CompleteTagList
{
  my $self = shift;
  my $info = $self->_getNTagList;

  # send XML data
  my $xmlstr;
  my $writer = getWriter(\$xmlstr);  # new document
  $writer->startTag('doc');                   # doc
  while ( my ($tag) = each %$info) {
    $writer->startTag($tag);                  # selection tag
    my $aref = $info->{$tag};      

    # Add 'Any' as the first element
    $writer->startTag(qq|item|);
    $writer->characters(qq|Any|);
    $writer->endTag;

    # Now add the real values
    for (@$aref) {
      $writer->startTag(qq|item|);            # items in a selection tag
      $writer->characters($_);
      $writer->endTag;                        # items in a selection tag
    }
    $writer->endTag;                          # selection tag
  }
  $writer->endTag;  # doc
  $writer->end;     # document

  print STDERR $xmlstr if $self->{config}{debug} >> 3 & 0x1;
  $xmlstr;
}

sub TagList
{
  my $self = shift;
  my $tag = $self->_extract('-as_printable', 'tagname', $esc_map->{tagname});
  my $info = (defined $tag and exists $vTags{$tag}) ? $self->_getTagList($tag) : {};
  my $xmlstr = writeData($info, qq|tagList|, qq|tag|);
  print STDERR $xmlstr if $self->{config}{debug} >> 3 & 0x1;
  $xmlstr;
}

sub JobInfo
{
  my $self = shift;
  my $info = $self->_getJobInfo;
  writeData($info, qq|jobInfo|, undef);
}

sub JobStatus
{
  my ($self, $jid) = @_;
  my $dict = $self->_getFieldValues({ 
      jid => $jid, 
    fields => ['status']
  });
  $dict->{status};
}

sub CPULoad
{
  my $self = shift;

  my $host = q|unknown|;
  # safe
  my $w = _getSize($self->_extract('-as_integer', 'width'),  500);
  my $h = _getSize($self->_extract('-as_integer', 'height'), 140);

  my $attr = 
  {
      width => $w,
     height => $h,
      title => qq|CPU Load/Efficiency|,
     ylabel => qq|CPU Usage|,
       ymax => 2.0,
    legends => {
                       Load => qq|red|, 
                 Efficiency => qq|blue|
               },
    yformat => qq|%3.1f|
  };

  # ensure that request has a valid jobid
  # maybe a simple check that the value is an integer is good enough
  # you cannot check this earlier before $attr is ready
  my $jobid = $self->_extract('-as_printable', 'jid', $esc_map->{jid});
  return $self->_sendBlankImage($attr) unless defined $jobid;
  
  # now find the jobid and check the job status, if queued return
  # in any case Queued jobs use cached images
  # first of all check if the client can access information
  my $dict = $self->_getFieldValues({ 
           jid => $jobid, 
        fields => ['status', 'exec_host', 'start'], 
    set_access => 1 
  });
  return $self->_sendBlankImage($attr) unless $self->_statusAvailable($dict->{status});

  # check if the job is running/completed
  return $self->_sendBlankImage($attr) if $self->_isQueued($dict->{status});

  # at this point we assume that all other informaton are retrieved properly
  # get the hostname and build the image title
  $host = $dict->{exec_host} || 'unknown';
  $attr->{title} = qq|CPU Load/Efficiency for $jobid\@$host|;
  my $stime = $dict->{start};

  # Retrieve the timeseries fields from DB, split and build the arrays
  $dict = $self->_getFieldValues({ 
       jid => $jobid,
    fields => ['cpuload', 'cpufrac', 'timestamp'],
     table => qq|jobinfo_timeseries|
  });
  my @loadList = map { min($_ * 1.0, 3.0) } # assume a MAX load of 3
                     (split /\s+/, trim $dict->{cpuload});
  return $self->_sendBlankImage($attr) unless scalar @loadList;

  my @fracList = map { min($_ * 1.0, 1.0) } 
                     (split /\s+/, trim $dict->{cpufrac});
  my @timeList = (split /\s+/, trim $dict->{timestamp});

  # build the x-axis labels 
  my @labels = ();
  unless (scalar @timeList - scalar @loadList) {
    push @labels, getXAxisLabelFD($stime, $_) for @timeList;
  }
  else {
    push @labels, getXAxisLabel($stime, $_) for (0..$#loadList);
  }
  if ($self->{config}{debug} >> 3 & 0x1) {
    print STDERR join("\n", @loadList), "\n";
    print STDERR join("\n", @labels), "\n";
  }

  # build the graph data
  my $data = [\@labels, \@loadList, \@fracList];
  $attr->{ymax} = max 0.5, max(@loadList, @fracList)*1.3;

  # all set
  my $output = $self->_sendImage($data, $attr, 1);
  return ((defined $output) ? $output : $self->_sendBlankImage($attr));
}

sub MemoryUsage
{
  my $self = shift;

  my $host = q|unknown|;
  my $w = _getSize($self->_extract('-as_integer', 'width'),  500);
  my $h = _getSize($self->_extract('-as_integer', 'height'), 140);

  my $attr = 
  {
      width => $w,
     height => $h,
      title => qq|Memory/Disk Usage|,
     ylabel => qq|Memory Usage (MB)|,
       ymax => 600,
    legends => {
        Physical => qq|red|, 
         Virtual => qq|blue|, 
            Disk => qq|cyan|
    },
    yformat => qq|%d|
  };

  # ensure that request has a valid jobid
  # maybe a simple check that the value is an integer is good enough
  # you cannot check this earlier before $attr is ready
  my $jobid = $self->_extract('-as_printable', 'jid', $esc_map->{jid});  
  return $self->_sendBlankImage($attr) unless defined $jobid;
  
  # now find the jobid and check the job status, if queued return

  # first of all check if the client can access information
  my $dict = $self->_getFieldValues({ 
           jid => $jobid, 
        fields => ['status','exec_host','start'], 
    set_access => 1 
  });
  return $self->_sendBlankImage($attr) unless $self->_statusAvailable($dict->{status});

  # check if the job is running/completed
  return $self->_sendBlankImage($attr) if $self->_isQueued($dict->{status});

  # at this point we assume that all other informaton are retrieved properly
  # get the hostname and build the the image title
  $host = $dict->{exec_host} || 'unknown';
  $attr->{title} = qq|Memory/Disk Usage for $jobid\@$host|;

  my $stime = $dict->{start};

  # retrieve timeseries fields from DB, split and build the arrays
  $dict = $self->_getFieldValues({
       jid => $jobid,
    fields => ['mem', 'vmem', 'diskusage', 'timestamp'],
     table => qq|jobinfo_timeseries|
  });
  my @memList  = map { $_*1.0/$conv->{K} }
                     (split /\s+/, trim $dict->{mem});
  return $self->_sendBlankImage($attr) unless scalar @memList;

  # vmem
  my @vmemList = map { $_*1.0/$conv->{K} }
                     (split /\s+/, trim $dict->{vmem});
  # diskusage
  my @duseList = map { $_*1.0/$conv->{K} }
                     (split /\s+/, trim $dict->{diskusage});

  # get the timestamp array
  my @timeList = (split /\s+/, trim $dict->{timestamp});

  # build the x-axis labels 
  my @labels = ();
  unless (scalar @timeList - scalar @memList) {
    push @labels, getXAxisLabelFD($stime, $_) for @timeList;
  }
  else {
    push @labels, getXAxisLabel($stime, $_) for (0..$#memList);
  }

  # build the graph data
  my $data = [\@labels, \@memList, \@vmemList, \@duseList];
  my $ymax = max(@memList, @vmemList, @duseList)*1.2;
  my $mod = 100 - int($ymax) % 100;
  $attr->{ymax} = int($ymax) + $mod; 

  # all set
  my $output = $self->_sendImage($data, $attr, 1);
  return ((defined $output) ? $output : $self->_sendBlankImage($attr));
}

sub PSInfo
{
  my $self = shift;
  $self->_sendMoreJobInfo(q|ps|);
}

sub TopInfo
{
  my $self = shift;
  $self->_sendMoreJobInfo(q|top|);
}

sub JobdirListInfo
{
  my $self = shift;
  $self->_sendMoreJobInfo(q|jobdir|);
}

sub WorkdirListInfo
{
  my $self = shift;
  $self->_sendMoreJobInfo(q|workdir|);
}

sub LogInfo
{
  my $self = shift;
  $self->_sendMoreJobInfo(q|log|);
}

sub ErrorInfo
{
  my $self = shift;
  $self->_sendMoreJobInfo(q|error|);
}

# private member functions
sub _setAccess
{
  my ($self, $rquery) = @_;
  my $voList = $self->{voList};
  # Site admins naturally have access to all the jobs
  return if $voList->[0] eq 'admin';  

  # VO admins may have access to all the jobs for that VO
  my $dn = $self->{dn};
  my $voadmin = 0;
  my $qf = q| AND (|;
  for my $vo (@$voList) {
    if (grep { $_ eq $dn } @{$self->{config}{admins}{$vo}}) {
      ++$voadmin;
      my $group = $self->{config}{vo2group}{$vo} || $vo;
      $qf .= qq| ugroup='$group' OR|; 
    }
  } 
  if ($voadmin) {
    $$rquery .= substr $qf, 0, rindex($qf, 'OR');
    $$rquery .= q|)|;
    return;
  }

  # show jobs for this DN only if strict privacy is enforced
  if ( $self->{config}{privacy_enforced} or 
         defined $self->_extract('-as_printable', 'myjobs', $esc_map->{myjobs}) ) {
    $$rquery .= qq| AND subject='$dn'|; 

    # local user jobs
    my $luser = $self->getLocalUser($dn);
    $$rquery .= qq| OR user='$luser'| if defined $luser; 
  }
  else {
    # show jobs for VOs the DN is in
    my $q = q| AND (|; 
    for my $vo (@$voList) {
      my $group = $self->{config}{vo2group}{$vo} || $vo;
      $q .= qq| ugroup='$group' OR|; 
    } 
    $$rquery .= substr $q, 0, rindex($q, 'OR');
    $$rquery .= q|)|;
  }
}

sub getLocalUserGroup
{
  my ($self, $dn) = @_;
  my $users = $self->{config}{'localusers'};
  return undef unless defined $users->{$dn};
  $users->{$dn}{group};
}
sub getLocalUser
{
  my ($self, $dn) = @_;
  my $users = $self->{config}{'localusers'};
  return undef unless defined $users->{$dn};
  $users->{$dn}{user};
}
sub _statusAvailable
{
  my ($self, $status) = @_;
  return 0 unless defined $status;
  return ((exists $jobstateS2LMap->{$status}) ? 1 : 0);
}

sub _addWindow
{
  my ($self, $state, $rquery) = @_;
  return unless (defined $state and defined $rquery);

  # For running and pending jobs
  # time window cannot be selected
  return unless (grep { $_ eq $state} qw/E U/);

  my $debug = $self->{config}{debug} || 0;
  my $pattern = '^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$';
  my ($f, $t);
  eval {
    # check the format of the string
    $f = $self->_extract('-as_printable', 'from');
    croak unless (defined $f and $f =~ /$pattern/);

    $t = $self->_extract('-as_printable', 'to');
    croak unless (defined $t and $t =~ /$pattern/);

    $f = str2time($f);
    $t = str2time($t);
    print STDERR join(';', $f, $t), "\n" if $debug >> 1 & 0x1;
  };
  if ($@) {
    print STDERR qq|Failed to parse timestamp because\n, $@|;
    $t = time;
    $f = $t - SIX_HOURS;
  }
  $$rquery .= ($state eq 'E') 
      ? qq| AND (end>=$f AND end<=$t)|
      : qq| AND (qtime>=$f AND qtime<=$t)|;
}

sub _addFilter
{
  my ($self, $rquery) = @_;
  my $config = $self->{config};

  my $filter = $self->_extract('-as_printable', 'filter', $esc_map->{filter});
  return [0,''] unless defined $filter;
  print STDERR $filter, "\n" if $config->{debug} >> 2 & 0x1;

  my ($name, $value) = map { trim $_ } (split /!/, $filter);
  print STDERR qq|Invalid CGI parameter: $filter\n| and return undef
    unless (defined $name and defined $value);
  print STDERR qq|Unsupported tagname $name\n| and return undef 
    unless exists $vTags{$name};      

  # _tricky_, if we prepare a statement we set status=1 
  # so that upstream one can pass the value with the query
  # status=0 means we have already substitued the value in the
  # query statement itself, so no need to pass again with the
  # query
  my $status = 1;
  if ($name eq 'grid_id') { # for LB
    $value = 'NO_MATCH' unless $self->_validateLB($value);
    $$rquery .= qq| AND $name LIKE '%$value%'|;  # used in building the statement itself
    $status = 0;
  }
  elsif (grep { $_ eq $name } qw/qtime start/) {
    $$rquery .= qq| AND FROM_UNIXTIME($name, '%Y-%m-%d')=?|;
  }
  else {
    if ($name eq 'exec_host') {
      my $usedomain = $config->{usedomain} || 0;
      $value .= qq|.$config->{domain}| if $usedomain;
    }
    $$rquery .= qq| AND $name=?|;
  }
  [1,$value];
}

sub _addDiagnosis
{
  my ($self, $rquery) = @_;
  my $diag = $self->_extract('-as_printable', 'diagnose', $esc_map->{diagnose});
  return unless defined $diag;

  if ($diag =~ /^cpu/) {
    my $map = 
    {
         cpu0 => qq|cputime/walltime<0.01|,
        cpu10 => qq|(cputime/walltime>=0.01 AND cputime/walltime<0.1)|,
        cpu30 => qq|(cputime/walltime>=0.1  AND cputime/walltime<0.3)|,
        cpuok => qq|cputime/walltime>=0.3|,
      cpuhigh => qq|cputime/walltime>=1.5|
    };
    my $cpucond = (defined $map->{$diag}) ? $map->{$diag} : $map->{cpuok};
    $$rquery .= qq| AND $cpucond AND walltime>1800|;
  }
  elsif ($diag =~ /load/) {
    my $map = 
    {
      load0 => qq|((statusbit>>2)&1)=1|,
      load1 => qq|((statusbit>>3)&1)=1|
    };
    my $cpucond = (defined $map->{$diag}) ? $map->{$diag} : $map->{load0};
    $$rquery .= qq| AND $cpucond|;
  }
  ##elsif ($diag eq 'load0') {
  ##  $$rquery .= qq| AND ((statusbit>>2)&0x1)=1|; 
  ##}
  elsif ($diag =~ /^hv?mem$/ or $diag =~ /^hv?diskusage$/) {
    my $memlim =
    {  
            mem => 2, 
           vmem => 4,
      diskusage => 6
    };
    $diag =~ s/^h//;
    exists $memlim->{$diag} 
      or print STDERR qq|Invalid lookup parameter: $diag\n| and return;
    my $limit = $memlim->{$diag} * $conv->{M}; # memory is stored in KB
    $$rquery .= qq| AND $diag>$limit|;
  }
  elsif ($diag eq 'noproxy') {
    $$rquery .= qq| AND timeleft<1800|;
  }
}

sub _normGridid
{
  my ($self, $attr) = @_;
  my $gid = $attr->{gid};
  $attr->{strip_https} = 1 unless exists $attr->{strip_https};

  if (defined $gid) {
    $gid =~ s#^https://## if ($attr->{strip_https} and $gid =~ m#^https://#);
  }
  else {
    if (defined $attr->{ceid}) {
      $gid = (defined $attr->{rb} and $attr->{rb} ne '?') 
        ? q|Pilot Job by-passing RB/WMS| 
        : q|Unknown|;
    }
    else {
      $gid = q|Local Job|;
    }
    $gid .= qq|!$attr->{jid}|;
  }
  $gid;
}
sub _getJobList 
{
  my $self = shift;
  my $dbh = $self->{dbh};

  my $list = [];
  my $status = $self->_extract('-as_printable', 'jobstate', $esc_map->{jobstate});
  return $list unless defined $status;
  my $jobstate = $jobstateL2SMap->{$status} || 'U';

  my $query = qq|SELECT jid,grid_id,user,ceid,rb FROM jobinfo_summary WHERE status=?|;
  my $fvalue = $self->_addFilter(\$query); # returns a list reference
  return $list unless defined $fvalue;

  $self->_addWindow($jobstate, \$query);
  $self->_addDiagnosis(\$query);
  $self->_setAccess(\$query);            # respect privacy settings
  print STDERR $query, "\n" if $self->{config}{debug} >> 1 & 0x1;

  my $sth = $dbh->prepare($query);
  my @args = ($jobstate);
  push @args, $fvalue->[1] if $fvalue->[0]>0; 
  $sth->execute(@args);

  my $dict = {};
  while ( my $aref = $sth->fetchrow_arrayref ) {
    my ($jid, $gid, $user, $ceid, $rb) 
      = ($aref->[0], $aref->[1], $aref->[2], $aref->[3], $aref->[4]);
    $gid = undef if (defined $gid and $gid eq '?');
    $gid = $self->_normGridid({ jid => $jid, 
                               ceid => $ceid, 
                                 rb => $rb, 
                                gid => $gid });
    $dict->{qq|$jid!$user|} = $gid;
  }
  $sth->finish;

  # find duplicate Grid ids - very complex, review later
  # must guard against glideins and other pilots
  my $diag = $self->_extract('-as_printable', 'diagnose', $esc_map->{diagnose});
  if (defined $diag and $diag eq 'duplicateid') {
    my $dup_list = {};
    while ( my ($jid,$gid) = each %$dict ) {  # for each must use while
      next if $gid =~ /^Pilot/;
      push @{$dup_list->{$gid}}, $jid;
    } 
    for my $gid (sort keys %$dup_list) {
      my @a = @{$dup_list->{$gid}};
      my $ndup = scalar @a;
      next if $ndup < 2;
      my $str = join ',', @a;
      my $item = join '##', $a[0], qq|$gid($ndup: $str)|;
      push @$list, $item;
    }
  }
  else {
    for my $jid (sort keys %$dict) {
      my $item = join '##', $jid, $dict->{$jid};
      push @$list, $item;
    } 
  }  
  $list;
}

sub _getUserview 
{
  my ($self, $jobstate) = @_;
  print STDERR "JOBSTATE=$jobstate\n" if $self->{config}{debug} >> 1 & 0x1;
  my $dbh = $self->{dbh};

  my $list = [];
  my $query = qq|SELECT jid,ceid,grid_id,rb,user,ugroup,queue,qtime,start,end,ex_st,cputime,walltime,mem,vmem,exec_host,rank|; 
  $self->{config}{has_jobpriority} and $query .= qq|,priority|;
  $query .= qq| FROM jobinfo_summary WHERE status=?|;
  my $fvalue = $self->_addFilter(\$query);
  return $list unless defined $fvalue;

  $self->_addWindow($jobstate, \$query);
  $self->_addDiagnosis(\$query);
  $self->_setAccess(\$query);       # respect privacy settings
  print STDERR $query, "\n" if $self->{config}{debug} >> 1 & 0x1;

  my $sth = $dbh->prepare($query);
  my @args = ($jobstate);
  push @args, $fvalue->[1] if $fvalue->[0]>0; 
  $sth->execute(@args);

  # Now extract and transform suitably
  while (my $h = $sth->fetchrow_hashref) {
    my $dict = {};
    while ( my ($key) = each %$h) {
      my $value = $h->{$key};
      $value = undef if (defined $value and $value eq '?');
      if (defined $value) { 
        if ($key eq 'user') {
          $value .= qq| ($h->{ugroup})|;
        }
        elsif (grep { $_ eq $key } qw/qtime start end/) {
          $value = strftime qq|%Y-%m-%d %H:%M:%S|, localtime($value);
        }
        elsif (grep { $_ eq $key } qw/cputime walltime/) {
          $value = time2hours($value);
        } 
        elsif (grep { $_ eq $key } qw/mem vmem/) {
          $value /= $conv->{K};
          $value = sprintf qq|%6.1f|, $value;
        }
      }
      if ($key eq 'grid_id') {
        my $jid  = $h->{jid};  # append localid to grid_id in case it is not defined
        my $ceid = $h->{ceid}; # well, ceid should always be defined from now on
        my $rb   = $h->{rb};   # we usually form the RB string
        $value = $self->_normGridid({ jid => $jid, 
                                      gid => $value, 
                                     ceid => $ceid, 
                                       rb => $rb });
      }
      $dict->{$key} = (defined $value) ? $value : ($udmap->{$key} || '?');
    }
    # Finally some cosmetic twists
    $dict->{exec_host} = NA if (defined $dict->{start} and $dict->{start} eq NA);
    $dict->{ex_st}     = NA if (defined $dict->{end} and $dict->{end} eq NA);
  
    push @$list, $dict;
  }
  $sth->finish;

  $list;
}

sub _getJobInfo
{
  my $self = shift;

  my $dict = {};
  my $jobid = $self->_extract('-as_printable', 'jid', $esc_map->{jid});  
  return $dict unless defined $jobid;

  my $fields = [
             'user',
             'ugroup',
             'queue',
             'qtime',
             'start',
             'end',
             'status',
             'cputime',
             'walltime',
             'exec_host',
             'ex_st',
             'ceid',
             'subject',
             'grid_id',
             'rb', 
             'timeleft',
             'role',
             'jobdesc',
             'rank'
  ];
  $self->{config}{has_jobpriority} and push @$fields, 'priority';
  my $h = $self->_getFieldValues({
            jid => $jobid,
         fields => $fields,
     set_access => 1
  }); 
  $h->{grid_id} = $self->_normGridid({ jid => $jobid, 
                                      ceid => $h->{ceid}, 
                                        rb => $h->{rb}, 
                                       gid => $h->{grid_id},
                               strip_https => 0 });
  while (my ($key) = each %$h) {
    my $value = $h->{$key};
    if (defined $value) {
      if ($key eq 'status') {
        $value = $jobstateS2LMap->{$value} || 'U';
      }
      elsif ($key eq 'user') {
        $value .= qq| ($h->{ugroup})|;
      }
      elsif (grep { $_ eq $key } qw/qtime start end/) {
        $value = getTime($value);
      }
      elsif (grep { $_ eq $key} qw/cputime walltime/) {
        $value = time2hours($value).qq| hrs|; 
      } 
      elsif ($key eq 'timeleft') {
        $value = ($value>0) ? time2hours($value).qq| hrs| : undef; 
      }
      elsif ($key eq 'grid_id') {
	if ($value =~ /^Pilot/) {
          $value = qq|PILOTJOB|;
        }
        elsif ($value =~ /^Local Job/) {
          $value = qq|LOCALJOB|;
        } 
        elsif ($value =~ /^Unknown/) {
          $value = qq|UNKNOJOB|;
        } 
        $value .= qq|!$jobid| unless $value =~ m#https://#;
      }
    }
    $dict->{$key} = (defined $value) ? $value : ($udmap->{$key} || '?');
  }
  # Finally some cosmetic twists
  $dict->{exec_host} = NA if (defined $dict->{start} and $dict->{start} eq NA);
  $dict->{ex_st}     = NA if (defined $dict->{end} and $dict->{end} eq NA);

  # Finally add the jid itself
  $dict->{jid} = $jobid;
  $dict;
}

sub _getTagList
{
  my ($self, $tag) = @_;
  my $dbh = $self->{dbh};

  my $status = $self->_extract('-as_printable', 'jobstate', $esc_map->{jobstate});
  my $jobstate = (defined $status) ? ($jobstateL2SMap->{$status} || 'U') : 'U';

  # build the query
  my $query = qq|SELECT DISTINCT|;
  $query .= ( grep { $_ eq $tag } qw/qtime start/) 
             ? qq| FROM_UNIXTIME($tag, '%Y-%m-%d')| 
             : qq| $tag|;
  $query .= qq| FROM jobinfo_summary WHERE status=?|;
  $self->_addWindow($jobstate, \$query);
  $self->_setAccess(\$query);                 # respect privacy settings
  print STDERR $query, "\n" if $self->{config}{debug} >> 1 & 0x1;

  # prepare statement and execute
  my $sth = $dbh->prepare($query);
  $sth->execute($jobstate);

  # prepare the dictionary
  my $info = {};
  while (my $aref = $sth->fetchrow_arrayref) {
    my $value = $aref->[0];
    next unless defined $value;
  
    # WN list contains NO HOST
    if ($tag eq 'exec_host') {
      $value = (split /\./, $value)[0]; # domain is not important
    }
    elsif ($tag eq 'grid_id') {
      $value = _LB($value);
    }
    # Strange that key and value are the same!
    # actually, this makes the writeData(...) happy
    $info->{$value} = $value;
  }
  $sth->finish;

  $info;
}

sub _getNTagList 
{
  my $self = shift;
  my $dbh = $self->{dbh};

  # job Status tag
  my $status = $self->_extract('-as_printable', 'jobstate', $esc_map->{jobstate});
  my $jobstate = (defined $status) ? ($jobstateL2SMap->{$status} || 'U') : 'U';

  # build query 
  my $query = qq|SELECT queue,ceid,rb,exec_host,subject,FROM_UNIXTIME(qtime,'%Y-%m-%d'),FROM_UNIXTIME(start,'%Y-%m-%d')
  FROM jobinfo_summary 
  WHERE status=?|;
  $self->_addWindow($jobstate, \$query);
  $self->_setAccess(\$query);              # respect privacy settings
  print STDERR $query, "\n" if $self->{config}{debug} >> 1 & 0x1;

  # prepare and execute
  my $sth = $dbh->prepare($query);
  $sth->execute($jobstate);

  # get the information in a big array and release the DB connection
  my @list = ();
  while (my $href = $sth->fetchrow_hashref) {
    push @list, $href;
  }
  $sth->finish;

  my $info = {};
  for my $href (@list) {
    while ( my ($key) = each %$href ) {
      my $nkey = $key;
      if ($key =~ /FROM_UNIXTIME\(start/) {
        $nkey = qq|start|;
      }
      elsif ($key =~ /FROM_UNIXTIME\(qtime/) {
        $nkey = qq|qtime|;
      }
      my $value = $href->{$key};
      next unless defined $value;
      $value = $1 if $value =~ m#^https://([^/]+):(?:.+)#;
      push @{$info->{$nkey}}, $value;
    }
  }
  while ( my ($key) = each %$info) {
    my @list = @{$info->{$key}};
    my %seen = ();
    @list = grep { ! $seen{$_} ++ } @list;
    $info->{$key} = [@list];
  }
  print STDERR Data::Dumper->Dump([$info], [qw/info/]) 
    if $self->{config}{debug} >> 3 & 0x1;

  $info;
}

sub _isQueued 
{
  my ($self, $status) = @_;
  return 0 unless defined $status;
  $status eq 'Q';
}

sub _sendImage
{
  my ($self, $data, $attr, $decorate) = @_;
  my $labels = $data->[0];
  my $nlabels = scalar @$labels;

  my ($w, $h) = ($attr->{width}, $attr->{height});
  my $graph = new GD::Graph::lines($w, $h);
  $graph->set_text_clr('black');  ## important
  $graph->set(
    x_label          => 'Time',
    y_label          => $attr->{ylabel},
    bgclr            => '#f8f8ff',
    fgclr            => '#333333',
    boxclr           => 'black',
    dclrs            => ['lred', 'lblue', 'cyan'],
    long_ticks       => 1,
    y_max_value      => $attr->{ymax},
    y_min_value      => 0,
    y_tick_number    => 'auto',  
          # +ve number implies numerical values that is not intended for the x-axis
    x_label_skip     => int($nlabels/6)+1,
    x_label_position => 1/2,
    y_number_format  => $attr->{yformat},
    box_axis         => 1,
    axis_space       => 2,
    text_space       => 2,
    types            => ['linespoints'],
    line_width       => 1,
    transparent      => 0
  );
  $graph->set_x_label_font(gdMediumBoldFont) or carp $graph->error;
  $graph->set_y_label_font(gdMediumBoldFont) or carp $graph->error;
  $graph->set_x_axis_font(gdSmallFont)       or carp $graph->error;
  $graph->set_y_axis_font(gdSmallFont)       or carp $graph->error;

  my $image = $graph->plot($data);
  return undef unless defined $image; # How to manage an undefined image object??

  my $colorMap = 
  {
     red => $image->colorAllocate(255, 0, 0),
    blue => $image->colorAllocate(0, 0, 255),
    cyan => $image->colorAllocate(0, 255, 255)
  };

  if (defined $decorate) {
    # get hold of the original GD object and draw legends etc.
    my $gray = $image->colorAllocate(190, 190, 190);
    WebService::MonitorCore::Text($image, gdSmallFont, 0.15*$w, 0.05*$h, $attr->{title}, $gray);
    WebService::MonitorCore::Text($image, gdTinyFont, 0.8*$w, 0.08*$h, getTimestamp, $gray);
    if (defined $attr->{legends}) {
      my $dict = $attr->{legends};
      my ($xpos, $ypos) = (0.8*$w, 0.7*$h);
      for my $legend (sort keys %$dict) {
        my $color = $colorMap->{$dict->{$legend}};
        WebService::MonitorCore::Line($image, $xpos, $ypos, $xpos+0.05*$w, $ypos, $color);
        WebService::MonitorCore::Text($image, gdSmallFont, $xpos+0.07*$w, 0.92*$ypos, $legend, $gray);
        $ypos -= 0.11*$h;
      }
    }
  }
  binmode STDOUT;
  $image->png;
}

sub _sendBlankImage
{
  my ($self, $attr) = @_;
  my $stime = time();
  my @labels = ();
  push @labels, getXAxisLabel($stime, $_) for (0..9);
  my $data = [\@labels, [0..0], [0..0]];
  $self->_sendImage($data, $attr);
}

sub _sendMoreJobInfo
{
  my ($self, $tag) = @_;

  my $jobid = $self->_extract('-as_printable', 'jid', $esc_map->{jid});  
  return qq|Jobid not found in the request!| unless defined $jobid;

  my $dict = $self->_getFieldValues({
           jid => $jobid, 
        fields => ['status', 'exec_host'], 
    set_access => 1
  });
  my $jobstatus = $dict->{status};
  return qq|Job not found, possible problems: 
      (a) DB update missing, 
      (b) access restriction!
        jobid=$jobid,status=$jobstatus| 
    unless $self->_statusAvailable($jobstatus);

  return qq|Job not running!,jobid=$jobid,status=$jobstateS2LMap->{$jobstatus}|
    if ( grep { $_ eq $jobstatus } qw/Q E/);

  my $host = $dict->{exec_host};
  return qq|Job not on any host, possible DB update problem!,
              jobid=$jobid,status=$jobstatus| 
    unless defined $host;

  $host = (split /\./, $host)[0];
  my $name = qq|$host.xml|;  

  # get hold of the BLOB
  my $q = qq|SELECT data FROM wninfo WHERE name=?|;
  my $aref = $self->_queryDB({ query => $q, args => [$name] });
  my $blob = (defined $aref) ? $aref->[0] : undef;

  return qq|Information not found in DB!,jobid=$jobid,host=$host| 
    unless defined $blob;

  # create the XML parser
  my $xp = getParser($blob);
  return qq|Error reading XML (from BLOB)!,jobid=$jobid| unless defined $xp;

  my $result;
  eval {
    if ($tag eq 'top') {
      $result = $xp->findvalue(qq|/info/$tag|);
      $result = qq|Most probably the WN is in bad state!| 
        unless (defined $result and length $result);
    }
    else {
      # enforce privacy again for job detail
      # workdir, jobdir, stdout, stderr are the private tabs
      my $private_tabs = $self->{config}{private_tabs} || [];
      my $voList = $self->{voList};
      my $dict = $self->_getFieldValues({
           jid => $jobid, 
        fields => ['walltime', 'subject', 'user', 'ugroup']
      });
      my ($subject, $ugroup) = ($dict->{subject}, $dict->{ugroup});
      my $thisvo = $self->{config}{ugroup2vo}{$ugroup} || $ugroup;
      my $dn     = $self->{dn};
      my $luser  = $self->getLocalUser($dn);
      my $showinfo = 1;
      if (grep { $_ eq $tag} @$private_tabs) {
         $showinfo = 0 unless (($voList->[0] eq 'admin') 
                            or ($dn eq $subject)
                            or (defined $luser and $luser eq $dict->{user})
                            or (grep { $_ eq $dn } @{$self->{config}{admins}{$thisvo}}));
      } 
      if ($showinfo) {
        $result = $xp->findvalue(qq|/info/jid[\@value="$jobid"]/$tag|);
        unless (defined $result and length $result) {
          my $walltime = $dict->{walltime};
          if ($walltime < 700) {
            $result = qq|Job has not run long enough, jobid=$jobid,walltime=$walltime secs|;
          }
          else {
            $result = ($tag eq 'error') 
               ? qq|Error log not found!,jobid=$jobid|
               : qq|Job finished or re-located!,jobid=$jobid|;
          } 
        }
      }
      else {
        $result  = qq|<font style="color:#f00">Permission denied!</font> privacy enforced.\n|;
        $result .= qq|Job owner: $subject|;
      }
    }
  };
  if ($@) {
    $result  = qq|Malformed XML, please wait for the next update!|;
    $result .= qq|\nError Detail: $@| if $self->{config}{debug};
  }
  # close the parser
  $xp->cleanup;

  $result;
}

sub _queryDB
{
  my ($self, $attr) = @_;
  my $dbh = $self->{dbh};
  print STDERR qq|Must pass a valid SQL SELECT statement| and return undef
    unless defined $attr->{query};
  
  my $query = $attr->{query};
  print STDERR $query, "\n" if $self->{config}{debug} >> 1 & 0x1;

  my $sth = $dbh->prepare($query);
  $sth->execute(@{$attr->{args}});

  my $aref = $sth->fetchrow_arrayref;
  $sth->finish;

  $aref;
}

sub _getFieldValues
{
  my ($self, $attr) = @_;
  my $dbh = $self->{dbh};

  $attr->{table}      = qq|jobinfo_summary| unless defined $attr->{table};
  $attr->{set_access} = 0 unless defined $attr->{set_access};
  my $fields = join ',', @{$attr->{fields}};

  my $query = qq|SELECT $fields 
  FROM $attr->{table} 
  WHERE jid=?|;
  $self->_setAccess(\$query) if $attr->{set_access};  
  print STDERR $query, "\n" if $self->{config}{debug} >> 1 & 0x1;

  my $sth = $dbh->prepare($query);
  $sth->execute($attr->{jid});
  my $href = $sth->fetchrow_hashref;
  $sth->finish;

  # set unknown(?) values back to undef
  for my $field (@{$attr->{fields}}) {
    $href->{$field} = undef if (defined $href->{$field} and $href->{$field} eq '?');
  }
  $href; 
}

sub Text
{
  my ($image, $f, $xpos, $ypos, $text, $color) = @_;
  $image->string($f, $xpos, $ypos, $text, $color);
}

sub Line
{
  my ($image, $x1, $y1, $x2, $y2, $color) = @_;
  $image->line($x1, $y1, $x2, $y2, $color);
}

1;
__END__
