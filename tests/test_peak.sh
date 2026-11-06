source scripts/lib.sh
test_peak_paused() {
  peak_paused x 10 0.9 && r=nghi || r=chay; assert_eq nghi "$r" peak_over_85_in_hours
  peak_paused x 10 0.84 && r=nghi || r=chay; assert_eq chay "$r" peak_under_85
  peak_paused x 18 0.99 && r=nghi || r=chay; assert_eq chay "$r" peak_after_6pm
  peak_paused x 06 0.99 && r=nghi || r=chay; assert_eq chay "$r" peak_before_7am
  peak_paused x 07 0.85 && r=nghi || r=chay; assert_eq nghi "$r" peak_at_7am_exact_85
  peak_paused x 12 "" && r=nghi || r=chay; assert_eq chay "$r" peak_unknown_usage_runs
}
