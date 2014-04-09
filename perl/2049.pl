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
use List::Util qw/sum max/;
our $win_goal = 2049;

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
  #print STDERR join ('', map {ord} @keys), "\n";
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
    # win (ASDW)
    '97 97' => 'left',
    '119 119' => 'up',
    '100 100' => 'right',
    '115 115' => 'down',

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
sub get_xy() {
  return my @res = (int rand(4) + 1, int rand(4) + 1);
}

sub new_map() {
  my $map = [
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
    [0,0,0,0,0,0],
  ];
  my @uno = get_xy();
  my @duo;
  do { @duo = get_xy(); } while ("@duo" eq "@uno");
  $map->[$uno[0]][$uno[1]] = 2;
  $map->[$duo[0]][$duo[1]] = 2;
  return $map;
}


sub print_map($){
  if (1) {
    # http://stackoverflow.com/questions/197933/whats-the-best-way-to-clear-the-screen-in-perl
    print "\033[2J";    #clear the screen
    print "\033[0;0H"; #jump to 0,0

    print "Hello!\n";
    print "  <-, ->, v, ^  or a,s,d,w | to move the map\n";
    print "  Esc           or q       | to exit\n";
    print "\n";
  }

  my ($map) = @_;
  for (my $i = 1; $i <= 4; $i ++)
  {
    print STDERR join("\t", map { $_ == 0 ? '.' : $_ } @{$map->[$i]}[1..4]), "\n"
  }
  print STDERR "\n";
}

sub transition($$;$) {
  our ($map, $dir, $need_generate) = @_;
  our $is_movable = 0;
  our $is_win = 0;

  sub cell($$;$) {
    my ($y, $x, $set_val) = @_;
    if ($dir eq 'left'){
      $x = 5 - $x;
      $map->[$y][$x] = $set_val if defined ($set_val);
      return $map->[$y][$x];
    } elsif ($dir eq 'right') {
      $map->[$y][$x] = $set_val if defined ($set_val);
      return $map->[$y][$x];
    } elsif ($dir eq 'up') {
      $x = 5 - $x;
      $map->[$x][$y] = $set_val if defined ($set_val);
      return $map->[$x][$y];
    } elsif ($dir eq 'down') {
      $map->[$x][$y] = $set_val if defined ($set_val);
      return $map->[$x][$y];
    }
    die ('WRONG DIR');
  }

  sub shift_cells($$) {
    my ($i, $start_from) = @_;
    my $first_nonzero = $start_from;
    for (; $first_nonzero >= 0; $first_nonzero --) {
      last if (cell($i, $first_nonzero) != 0);
    }
    my $shift_gap = $start_from - $first_nonzero;
    for (my $k = $first_nonzero; $k >= 1 && $shift_gap >0; $k --) {
      $is_movable = 1;
      cell($i, $k + $shift_gap, cell($i, $k));
      cell($i, $k, 0);
    }
  }

  sub merge_cells($$) {
    my ($i, $j) = @_;
    #print_map($map);
    # TODO add 2049 check
    my $cell_prev = cell($i, $j-1);
    my $cell_curr = cell($i, $j);
    if (($cell_prev == $cell_curr || ($cell_prev + $cell_curr == $win_goal && ($cell_prev == 1 || $cell_curr == 1))) && $cell_curr != 0) {
      $is_movable = 1;
      $is_win = 1 if ($win_goal == cell($i, $j, cell($i, $j) + cell($i, $j-1)));
      cell($i, $j-1, 0);
    }
  }

  for my $i (1..4) {
    for my $j (reverse 1..4) {
      shift_cells($i, $j);
    }

    for my $j (reverse 1..4) {
      merge_cells($i, $j);
      shift_cells($i, $j - 1);
    }
  }
  if ($is_win) {
    print_map($map);
    menu_win();
  }
  if ($is_movable && $need_generate) {
    # generate new piece
    my @new;
    do { @new = get_xy(); } while ( $map->[$new[0]][$new[1]] != 0);
    my $max_piece = max (map { max @$_ } @$map);
    # 2048 for 2049 is a threshold for spawning 1s
    my $new_piece = $max_piece >= $win_goal-1 ? 1 : 2;
    $map->[$new[0]][$new[1]] = $new_piece;
    
    #my @free_spots = grep { $_ > 0 } map { $_->[0] } @$map;
    #menu_gameover() if (@free_spots == 0);
    #gen...
  }
    
  return ($is_movable, $map);
}

