#!/bin/bash
# Chạy test iOS trên simulator iPhone mới nhất có sẵn trên máy runner.
# Truyền thêm tham số (vd -only-testing:CutCutTests/Foo) để chạy hẹp.
set -euo pipefail
udid=$(xcrun simctl list devices available -j \
  | jq -r '[.devices | to_entries[] | select(.key | test("iOS")) | .value[] | select(.name | test("^iPhone"))][-1].udid')
[ -n "$udid" ] && [ "$udid" != "null" ] || { echo "Không có simulator iPhone"; exit 1; }
xcodebuild test -project ios/CutCut/CutCut.xcodeproj -scheme CutCut \
  -destination "id=$udid" -quiet "$@"
