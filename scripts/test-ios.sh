#!/bin/bash
# Chạy test iOS trên simulator iPhone mới nhất có sẵn trên máy runner.
# Truyền thêm tham số (vd -only-testing:CutCutTests/Foo) để chạy hẹp.
# Máy macOS free ~7GB RAM: build nhẹ (-jobs 3, không index, test tuần tự) + DerivedData CHUNG /tmp/dd với lần build app
# chạy thật (khỏi build 2 lần). Từng làm máy "lost communication" khi build + simulator + Claude cùng lúc.
set -euo pipefail
udid=${SIM_UDID:-$(xcrun simctl list devices available -j \
  | jq -r '[.devices | to_entries[] | select(.key | test("iOS")) | .value[] | select(.name | test("^iPhone"))][-1].udid')}
[ -n "$udid" ] && [ "$udid" != "null" ] || { echo "Không có simulator iPhone"; exit 1; }
xcodebuild test -project ios/CutCut/CutCut.xcodeproj -scheme CutCut -destination "id=$udid" -derivedDataPath /tmp/dd \
  -jobs 3 COMPILER_INDEX_STORE_ENABLE=NO -parallel-testing-enabled NO -quiet "$@"
