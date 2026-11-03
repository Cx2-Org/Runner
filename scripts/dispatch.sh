#!/bin/bash
# Bộ điều phối: lấy issue có ci-run ở repo private, mở job cho tới khi đủ MAX_PARALLEL.
# Log repo này PUBLIC: chỉ in số issue, không in tiêu đề/nội dung.
# GH_TOKEN = token repo runner (mở job); PRIV_TOKEN = PAT repo private.
set -euo pipefail
PLATFORMS='["ios","mac","android","windows"]'
priv() { GH_TOKEN="$PRIV_TOKEN" gh "$@" -R "$PRIVATE_REPO"; }

active=$(gh run list --workflow run-cluster.yml -L 100 --json status,displayTitle \
  -q '[.[] | select(.status != "completed") | .displayTitle]')
issues=$(priv issue list --label ci-run --state open -L 100 --json number,labels)

# Dọn ci-running treo (job chết cứng không kịp gỡ label).
for n in $(jq -r '.[] | select([.labels[].name] | index("ci-running")) | .number' <<<"$issues"); do
  if ! jq -e --arg t "issue-$n" 'index($t)' <<<"$active" >/dev/null; then
    priv issue edit "$n" --remove-label ci-running >/dev/null
    echo "issue #$n: gỡ ci-running treo"
  fi
done

slots=$(( MAX_PARALLEL - $(jq length <<<"$active") ))
[ "$slots" -gt 0 ] || { echo "đang chạy đủ $MAX_PARALLEL job"; exit 0; }

jq -c --argjson P "$PLATFORMS" '.[] | select([.labels[].name] | index("ci-running") | not)
  | {n: .number, p: ([.labels[].name] | map(select(. as $x | $P | index($x))) | .[0])}' <<<"$issues" \
| while read -r row && [ "$slots" -gt 0 ]; do
  n=$(jq -r .n <<<"$row"); p=$(jq -r '.p // empty' <<<"$row")
  if [ -z "$p" ]; then
    priv issue comment "$n" --body "Runner: thiếu label nền tảng (ios/mac/android/windows). Gắn label rồi gắn lại ci-run." >/dev/null
    priv issue edit "$n" --remove-label ci-run >/dev/null; echo "issue #$n: thiếu nền tảng"; continue
  fi
  runs_on=$(jq -r --arg p "$p" '.[$p].runs_on' platforms.json)
  if [ -z "$(jq -r --arg p "$p" '.[$p].test' platforms.json)" ]; then
    priv issue comment "$n" --body "Runner: nền tảng \`$p\` chưa cấu hình lệnh test trong platforms.json." >/dev/null
    priv issue edit "$n" --remove-label ci-run >/dev/null; echo "issue #$n: $p chưa cấu hình"; continue
  fi
  priv issue edit "$n" --add-label ci-running >/dev/null
  gh workflow run run-cluster.yml -f issue="$n" -f platform="$p" -f runs_on="$runs_on"
  echo "issue #$n → $p"; slots=$((slots - 1))
done
