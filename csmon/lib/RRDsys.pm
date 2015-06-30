package RRDsys;

use strict;
use warnings;
use Carp;
use RRDp;

use ConfigReader;
use Util qw/trim/;

sub new 
{
  my ($this, $attr) = @_;
  my $class = ref $this || $this;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $rrdtool = $config->{rrd}{rrdtool} || q|/usr/bin/rrdtool|;

  RRDp::start $rrdtool or croak qq|>>> $rrdtool not found! stopped|;
  $RRDp::error_mode = 'catch';

  my $file = $attr->{file} || $config->{rrd}{db};
  my $location = $config->{rrd}{location};
  my $rrdFile = qq|$location/$file|;
  bless { 
    _rrdFile => $rrdFile 
  }, $class;
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

  my $reader = ConfigReader->instance();
  my $config = $reader->config;

  my $verbose    = $config->{rrd}{verbose} || 0;
  my $width      = $config->{rrd}{width};
  my $height     = $config->{rrd}{height};
  my $comment    = $config->{rrd}{comment} || 'Unknown';
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

1;
__END__
