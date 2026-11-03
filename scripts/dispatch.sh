#!/bin/bash
# Bộ điều phối: lấy issue có ci-run ở repo private, mở job tới khi chạm trần.
# Trần ở platforms.json → "_limits": tổng (total) + từng loại máy (macOS free tối đa 5, tổng free tối đa 20).
# Log repo này PUBLIC: chỉ in số issue, không in tiêu đề/nội dung.
# GH_TOKEN = token repo runner (mở job); PRIV_TOKEN = PAT repo private.
set -euo pipefail
PLATFORMS='["ios","mac","android","windows"]'
priv() { GH_TOKEN="$PRIV_TOKEN" gh "$@" -R "$PRIVATE_REPO"; }
lim() { jq -r --arg k "$1" '._limits[$k] // ._limits.total' platforms.json; }

# Job đang chạy, run-name dạng "issue-<n> <runs_on>".
active=$(gh run list --workflow run-cluster.yml -L 200 --json status,displayTitle \
  -q '[.[] | select(.status != "completed") | .displayTitle]')
issues=$(priv issue list --label ci-run --state open -L 200 --json number,labels)

# Dọn ci-running treo (job chết cứng không kịp gỡ label).
for n in $(jq -r '.[] | select([.labels[].name] | index("ci-running")) | .number' <<<"$issues"); do
  if ! jq -e --arg t "issue-$n" 'any(.[]; . == $t or startswith($t + " "))' <<<"$active" >/dev/null; then
    priv issue edit "$n" --remove-label ci-running >/dev/null
    echo "issue #$n: gỡ ci-running treo"
  fi
done

declare -A used
total=0
while read -r os; do [ -n "$os" ] && used[$os]=$(( ${used[$os]:-0} + 1 )) && total=$((total + 1)); done \
  < <(jq -r '.[] | split(" ")[1] // "?"' <<<"$active")
max_total=$(lim total)
echo "đang chạy $total/$max_total job"

while read -r row; do
  [ "$total" -lt "$max_total" ] || { echo "chạm trần tổng $max_total"; break; }
  n=$(jq -r .n <<<"$row"); p=$(jq -r '.p // empty' <<<"$row")
  if [ -z "$p" ]; then
    priv issue comment "$n" --body "Runner: thiếu label nền tảng (ios/mac/android/windows). Gắn label rồi gắn lại ci-run." >/dev/null
    priv issue edit "$n" --remove-label ci-run >/dev/null; echo "issue #$n: thiếu nền tảng"; continue
  fi
  if [ -z "$(jq -r --arg p "$p" '.[$p].test' platforms.json)" ]; then
    priv issue comment "$n" --body "Runner: nền tảng \`$p\` chưa cấu hình lệnh test trong platforms.json." >/dev/null
    priv issue edit "$n" --remove-label ci-run >/dev/null; echo "issue #$n: $p chưa cấu hình"; continue
  fi
  os=$(jq -r --arg p "$p" '.[$p].runs_on' platforms.json)
  if [ "${used[$os]:-0}" -ge "$(lim "$os")" ]; then echo "issue #$n: $os đủ $(lim "$os") job, chờ"; continue; fi
  priv issue edit "$n" --add-label ci-running >/dev/null
  gh workflow run run-cluster.yml -f issue="$n" -f platform="$p" -f runs_on="$os"
  used[$os]=$(( ${used[$os]:-0} + 1 )); total=$((total + 1))
  echo "issue #$n → $p ($os)"
done < <(jq -c --argjson P "$PLATFORMS" '.[] | select([.labels[].name] | index("ci-running") | not)
  | {n: .number, p: ([.labels[].name] | map(select(. as $x | $P | index($x))) | .[0])}' <<<"$issues")
