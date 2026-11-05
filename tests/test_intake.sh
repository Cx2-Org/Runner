test_tg_parse() {
  source scripts/lib.sh
  local out; out=$(tg_parse_giao tests/fixtures/tg_updates.json -1004420681690 461)
  assert_eq 2 "$(grep -c . <<<"$out")" parse_count
  assert_eq "tg:-1004420681690:11" "$(sed -n 1p <<<"$out" | jq -r .key)" parse_key
  assert_eq "làm tính năng A cho iOS" "$(sed -n 1p <<<"$out" | jq -r .text)" parse_text
  assert_eq "sửa lỗi B
dòng 2" "$(sed -n 2p <<<"$out" | jq -r .text)" parse_bot_suffix
  assert_eq 106 "$(tg_max_update_id tests/fixtures/tg_updates.json)" max_update
}
test_intake_idempotent() {
  ( source tests/stubs.sh; make_stubs
    cp tests/fixtures/tg_updates.json "$STUB/updates.json"
    export REPO=x/y TG_BOT_TOKEN_1=t TG_CHAT_ID=-1004420681690 TG_THREAD_ID=461
    bash scripts/intake.sh; bash scripts/intake.sh
    assert_eq 2 "$(grep -c '^gh issue create' "$STUB/log")" intake_creates_once
    assert_eq 2 "$(jq '[.[] | select(.labels | index("inbox"))] | length' "$STUB/issues.json")" intake_inbox_label
    assert_eq 1 "$(jq '[.[] | select(.body | contains("<!-- tg:-1004420681690:12 -->"))] | length' "$STUB/issues.json")" intake_key_in_body
    assert_eq 1 "$(grep -c 'offset=107' "$STUB/log" | tr -d ' ' | sed 's/^[2-9]$/1/')" intake_ack
    echo "$PASS $FAIL" > /tmp/intake_counts ); read -r PASS FAIL < /tmp/intake_counts
}
test_intake_create_fail_no_ack() {
  ( source tests/stubs.sh; make_stubs
    cp tests/fixtures/tg_updates.json "$STUB/updates.json"; touch "$STUB/fail_create"
    export REPO=x/y TG_BOT_TOKEN_1=t TG_CHAT_ID=-1004420681690 TG_THREAD_ID=461
    bash scripts/intake.sh >/dev/null 2>&1
    assert_eq 0 "$(grep -c 'offset=107' "$STUB/log")" intake_fail_no_full_ack
    assert_eq 1 "$(grep -c 'offset=100' "$STUB/log")" intake_fail_ack_before
    echo "$PASS $FAIL" > /tmp/t_counts ); read -r PASS FAIL < /tmp/t_counts
}
