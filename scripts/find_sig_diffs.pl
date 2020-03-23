#!/usr/bin/perl
use strict;
my $DEBUG = 0;

###############################################################################
#MAIN
###############################################################################
if (scalar(@ARGV) < 2) {
  print "ERROR: Missing arguments.\n";
  exit(1);
}
my $ref_file = $ARGV[0];
my $diff_file = $ARGV[1];
print "ref_file = $ref_file\n" if ($DEBUG);
open(REF_FILEIN, "<", $ref_file);
my %ref_func_self_ticks = {};
while (my $line = <REF_FILEIN>) {
  my @line_arr = split(/,/, $line);
  my $func_name = $line_arr[0];
  my $self_ticks = $line_arr[1];
  chomp($self_ticks);
  $ref_func_self_ticks{$func_name} = $self_ticks;
}
close(REF_FILEIN);

my %func_pos_diff;
my %func_neg_diff;
open(DIFF_FILEIN, "<", $diff_file);
print "diff_file = $diff_file\n" if ($DEBUG);
while (my $line = <DIFF_FILEIN>) {
  my @line_arr = split(/,/, $line);
  my $func_name = $line_arr[0];
  my $self_ticks = $line_arr[1];
  chomp($self_ticks);
  if (my $ref_self_ticks = $ref_func_self_ticks{$func_name}) {
    next if ($ref_self_ticks == $self_ticks);
    my $raw_diff = abs($ref_self_ticks - $self_ticks);
    my $pct_diff = ($raw_diff * 100) / $ref_self_ticks;
    my @diff_pair = ($pct_diff, $raw_diff);;
    if ($ref_self_ticks > $self_ticks) {
      printf("%s improves by %.2f\% (%s ticks).\n", $func_name, $pct_diff,
             $raw_diff) if ($DEBUG);
      $func_neg_diff{$func_name} = \@diff_pair; 
    } else {
      printf("%s degrades by %.2f\% (%s ticks).\n", $func_name, $pct_diff,
             $raw_diff) if ($DEBUG);
      $func_pos_diff{$func_name} = \@diff_pair; 
    }
  }
}
close(DIFF_FILEIN);
print "######### DEGRADATIONS START ########\n";
foreach my $func_name (reverse sort { ${$func_pos_diff{$a}}[0] <=> ${$func_pos_diff{$b}}[0] } keys %func_pos_diff) {
  my $pct_diff = ${$func_pos_diff{$func_name}}[0];
  my $raw_diff = ${$func_pos_diff{$func_name}}[1];
  printf("%s degrades by %.2f\% (%s ticks).\n", $func_name, $pct_diff,
         $raw_diff);
}
print "######### DEGRADATIONS END ########\n\n";
print "######### IMPROVEMENTS START ########\n";
foreach my $func_name (reverse sort { ${$func_neg_diff{$a}}[0] <=> ${$func_neg_diff{$b}}[0] } keys %func_neg_diff) {
  my $pct_diff = ${$func_neg_diff{$func_name}}[0];
  my $raw_diff = ${$func_neg_diff{$func_name}}[1];
  printf("%s improves by %.2f\% (%s ticks).\n", $func_name, $pct_diff,
         $raw_diff);
}
print "######### IMPROVEMENTS END ########\n";
