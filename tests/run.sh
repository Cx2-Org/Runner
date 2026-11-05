#!/bin/bash
# Chạy mọi tests/test_*.sh. Mỗi file định nghĩa hàm test_*; assert_eq <mong đợi> <thực tế> <tên>.
cd "$(dirname "$0")/.." || exit 1
PASS=0; FAIL=0
assert_eq() { if [ "$1" == "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL $3: mong '$1' được '$2'"; fi; }
export -f assert_eq 2>/dev/null
for f in tests/test_*.sh; do
  source "$f"
  for t in $(declare -F | awk '{print $3}' | grep '^test_'); do "$t"; unset -f "$t"; done
done
echo "PASS $PASS / FAIL $FAIL"; [ "$FAIL" = 0 ]
