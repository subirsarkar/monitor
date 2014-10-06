package LSF::RRDsys;

use strict;
use warnings;
use Carp;
use RRDp;

use LSF::ConfigReader;
use LSF::Util qw/trim/;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $config = LSF::ConfigReader->instance()->config;
  my $executable = $config->{rrd}{rrdtool} || q|/usr/bin/rrdtool|;

  RRDp::start $executable or croak qq|>>> $executable not found! stopped|;
  $RRDp::error_mode = 'catch';

  my $file = $attr->{file} || $config->{rrd}{db};
  my $location = $config->{rrd}{location};
  my $rrdFile = qq|$location/$file|;
  bless { 
    _rrdFile => $rrdFile 
  }, $class;
}

sub filepath
{
  my ($self, $file) = @_;
  defined $file or croak qq|File argument missing!|;

  my $config = LSF::ConfigReader->instance()->config;
  my $location = $config->{rrd}{location};
  qq|$location/$file|;
}

sub rrdFile
{
  my ($self, $file) = @_;
  defined $file or return $self->{_rrdFile};

  my $config = LSF::ConfigReader->instance()->config;
  my $location = $config->{rrd}{location};
  $self->{_rrdFile} = qq|$location/$file|;
  $self->{_rrdFile};
}

sub create
{
  my ($self, $list) = @_;

  my $rrd = $self->{_rrdFile};
  carp qq|>>> RRD file $rrd already exists!| and return if -f $rrd;

  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{rrd}{verbose} || 0;
  my $step = $config->{rrd}{step};
  my $heartbeat = $step + 300; # seconds

  my $start = time();
  my $command = qq|create $rrd -b $start -s $step\n|;
  for my $var (@$list) {
    $command .= qq|DS:$var:GAUGE:$heartbeat:U:U\n|;
  }
  $command .= q|RRA:AVERAGE:0.5:1:20
RRA:AVERAGE:0.5:5:96
RRA:AVERAGE:0.5:20:168
RRA:AVERAGE:0.5:80:180
RRA:AVERAGE:0.5:240:730|;
  print $command, "\n" if $verbose;

  RRDp::cmd $command; 
  print $RRDp::error, "\n" if $RRDp::error;  

  RRDp::read;
}

sub update
{
  my ($self, $list) = @_;
  my $rrd = $self->{_rrdFile};
  croak qq|>>> RRD file $rrd not found!| unless -f $rrd;

  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{rrd}{verbose} || 0;

  my $command = qq|update $rrd |.join(':', @$list);
  print $command, "\n" if $verbose;

  print STDERR q|* Filling RRD with Values. One moment please ...\n| if $verbose;
  RRDp::cmd $command;
  print $RRDp::error, "\n" if $RRDp::error;

  RRDp::read;
}

sub graph
{
  my ($self, $attr) = @_;
  carp q|attr must be defined correctly| 
    and return unless defined $attr->{fields};

  # may be we should use some default
  my $rrd = $self->{_rrdFile};
  croak qq|>>> RRD file $rrd not found!| unless -f $rrd;

  my $config = LSF::ConfigReader->instance()->config;

  my $verbose    = $config->{rrd}{verbose} || 0;
  my $width      = $config->{rrd}{width};
  my $height     = $config->{rrd}{height};
  my $comment    = $config->{rrd}{comment} || q|Unknown|;
  my $timeSlices = $config->{rrd}{timeSlices} || [];

  my $vlabel = $attr->{vlabel};

  my $cfrag = qq|--width $width 
--height $height 
--vertical-label '$vlabel' 
--color ARROW#bfbfbf
--lower-limit 0
--alt-autoscale-max|;

  my $fields  = $attr->{fields};
  my $colors  = $attr->{colors};
  my $options = $attr->{options};
  my $titles  = $attr->{titles};
  my $gtag    = $attr->{gtag};

  my $n       = scalar @$fields - 1;
  my $legend  = qq| COMMENT:'$comment'\\n|;
  $legend .= q| COMMENT:"            max    avg     cur\n"|;
  for my $i (0..$n) {
    my $lname  = qq|name$i|;
    my $var    = $fields->[$i];
    my $option = $options->[$i];
    my $color  = $colors->[$i];
    my $title  = $titles->[$i];
    $cfrag .= sprintf qq| DEF:%s=%s:%s:AVERAGE %s:%s%s:'%s'|,
                $lname, $rrd, $var, $option, $lname, $color, trim $title;
    $legend .= sprintf qq|      COMMENT:'%s'|, $title;
    $legend .= sprintf q| GPRINT:%s:MAX:'%%5.0lf' GPRINT:%s:AVERAGE:'%%5.0lf' GPRINT:%s:LAST:'%%5.0lf'"\n"|, 
          $lname, $lname, $lname;
  }
  $cfrag .= qq|$legend|;
  my $now = time;
  my $imageDir = qq|$config->{baseDir}/images/rrd|;
  for my $el (@$timeSlices) {
    my $ptag = $el->{ptag};
    my $tsec = $el->{period};

    my $diff   = $now - $tsec;
    my $image  = qq|$imageDir/${ptag}_$gtag.png|;
    my $command = qq|graph $image --start $diff $cfrag|;

    print $command, "\n" if $verbose;
    RRDp::cmd $command;
    print $RRDp::error, "\n" if $RRDp::error;

    RRDp::read;
  }
}
sub DESTROY
{
  RRDp::end;
}

