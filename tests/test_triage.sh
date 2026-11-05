test_validate_plan() {
  source scripts/lib.sh
  validate_plan tests/fixtures/plan_ok.json; assert_eq 0 $? plan_ok
  validate_plan tests/fixtures/plan_bad_platform.json; assert_eq 1 $? plan_bad_platform
  validate_plan tests/fixtures/plan_no_done.json; assert_eq 1 $? plan_no_done
  assert_eq 3 "$(pick_bot '{"1":0,"2":1,"3":0}')" pick_least
  assert_eq 2 "$(pick_bot '{"1":0,"2":0,"3":0}')" pick_tie_prefers_2
  assert_eq 1 "$(pick_bot '{"1":0,"2":2,"3":1}')" pick_queenie_when_free
  assert_eq ios,android "$(order_children tests/fixtures/plan_ok.json | jq -r .platform | paste -sd, -)" order_deps_first
}
test_triage_idempotent() {
  ( source tests/stubs.sh; make_stubs
    jq '. + [{number:1,title:"Việc: A",body:"làm A\n<!-- tg:1:2 -->",labels:["inbox"],state:"OPEN"}]' "$STUB/issues.json" > "$STUB/t" && mv "$STUB/t" "$STUB/issues.json"
    printf '#!/bin/bash\necho "claude $*" >> "$STUB/log"; cp "%s" "$PLAN"; echo "{\\"type\\":\\"result\\",\\"is_error\\":false,\\"result\\":\\"ok\\"}"\n' "$PWD/tests/fixtures/plan_ok.json" > "$STUB/bin/claude"; chmod +x "$STUB/bin/claude"
    export REPO=x/y TOK_1=a VIBECUT_DIR="$STUB"
    bash scripts/triage.sh 1 >/dev/null; bash scripts/triage.sh 1 >/dev/null
    assert_eq 2 "$(grep -c '^gh issue create' "$STUB/log")" triage_children_once
    assert_eq "ios,model:opus,bot:ironman,ci-run" "$(jq -r '.[] | select(.title=="[ios] Làm A") | .labels | join(",")' "$STUB/issues.json")" triage_labels
    assert_eq 1 "$(jq -r '.[] | select(.title=="[android] Port A") | .body' "$STUB/issues.json" | grep -c '^Chờ: #2$')" triage_depends
    assert_eq 1 "$(jq -r '.[] | select(.title=="[android] Port A") | .body' "$STUB/issues.json" | grep -c 'parent:#1 platform:android')" triage_marker
    assert_eq "planned" "$(jq -r '.[] | select(.number==1) | .labels | join(",")' "$STUB/issues.json")" triage_parent_planned
    echo "$PASS $FAIL" > /tmp/triage_counts ); read -r PASS FAIL < /tmp/triage_counts
}
