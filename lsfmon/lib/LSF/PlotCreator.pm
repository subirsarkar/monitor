package LSF::PlotCreator;

use strict;
use warnings;
use Carp;
use IO::File;
use Data::Dumper;
use List::Util qw/max min/;

use GD;
use GD::Graph::pie;
use GD::Graph::bars;
use GD::Graph::hbars;
use GD::Graph::colour qw/:colours :lists :files :convert/;
use Image::Magick;

use LSF::ConfigReader;

require Exporter;
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/createPNG plotPie plotBar drawLegends createPNGWithIM/;

sub createPNG
{
  my ($image, $file) = @_;
  my $fh = IO::File->new($file, 'w');
  croak qq|Failed to open $file, $!, stopped| unless ($fh and $fh->opened);
  binmode $fh;
  print $fh $image->png;
  $fh->close;
}

sub createPNGWithIM
{
  my $params = shift;
  my $image  = $params->{image};
  return unless $image;

  my $width  = $params->{width};
  my $height = $params->{height};
  my $file   = $params->{file};

  eval {
    my $magick = Image::Magick->new(magick => 'png');
    $magick->BlobToImage($image->png);
    $magick->Resize(width => $width, height => $height, blur => 0.9); # small and anti-aliased one
    $magick->Write($file);
  };
  carp qq|ImageMagick failed! Reason: $@| if $@;
}

sub getFont
{
  my $package = shift;
  my $config = LSF::ConfigReader->instance()->config;
  my $fontDir  = $config->{plotcreator}{font}{dir} || qq|$config->{baseDir}/fonts|;
  my $index    = $config->{plotcreator}{font}{default} || 1;
  my $fontName = $config->{plotcreator}{font}{names}[$index] || 'arial.ttf';
  qq|$fontDir/$fontName|;
}

sub drawLegends
{
  my $data = shift;
  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{plotcreator}{image}{legends}{verbose} || 0;
  print Data::Dumper->Dump([$data], [qw/plotdata/]) if $verbose;

  my ($colors, $labels, $values) = ($data->[0], $data->[1], $data->[2]);

  my $width  = $config->{plotcreator}{image}{legends}{width};
  my $height = $config->{plotcreator}{image}{legends}{height};

  # Create a new image
  my $image = GD::Image->new($width, $height);
  my $font = __PACKAGE__->getFont;

  my $gdcolors = {
           white => $image->colorAllocate(255,255,255), 
           black => $image->colorAllocate(0,0,0),
            grey => $image->colorAllocate(132,132,132),
            blue => $image->colorAllocate(206,206,255),
        leftblue => $image->colorAllocate(231,231,255),
      bottomblue => $image->colorAllocate(165,165,206),
       rightblue => $image->colorAllocate(123,123,156),
         topblue => $image->colorAllocate(214,214,255)
  };
  # Make the background transparent and interlaced
  $image->transparent($gdcolors->{white});
  $image->interlaced('true');

  my $n = scalar(@$labels) - 1;
  my $xleft = 10;
  my $ytop  = 10;
  my $xstep = $config->{plotcreator}{image}{legends}{xstep} || 100;
  my $ystep = $config->{plotcreator}{image}{legends}{ystep} || 18;
  my $max_re = $config->{plotcreator}{image}{legends}{max_re} || 4;
  my $index = 0;
  my ($x,$y) = ($xleft, $ytop);
  for my $l (0..$n) {
     print join(" ", $labels->[$l], $x, $y), "\n" if $verbose;
     __PACKAGE__->legend($image, {
           fillColor => $image->colorAllocate(hex2rgb($colors->[$l])),
              colors => $gdcolors,
                   x => $x,
                   y => $y,
                font => $font,
                text => $labels->[$l]
     });    
     $x = $xleft + (++$index) * $xstep;
     if ($index > $max_re) {
       $index = 0;
       $x = $xleft;
       $y += $ystep;
     }
  }
  $image;
}

