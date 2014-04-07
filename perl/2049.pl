#!/usr/bin/perl
use strict;

sub usage
{
  my $s = <<END;
  This 2049 console game, enjoy!
  (c) Sergey Vinogradov
END
  die $s;
}

use Data::Dumper;

#### -----------------------------
#### Console input

# this note was helpful: http://ahinea.com/en/tech/perl-unicode-pack-unpack-hack.html
# this note was helpful: http://perldoc.perl.org/Time/HiRes.html

use Term::ReadKey;
use Time::HiRes qw( usleep );
sub console_read_key()
{
  ReadMode 4; 
  my @keys;
  my $key;

  # get 1st char
  while (not defined ($key = ReadKey(-1))) { usleep(10000); }
  push @keys, $key;

  # get 2nd char immediately, if not - it's not a utf8 char
  unless ($key =~ /[a-z0-9\\\/\(\)\[\]\{\}\|`~'":;\.,<>\-\+_=\*\&\^\%\$\#\@\!\?]/i)
  {
    while (1) {
      $key = ReadKey(0.01);
      last if (!defined $key);
      push @keys, $key;
    }
  }
  ReadMode 1;
  $key = pack "U0C*", unpack "C*", join ('', @keys);
  return ($key, @keys);
}

sub console_is_esc($) {
  my $chars = shift;
  my $char = join ' ', map { ord $_ } @$chars;
  return $char eq '27 27';
}

sub console_is_arrow($) {
  my $chars = shift;
  my $char = join ' ', map { ord $_ } @$chars;

  my $keys = {
    # mac
    '27 27 91 68' => 'left',
    '27 27 91 65' => 'up',
    '27 27 91 67' => 'right',
    '27 27 91 66' => 'down',

    # linux
    '27 91 68' => 'left',
    '27 91 65' => 'up',
    '27 91 67' => 'right',
    '27 91 66' => 'down',
  };
  return $keys->{$char};
}

#### Console input
#### -----------------------------


#### -----------------------------
#### util functions

sub new_map() {
  my $map = [
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
  ];
  sub get_xy() {
    return my @res = (int rand(4) + 1, int rand(4) + 1);
  }
  my @uno = get_xy();
  my @duo;
  do { @duo = get_xy(); } while ("@duo" eq "@uno");
  $map->[$uno[0]][$uno[1]] = 2;
  $map->[$duo[0]][$duo[1]] = 2;
  return $map;
}


sub print_map($){
  # http://stackoverflow.com/questions/197933/whats-the-best-way-to-clear-the-screen-in-perl
  print "\033[2J";    #clear the screen
  print "\033[0;0H"; #jump to 0,0

  print "Hello!\n";
  print "  <-, ->, v, ^ | to move the map\n";
  print "  Esc          | to exit\n";
  print "\n";

  my ($map) = @_;
  for (my $i = 1; $i <= 4; $i ++)
  {
    print join("\t", @{$map->[$i]}), "\n"
  }
  print "> \n"
}

sub transition($$) {
  my ($map, $dir) = @_;
  if ($dir eq 'left'){
    print 'left';
  } elsif ($dir eq 'right') {
    my $is_movable = 0;
    for (my $i = 1; $i <= 4; $i++) {
      for (my $j = 4; $j >= 1; $j--) {
        # merge
        if ($map->[$i][$j-1] == $map->[$i][$j] && $map->[$i][$j] != 0) {
          $is_movable = 1;
          $map->[$i][$j] += $map->[$i][$j-1];
          $map->[$i][$j-1] = 0;
        }
        
        # shift
        my $first_nonzero = $j;
        for (; $first_nonzero >= 0; $first_nonzero --) {
          last if ($map->[$i][$first_nonzero] != 0);
        }
        my $shift_gap = $j - $first_nonzero;
        for (my $k = $first_nonzero; $k >= 1 && $shift_gap >0; $k --) {
          $is_movable = 1;
          $map->[$i][$k + $shift_gap] = $map->[$i][$k];
          $map->[$i][$k] = 0;
        }
      }
    }
    if ($is_movable) {
      # generate new piece
      #my @free_spots = grep { $_ > 0 } map { $_->[0] } @$map;
      #menu_gameover() if (@free_spots == 0);
      #gen...
    }
    print 'right';
    return ($is_movable, $map);
  } elsif ($dir eq 'up') {
    print 'up';
  } elsif ($dir eq 'down') {
    print 'down';
  } else {
    print 'WRONG DIR';
    return (0, $map);
  }
  print "\n";
  return (1, $map);
}

#### util functions
#### -----------------------------

#### -----------------------------
#### menu

sub menu_exit()
{
  print "\nexit\n";
  exit 0;
}

sub menu()
{
  my $map = new_map();
  print_map($map);

  while (1)
  {
    my (@char_ext) = console_read_key();
    my $arrow;
    my $res;

    # exit
    if (console_is_esc(\@char_ext))
    {
      menu_exit();
    } # if..char

    elsif ($arrow = console_is_arrow(\@char_ext))
    {
      ($res, $map) = transition($map, $arrow);
      if ($res)
      {
        print_map($map);
      }
    } # if..char
  } # while(1)

  menu_exit();
}


#### menu
#### -----------------------------

#### -----------------------------
#### unit tests

use List::Util qw/sum/;

# fills this array:
# TEST [000], FILE [2049.pl], LINE [522], FUNC [main::unit_ok], COND [PASS!]
sub unit_ok($$)
{
  my ($p_units, $cond) = @_;

  my @caller = caller(0);
  my $test_line = sprintf("TEST [%03d], FILE [%s], LINE [%d], FUNC [%s], COND [%s]",
    $$p_units->{num_all}++,
    @caller[1 .. 3],
    $cond ? "PASS!" : "FAIL :("
  );

  push @{$$p_units->{all}}, $test_line;
  if ($cond)
  {
  }
  else
  {
    $$p_units->{num_fails} ++;
  }

  print STDERR "$test_line\n";
}

sub unit_tests()
{
  my $units = {num_fails => 0, all => []};

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 2, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'left');
  unit_ok(\$units, $moved);

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 2, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'down');
  unit_ok(\$units, $moved);

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 2, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'right');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][4] == 4);
  unit_ok(\$units, $new_map->[1][3] == 0);
  unit_ok(\$units, sum (@{$new_map->[1]}) == 4);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 2, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'right');
  unit_ok(\$units, $moved);

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 2, 0, 0],
                                       [0, 0, 0, 0, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'right');
  unit_ok(\$units, $moved);
  
  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 2, 0],
                                       [0, 0, 0, 0, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'right');
  unit_ok(\$units, !$moved);

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 2, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'up');
  unit_ok(\$units, !$moved);

  return $units->{num_fails};
}

die "tests fail\n" if unit_tests() != 0;
#### unit tests
#### -----------------------------

menu();
