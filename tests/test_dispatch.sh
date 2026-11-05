test_blocked_by() {
  source scripts/lib.sh
  assert_eq "12 15" "$(blocked_by $'abc\nChờ: #12, #15\n<!-- x -->' | xargs)" blocked_two
  assert_eq "" "$(blocked_by 'không chờ gì')" blocked_none
}
test_queue_alert() {
  source scripts/lib.sh
  local s='{"last":0,"armed":true,"idle_sent":false}' r
  r=$(queue_alert 3 2 "$s" 100000); assert_eq none "$(head -1 <<<"$r")" q_many; s=$(tail -1 <<<"$r")
  assert_eq true "$(jq .armed <<<"$s")" q_armed
  r=$(queue_alert 1 2 "$s" 100000); assert_eq low "$(head -1 <<<"$r")" q_low; s=$(tail -1 <<<"$r")
  r=$(queue_alert 1 2 "$s" 100600); assert_eq none "$(head -1 <<<"$r")" q_no_spam; s=$(tail -1 <<<"$r")
  r=$(queue_alert 0 0 "$s" 100700); assert_eq idle "$(head -1 <<<"$r")" q_idle; s=$(tail -1 <<<"$r")
  r=$(queue_alert 0 0 "$s" 100750); assert_eq none "$(head -1 <<<"$r")" q_idle_once; s=$(tail -1 <<<"$r")
  r=$(queue_alert 4 0 "$s" 100800); r=$(queue_alert 1 1 "$(tail -1 <<<"$r")" 100900)
  assert_eq none "$(head -1 <<<"$r")" q_rearm_waits_3h
  r=$(queue_alert 1 1 "$(tail -1 <<<"$r")" 112000); assert_eq low "$(head -1 <<<"$r")" q_rearm_after_3h
}
test_dispatch_queue_alert() {
  ( source tests/stubs.sh; make_stubs
    export PRIVATE_REPO=x/y PRIV_TOKEN=p TG_BOT_TOKEN_1=t TG_CHAT_ID=1 TG_THREAD_ID=2
    jq '. + [{number:1,title:"a",body:"x",labels:["ci-run","ios","ci-running"],state:"OPEN",updatedAt:"2099-01-01T00:00:00Z"}]' "$STUB/issues.json" > "$STUB/t" && mv "$STUB/t" "$STUB/issues.json"
    bash scripts/dispatch.sh > "$STUB/out" 2>&1; assert_eq 0 $? dispatch_runs
    assert_eq 1 "$(grep -c 'sendMessage' "$STUB/log")" dispatch_alert_once_low
    bash scripts/dispatch.sh > /dev/null 2>&1
    assert_eq 1 "$(grep -c 'sendMessage' "$STUB/log")" dispatch_no_spam
    assert_eq 1 "$(jq '[.[] | select(.labels | index("runner-state"))] | length' "$STUB/issues.json")" dispatch_state_issue
    echo "$PASS $FAIL" > /tmp/disp_counts ); read -r PASS FAIL < /tmp/disp_counts
}
