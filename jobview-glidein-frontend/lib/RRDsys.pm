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

  RRDp::start "/usr/bin/rrdtool" or croak qq|rrdtool not found! stopped|;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
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

  my $rrdfile = $self->{_rrdFile};
  croak qq|RRD file $rrdfile already exists!| if -f $rrdfile;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{rrd}{verbose} || 0;
  my $step    = $config->{rrd}{step};

  my $start = time() - 10; # this is anyway the default
  my $command = qq|create $rrdfile -b $start -s $step\n|;
  for my $var (@$list) {
    $command .= qq|DS:$var:GAUGE:720:U:U\n|;
  }
  $command .= qq|RRA:AVERAGE:0.5:1:10
RRA:AVERAGE:0.5:5:48
RRA:AVERAGE:0.5:10:168
RRA:AVERAGE:0.5:20:336
RRA:AVERAGE:0.5:120:730|;
  print $command, "\n" if $verbose;

  RRDp::cmd $command; 
}

sub update
{
  my ($self, $list) = @_;
  my $rrdfile = $self->{_rrdFile};
  croak qq|RRD file $rrdfile not found!| unless -f $rrdfile;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{rrd}{verbose} || 0;

  my $command = qq|update $rrdfile |.join(':', @$list);
  if ($verbose) {
    print qq|* Filling RRD with Values. One moment please ...\n|;
    print $command, "\n";
  }
  RRDp::cmd $command;
  my $answer = RRDp::read;
}

sub graph
{
  my ($self, $attr) = @_;
  croak qq|attr must be defined correctly| unless defined $attr->{fields};
  # may be we should use some default

  my $rrdfile = $self->{_rrdFile};
  croak qq|RRD file $rrdfile not found!| unless -f $rrdfile;

  my $reader = ConfigReader->instance();
  my $config = $reader->config;
  my $verbose = $config->{rrd}{verbose} || 0;
  my $width  = $config->{rrd}{width} || 300;
  my $height = $config->{rrd}{height} || 100;
  my $comment = $config->{rrd}{comment} || 'Unknown';
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
  $legend .= q| COMMENT:"            max    avg     cur\n"|;
  for my $i (0..$n) {
    my $lname  = qq|name$i|;
    my $var    = $fields->[$i];
    my $option = $options->[$i];
    my $color  = $colors->[$i];
    my $title  = $titles->[$i];
    $cfrag .= sprintf q| DEF:%s=%s:%s:AVERAGE %s:%s%s:'%s'|,
                $lname, $rrdfile, $var, $option, $lname, $color, trim $title;
    $legend .= sprintf q|      COMMENT:'%s'|, $title;
    $legend .= sprintf q| GPRINT:%s:MAX:'%%5.0lf' GPRINT:%s:AVERAGE:'%%5.0lf' GPRINT:%s:LAST:'%%5.0lf'"\n"|, 
          $lname, $lname, $lname;
  }
  $cfrag .= $legend;
  my $now = time;
  my $imageDir = qq|$config->{baseDir}/images/rrd|;
  for my $el (@$timeSlices) {
    my $ptag = $el->{ptag};
    my $tsec = $el->{period};
    my $diff  = $now - $tsec;
    my $image = qq|$imageDir/${ptag}_$gtag.gif|;
    my $command = qq|graph $image --start $diff $cfrag|;

    print $command, "\n" if $verbose;
    RRDp::cmd $command;
    my $ans = RRDp::read;
  }
}
sub DESTROY
{
  RRDp::end;
}

1;
__END__
