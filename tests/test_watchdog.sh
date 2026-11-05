test_watchdog() {
  source scripts/lib.sh
  local d; d=$(mktemp -d)
  local t0=$SECONDS
  run_with_idle_kill 2 "$d/a" -- bash -c 'echo a; sleep 8'; local rc=$?
  assert_eq 124 "$rc" idle_kill_rc
  assert_eq 1 "$(( SECONDS - t0 < 7 ))" idle_kill_fast
  run_with_idle_kill 3 "$d/b" -- bash -c 'for i in 1 2 3; do echo $i; sleep 1; done; exit 5'; rc=$?
  assert_eq 5 "$rc" passthrough_rc
  assert_eq 3 "$(tail -1 "$d/b")" output_kept
  rm -rf "$d"
}
