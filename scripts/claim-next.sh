#!/bin/bash
# Runner còn giờ thì nhận tiếp issue chờ CÙNG nền tảng (máy đã dựng sẵn). In số issue, rỗng nếu hết việc.
# Bỏ qua issue còn "Chờ: #a" mà #a chưa xong (PR chưa merge).
# ponytail: gắn ci-running rồi mới làm, không khoá; 2 runner cùng nhận 1 issue trong cùng giây thì hiếm, chấp nhận.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
while IFS=$'\t' read -r n body64; do
  [ -n "$n" ] || continue
  [ -z "$(blocked_open "$REPO" "$(base64 -d <<<"$body64" 2>/dev/null || base64 -D <<<"$body64")")" ] || continue
  gh issue edit "$n" -R "$REPO" --add-label ci-running >/dev/null && echo "$n"; exit 0
done < <(gh issue list -R "$REPO" --label ci-run --label "$PLATFORM" --state open -L 50 --json number,labels,body \
  -q '[.[] | select([.labels[].name] | index("ci-running") | not)] | sort_by(.number) | .[] | "\(.number)\t\(.body | @base64)"')