sub legend
{
  my ($package, $image, $attr) = @_;
  my $colors = $attr->{colors};

  # A filled rectangle with shadow
  $image->filledRectangle($attr->{x},   $attr->{y},   $attr->{x}+35, $attr->{y}+15, $colors->{white});
  $image->filledRectangle($attr->{x}+3, $attr->{y}+3, $attr->{x}+35, $attr->{y}+15, $colors->{grey});
  $image->filledRectangle($attr->{x},   $attr->{y},   $attr->{x}+32, $attr->{y}+12, $attr->{fillColor});
  $image->rectangle($attr->{x},         $attr->{y},   $attr->{x}+32, $attr->{y}+12, $colors->{white});

  $image->line($attr->{x}+1,  $attr->{y},    $attr->{x}+31, $attr->{y},    $colors->{topblue});
  $image->line($attr->{x}+32, $attr->{y}+1,  $attr->{x}+32, $attr->{y}+11, $colors->{rightblue});
  $image->line($attr->{x}+1,  $attr->{y}+12, $attr->{x}+31, $attr->{y}+12, $colors->{bottomblue});
  $image->line($attr->{x},    $attr->{y}+1,  $attr->{x},    $attr->{y}+11, $colors->{leftblue});

  # Draw the text
  $image->stringFT($colors->{black}, $attr->{font}, 9, 0, $attr->{x}+40, $attr->{y}+12, $attr->{text});
}

sub plotPie
{
  my ($title, $data, $scale) = @_;

  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{plotcreator}{image}{pie}{verbose} || 0;
  print Data::Dumper->Dump([$data], [qw/plotdata/]) if $verbose;

  $scale = 1 unless defined $scale;
  my ($colors, $labels, $values) = ($data->[0], $data->[1], $data->[2]);

  my $width  = $config->{plotcreator}{image}{pie}{width};
  my $height = $config->{plotcreator}{image}{pie}{height};
  my $font   = __PACKAGE__->getFont;

  my $graph = GD::Graph::pie->new($width * $scale, $height * $scale);
  $graph->set_text_clr('black');
  $graph->set_title_font($font, 9 * $scale);
  $graph->set_value_font($font, 8 * $scale);
  $graph->set(
             title => $title,
          l_margin => 15 * $scale,
          r_margin => 15 * $scale,
       start_angle => 90,
       transparent => 0,
        line_width => $scale,
             dclrs => $colors,
         accentclr => 'black',
              '3d' => 1,
      axislabelclr => '#dddddd',
    suppress_angle => 5 
  );
  $graph->plot([$values, $values]) or carp $graph->error;
}

sub plotBar
{
  my ($title, $x_label, $y_label, $data) = @_;

  my $config = LSF::ConfigReader->instance()->config;
  my $verbose = $config->{plotcreator}{image}{bar}{verbose} || 0;
  print Data::Dumper->Dump([$data], [qw/plotdata/]) if $verbose;
  
  my ($colors, $labels, $values) = ($data->[0], $data->[1], $data->[2]);
  my $max_value = max(@$values);

  my $mlen = $config->{plotcreator}{image}{bar}{max_label_len} || 8;
  @$labels = map { substr $_, 0, min(length $_, $mlen) } @$labels;
  my $max_len = max( map { length $_ } @$labels );

  my $width  = $config->{plotcreator}{image}{bar}{width};
  my $height = $config->{plotcreator}{image}{bar}{height};
  my $font   = __PACKAGE__->getFont;
  my $axis_space = $config->{plotcreator}{image}{bar}{axis_space} || 8;
  $axis_space /= 2 unless $max_len > $mlen/2;

  my $graph = GD::Graph::hbars->new($width, $height);
  $graph->set_text_clr('black');
  $graph->set_title_font($font,  10);
  $graph->set_x_axis_font($font,  9);
  $graph->set_y_axis_font($font,  9);
  $graph->set_x_label_font($font, 8);
  $graph->set_y_label_font($font, 8);
  $graph->set_values_font($font,  7);
  $graph->set(
               title => $title,
             x_label => $x_label,
             y_label => $y_label,
    x_label_position => .5,
    y_label_position => .5,
         y_max_value => $max_value*1.1,
         y_min_value => 0,
               dclrs => $colors,
               bgclr => 'white',
           accentclr => 'white',
         transparent => 0,
          interlaced => 0,
          cycle_clrs => 1,
       y_tick_number => 5,
     y_number_format => '%d',
       y_plot_values => 0,
       x_plot_values => 0,
           zero_axis => 0,
         show_values => 1,
         bar_spacing => 15,
           bar_width => 30,
            box_axis => 0,
         tick_length => 0,
          text_space => $config->{plotcreator}{image}{bar}{text_space} || 4,
          axis_space => $axis_space
  );
  $graph->plot([$labels, $values]) or carp $graph->error;
}                                              

1;
__END__
