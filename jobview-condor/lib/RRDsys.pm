package RRDsys;

use strict;
use warnings;
use Carp;
use RRDp;

use ConfigReader;
use Util qw/trim/;

require Exporter;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT = qw( 
);
our @EXPORT_OK = qw(
   create_rrd     
   update_rrd
 create_graph 
);
sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
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
  defined $file or die qq|file argument missing!|;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $location = $config->{rrd}{location};
  qq|$location/$file|;
}
sub rrdFile
{
  my ($self, $file) = @_;
  defined $file or return $self->{_rrdFile};

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $location = $config->{rrd}{location};
  $self->{_rrdFile} = qq|$location/$file|;
  $self->{_rrdFile};
}

sub create
{
  my ($self, $list) = @_;

  my $rrd = $self->{_rrdFile};
  carp qq|>>> RRD file $rrd already exists!| and return if -f $rrd;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
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

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{rrd}{verbose} || 0;

  my $command = qq|update $rrd |.join(':', @$list);
  print $command, "\n" if $verbose;

  print q|* Filling RRD with Values. One moment please ...|, "\n" if $verbose;
  RRDp::cmd $command;
  print $RRDp::error, "\n" if $RRDp::error;

  RRDp::read;
}

sub graph
{
  my ($self, $attr) = @_;
  carp q|attr must be defined correctly| and return unless defined $attr->{fields};

  # may be we should use some default
  my $rrdFile = $self->{_rrdFile};
  croak qq|>>> RRD file $rrdFile not found!| unless -r $rrdFile;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $verbose    = $config->{rrd}{verbose} || 0;
  my $width      = $config->{rrd}{width} || 300;
  my $height     = $config->{rrd}{height} || 100;
  my $comment    = $config->{rrd}{comment} || 'Unknown';
  my $timeSlices = $config->{rrd}{timeSlices} || [];

  my $vlabel = $attr->{vlabel};

  my $cfrag = qq|--width $width 
--height $height 
--vertical-label '$vlabel' 
--color ARROW#bfbfbf
--lower-limit 0
--alt-autoscale-max |;

  my $fields  = $attr->{fields};
  my $colors  = $attr->{colors};
  my $options = $attr->{options};
  my $titles  = $attr->{titles};
  my $gtag    = $attr->{gtag};

  my $n       = scalar @$fields - 1;
  my $legend  = q| COMMENT:"|.$comment.q|\n"|;
  $legend .= q| COMMENT:"           max    avg     cur\n"|;
  for my $i (0..$n) {
    my $lname  = qq|name$i|;
    my $var    = $fields->[$i];
    my $option = $options->[$i];
    my $color  = $colors->[$i];
    my $title  = $titles->[$i];
    $cfrag .= sprintf qq| DEF:%s=%s:%s:AVERAGE %s:%s%s:'%s'|,
                $lname, $rrdFile, $var, $option, $lname, $color, trim $title;
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

sub create_rrd
{
  my ($rrdH, $attr) = @_;
  defined $attr->{filename} or die qq|filename attribute must be provided|;
  my $path = $rrdH->rrdFile($attr->{filename});
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
    unshift @$list, ('totalCPU','freeCPU');
    push @$list, 'nUsers';
  }
  $rrdH->create($list);
}

sub update_rrd
{
  my ($rrdH, $attr) = @_;
  defined $attr->{filename} or die qq|filename attribute must be provided|;
  scalar @{$attr->{data}} or die qq|empty data list provided!|;
  my $path = $rrdH->rrdFile($attr->{filename});
  $rrdH->update($attr->{data});
}

sub create_graph
{
  my ($rrdH, $tag) = @_;

  # Jobs
  my $vlabel = ((defined $tag) ? $tag : '').q| Jobs|;
  my $gtag   = q|jobwtime|.(defined $tag ? qq|_$tag| : '');

  my $attr = {
     fields => ['totalJobs', 'runningJobs', 'pendingJobs', 'heldJobs'],
     colors => ['#003399', '#009900', '#ff3300', '#CC9900'],
    options => ['LINE2', 'LINE2', 'LINE2', 'LINE2'],
     titles => ['  Total', 'Running', 'Pending', '   Held'],
     vlabel => trim($vlabel),
       gtag => trim($gtag)
  };
  $rrdH->graph($attr);

  # Efficiency
  $vlabel = ((defined $tag) ? $tag : '').q| CPUEff|;
  $gtag   = q|cpueffwtime|.(defined $tag ? qq|_$tag| : '');

  $attr = {
     fields => ['cpuEfficiency'],
     colors => ['#003399'],
    options => ['LINE2'],
     titles => ['cpuEff'],
     vlabel => trim($vlabel),
       gtag => trim($gtag)
  };
  $rrdH->graph($attr);
  
  # Low efficiency jobs
  $vlabel = ((defined $tag) ? $tag : '').q| Jobs(eff<10%)|;
  $gtag   = q|leffwtime|.(defined $tag ? qq|_$tag| : '');

  $attr = {
     fields => ['leffJobs'],
     colors => ['#003399'],
    options => ['LINE2'],
     titles => ['eff<10%'],
     vlabel => trim($vlabel),
       gtag => trim($gtag)
  };
  $rrdH->graph($attr);
}

1;
__END__