# package methods/functions
sub create_slot_rrd
{
  my ($pkg, $rrdH, $attr) = @_;
  defined $attr->{filename} or croak qq|Filename attribute must be provided|;
  my $path = $rrdH->rrdFile($attr->{filename});
  -r $path and return;

  my $list = ['totalSlots', 'usedSlots', 'freeSlots'];
  $rrdH->create($list);
}
sub create_rrd
{
  my ($pkg, $rrdH, $attr) = @_;
  defined $attr->{filename} or croak qq|Filename attribute must be provided|;
  my $path = $rrdH->rrdFile($attr->{filename});
  -r $path and return;
  my $gflag = $attr->{global} || 0;

  my $list = [
    'totalJobs',
    'runningJobs', 
    'pendingJobs', 
    'heldJobs',
    'cpuEfficiency',
    'leffJobs'
  ];
  if ($gflag) {
    unshift @$list, ('totalCPU', 'usedCPU', 'freeCPU');
    push @$list, 'nUsers';
  }
  $rrdH->create($list);
}

sub update_rrd
{
  my ($pkg, $rrdH, $attr) = @_;
  defined $attr->{filename} or croak qq|Filename attribute must be provided|;
  scalar @{$attr->{data}} or croak qq|Empty data list provided!|;
  my $path = $rrdH->rrdFile($attr->{filename});
  $rrdH->update($attr->{data});
}

sub create_global_graph
{
  my ($pkg, $rrdH, $attr) = @_;
  defined $attr->{filename} or croak qq|Filename attribute must be provided|;
  $rrdH->rrdFile($attr->{filename});

  defined $attr->{fields} or croak qq|RRD Fields must be provided as an array reference|;
  my $data = {
     fields => $attr->{fields},
     colors => ['#0022e9', '#00b871', '#ffdd22'],
    options => ['LINE2', 'LINE2', 'LINE2'],
     titles => ['  Total', '   Used', '   Free'],
     vlabel => ($attr->{vlabel} || q|CPU|).q| Availability|,
       gtag => $attr->{gtag} || q|cpuwtime|
  };
  $rrdH->graph($data);
}
sub create_graph
{
  my ($pkg, $rrdH, $attr) = @_;
  defined $attr->{filename} or croak qq|filename attribute must be provided|;
  my $path = $rrdH->rrdFile($attr->{filename});
  my $tag = $attr->{tag} || undef;

  # Jobs
  my $vlabel = ((defined $tag) ? $tag : '').q| Jobs|;
  my $gtag   = q|jobwtime|.(defined $tag ? qq|_$tag| : '');

  my $data = {
     fields => ['totalJobs', 'runningJobs', 'pendingJobs', 'heldJobs'],
     colors => ['#00ff00', '#0000ff', '#ff0000', '#ffdd22'],
    options => ['LINE2', 'LINE2', 'LINE2', 'LINE2'],
     titles => ['  Total', 'Running', 'Pending', '   Held'],
     vlabel => trim($vlabel),
       gtag => trim($gtag)
  };
  $rrdH->graph($data);

  # Efficiency
  $vlabel = ((defined $tag) ? $tag : '').q| CPUEff|;
  $gtag   = q|cpueffwtime|.(defined $tag ? qq|_$tag| : '');

  $data = {
     fields => ['cpuEfficiency'],
     colors => ['#0000ff'],
    options => ['LINE2'],
     titles => ['cpuEff'],
     vlabel => trim($vlabel),
       gtag => trim($gtag)
  };
  $rrdH->graph($data);
  
  # Low efficiency jobs
  $vlabel = ((defined $tag) ? $tag : '').q| Jobs(eff<10%)|;
  $gtag   = q|leffwtime|.(defined $tag ? qq|_$tag| : '');

  $data = {
     fields => ['leffJobs'],
     colors => ['#0000ff'],
    options => ['LINE2'],
     titles => ['eff<10%'],
     vlabel => trim($vlabel),
       gtag => trim($gtag)
  };
  $rrdH->graph($data);

  my $show_users = $attr->{show_users} || 0;
  if ($show_users) {
    # number of users
    $vlabel = ((defined $tag) ? $tag : '').q| Users|;
    $gtag   = q|userwtime|.(defined $tag ? qq|_$tag| : '');

    $data = {
       fields => ['nUsers'],
       colors => ['#0000ff'],
      options => ['LINE2'],
       titles => ['No. of Users'],
       vlabel => trim($vlabel),
         gtag => trim($gtag)
    };
    $rrdH->graph($data);
  }
}

1;
__END__
