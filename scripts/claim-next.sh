#!/bin/bash
# Runner còn giờ thì nhận tiếp issue chờ CÙNG nền tảng (máy đã dựng sẵn). In số issue, rỗng nếu hết việc.
# ponytail: gắn ci-running rồi mới làm, không khoá; 2 runner cùng nhận 1 issue trong cùng giây thì hiếm, chấp nhận.
set -uo pipefail
n=$(gh issue list -R "$REPO" --label ci-run --label "$PLATFORM" --state open -L 50 --json number,labels \
  -q '[.[] | select([.labels[].name] | index("ci-running") | not)] | sort_by(.number) | .[0].number // empty')
[ -n "$n" ] && gh issue edit "$n" -R "$REPO" --add-label ci-running >/dev/null && echo "$n"
