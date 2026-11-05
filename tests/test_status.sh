test_status_public() {
  local raw='{"runs":[{"name":"run-cluster","display_title":"issue-12 ubuntu-latest","status":"in_progress"}],"open":[{"number":12,"title":"[desktop/linux] D02 Mô hình BÍ MẬT","body":"- [x] a","labels":[{"name":"ci-run"},{"name":"ci-running"},{"name":"bot:ironman"}]}],"lastComment":{"12":"✎ Task 1: nội dung BÍ MẬT"},"closed":[],"closedReport":{}}'
  local out; out=$(node scripts/status.js <<<"$raw")
  assert_eq D02 "$(jq -r '.bots[1].jobs[0].code' <<<"$out")" status_code
  assert_eq 0 "$(grep -c 'BÍ MẬT' <<<"$out")" status_no_private_text
  assert_eq code "$(jq -r '.bots[1].state' <<<"$out")" status_phase
}
