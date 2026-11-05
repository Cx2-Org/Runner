test_bot() {
  source scripts/lib.sh
  assert_eq 2 "$(bot_no_from_labels ',ios,bot:ironman,ci-run,')" bot_ironman
  assert_eq 1 "$(bot_no_from_labels ',bot:queenie,')" bot_queenie
  assert_eq "" "$(bot_no_from_labels ',ios,')" bot_none
  assert_eq "Spider Man" "$(bot_name 3)" name3
  assert_eq "Captain Queenie" "$(bot_name 1)" name1
  assert_eq "Runner" "$(bot_name 0)" name0
}