#### util functions
#### -----------------------------

#### -----------------------------
#### menu

sub menu_win() {
    die "you win!\n";
}

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
    if (console_is_esc(\@char_ext) || $char_ext[0] eq 'q')
    {
      menu_exit();
    } # if..char

    elsif ($arrow = console_is_arrow(\@char_ext))
    {
      ($res, $map) = transition($map, $arrow, 1);
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

use Storable qw(dclone);

# fills this array:
# TEST [000], FILE [2049.pl], LINE [522], FUNC [main::unit_ok], COND [PASS!]
sub unit_ok($$)
{
  my ($p_units, $cond) = @_;

  my @caller = caller(0);
  $$p_units->{num_all}++;

  if ($cond)
  {
  }
  else
  {
    $$p_units->{num_fails} ++;
  }

  my $pass_count = $$p_units->{num_all} - $$p_units->{num_fails};
  my $test_line = sprintf("TEST [%03d], FILE [%s], LINE [%d], FUNC [%s], COND [%s], RESULTS [%0.1f%% (%s/%s)]",
    $$p_units->{num_all},
    @caller[1 .. 3],
    $cond ? "PASS!" : "FAIL :(",
    100.0 * ($pass_count / $$p_units->{num_all}),
    $pass_count,
    $$p_units->{num_all}
  );
  push @{$$p_units->{all}}, $test_line;

  print STDERR "$test_line\n";
}

sub unit_tests()
{
  my $units = {num_fails => 0, all => []};

  #### #### movable? #### ####

  my $map_no_sum = [ [0, 0, 0, 0, 0, 0],
                     [0, 0, 0, 2, 0, 0],
                     [0, 0, 0, 0, 0, 0],
                     [0, 0, 2, 0, 0, 0],
                     [0, 0, 0, 0, 0, 0],
                     [0, 0, 0, 0, 0, 0] ];

  my ($moved, $new_map) = transition(dclone($map_no_sum), 'down');
  unit_ok(\$units, $moved);

  my ($moved, $new_map) = transition(dclone($map_no_sum), 'up');
  unit_ok(\$units, $moved);

  my ($moved, $new_map) = transition(dclone($map_no_sum), 'right');
  unit_ok(\$units, $moved);

  my ($moved, $new_map) = transition(dclone($map_no_sum), 'left');
  unit_ok(\$units, $moved);

  #### #### not movable? #### ####

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 2, 2, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'down');
  unit_ok(\$units, !$moved);

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 2, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'up');
  unit_ok(\$units, !$moved);

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 2, 0],
                                       [0, 0, 0, 0, 2, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'right');
  unit_ok(\$units, !$moved);

  my ($moved, $new_map) = transition([ [0, 0, 0, 0, 0, 0],
                                       [0, 2, 0, 0, 0, 0],
                                       [0, 2, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0],
                                       [0, 0, 0, 0, 0, 0] ], 'left');
  unit_ok(\$units, !$moved);

  #### #### basic sum+shift #### ####

  my $map_sum_hor = [ [0, 0, 0, 0, 0, 0],
                      [0, 0, 2, 2, 0, 0],
                      [0, 0, 0, 0, 0, 0],
                      [0, 0, 0, 0, 0, 0],
                      [0, 0, 0, 0, 0, 0],
                      [0, 0, 0, 0, 0, 0] ];

  my ($moved, $new_map) = transition(dclone($map_sum_hor), 'down');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[4][2] == 2);
  unit_ok(\$units, $new_map->[4][3] == 2);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  my ($moved, $new_map) = transition(dclone($map_sum_hor), 'up');
  unit_ok(\$units, !$moved);
  unit_ok(\$units, $new_map->[1][2] == 2);
  unit_ok(\$units, $new_map->[1][3] == 2);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  my ($moved, $new_map) = transition(dclone($map_sum_hor), 'right');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][4] == 4);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  my ($moved, $new_map) = transition(dclone($map_sum_hor), 'left');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][1] == 4);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  my $map_sum_ver = [ [0, 0, 0, 0, 0, 0],
                      [0, 0, 0, 0, 0, 0],
                      [0, 0, 2, 0, 0, 0],
                      [0, 0, 2, 0, 0, 0],
                      [0, 0, 0, 0, 0, 0],
                      [0, 0, 0, 0, 0, 0] ];

  my ($moved, $new_map) = transition(dclone($map_sum_ver), 'down');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[4][2] == 4);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  my ($moved, $new_map) = transition(dclone($map_sum_ver), 'up');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][2] == 4);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  my ($moved, $new_map) = transition(dclone($map_sum_ver), 'right');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[2][4] == 2);
  unit_ok(\$units, $new_map->[3][4] == 2);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  my ($moved, $new_map) = transition(dclone($map_sum_ver), 'left');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[2][1] == 2);
  unit_ok(\$units, $new_map->[3][1] == 2);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 4);

  #### #### more complex sum + shift #### #####

  my $map_sum_1 = [ [0, 0, 0, 0, 0, 0],
                    [0, 2, 2, 2, 2, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0] ];

  my ($moved, $new_map) = transition(dclone($map_sum_1), 'left');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][1] == 4);
  unit_ok(\$units, $new_map->[1][2] == 4);
  
  my ($moved, $new_map) = transition(dclone($map_sum_1), 'right');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][4] == 4);
  unit_ok(\$units, $new_map->[1][3] == 4);

  my $map_sum_1 = [ [0, 0, 0, 0, 0, 0],
                    [0, 2, 2, 2, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0] ];

  my ($moved, $new_map) = transition(dclone($map_sum_1), 'left');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][1] == 4);
  unit_ok(\$units, $new_map->[1][2] == 2);

  my ($moved, $new_map) = transition(dclone($map_sum_1), 'right');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][4] == 4);
  unit_ok(\$units, $new_map->[1][3] == 2);

  my $map_sum_1 = [ [0, 0, 0, 0, 0, 0],
                    [0, 2, 0, 0, 2, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0] ];

  my ($moved, $new_map) = transition(dclone($map_sum_1), 'left');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][1] == 4);

  my ($moved, $new_map) = transition(dclone($map_sum_1), 'right');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][4] == 4);

  #### #### complex sum+shift #### ####

  my $map_sum_2 = [ [0, 0, 0, 0, 0, 0],
                    [0, 2, 2, 2, 2, 0],
                    [0, 0, 2, 2, 0, 0],
                    [0, 2, 0, 0, 2, 0],
                    [0, 2, 2, 2, 2, 0],
                    [0, 0, 0, 0, 0, 0] ];

  my ($moved, $new_map) = transition(dclone($map_sum_2), 'right');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][4] == 4);
  unit_ok(\$units, $new_map->[1][3] == 4);
  unit_ok(\$units, $new_map->[2][4] == 4);
  unit_ok(\$units, $new_map->[3][4] == 4);
  unit_ok(\$units, $new_map->[4][4] == 4);
  unit_ok(\$units, $new_map->[4][3] == 4);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 24);

  my ($moved, $new_map) = transition(dclone($map_sum_2), 'left');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][1] == 4);
  unit_ok(\$units, $new_map->[1][2] == 4);
  unit_ok(\$units, $new_map->[2][1] == 4);
  unit_ok(\$units, $new_map->[3][1] == 4);
  unit_ok(\$units, $new_map->[4][1] == 4);
  unit_ok(\$units, $new_map->[4][2] == 4);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 24);

  my ($moved, $new_map) = transition(dclone($map_sum_2), 'down');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[4][1] == 4);
  unit_ok(\$units, $new_map->[4][2] == 4);
  unit_ok(\$units, $new_map->[4][3] == 4);
  unit_ok(\$units, $new_map->[4][4] == 4);
  unit_ok(\$units, $new_map->[3][1] == 2);
  unit_ok(\$units, $new_map->[3][2] == 2);
  unit_ok(\$units, $new_map->[3][3] == 2);
  unit_ok(\$units, $new_map->[3][4] == 2);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 16 + 8);

  my ($moved, $new_map) = transition(dclone($map_sum_2), 'up');
  unit_ok(\$units, $moved);
  unit_ok(\$units, $new_map->[1][1] == 4);
  unit_ok(\$units, $new_map->[1][2] == 4);
  unit_ok(\$units, $new_map->[1][3] == 4);
  unit_ok(\$units, $new_map->[1][4] == 4);
  unit_ok(\$units, $new_map->[2][1] == 2);
  unit_ok(\$units, $new_map->[2][2] == 2);
  unit_ok(\$units, $new_map->[2][3] == 2);
  unit_ok(\$units, $new_map->[2][4] == 2);
  unit_ok(\$units, sum (map { sum @$_ } @$new_map) == 16 + 8);

  return $units->{num_fails};
}

die "tests fail\n" if unit_tests() != 0;
#### unit tests
#### -----------------------------

menu();
