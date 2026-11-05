#!/bin/bash
# Gom dữ liệu → scripts/status.js (lọc chỉ còn số/mã/trạng thái) → ép lên nhánh `status` (1 commit duy nhất, không phình lịch sử).
# Env: GH_TOKEN (repo runner, contents: write), PRIV_TOKEN, PRIVATE_REPO, GITHUB_REPOSITORY. Log PUBLIC: chỉ in "đã đăng".
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
pg() { GH_TOKEN="$PRIV_TOKEN" gh api "$@"; }
runs=$(jq -s '[.[].workflow_runs[]]' <(gh api "repos/$GITHUB_REPOSITORY/actions/runs?status=in_progress&per_page=50") \
  <(gh api "repos/$GITHUB_REPOSITORY/actions/runs?status=queued&per_page=50")) || exit 0
open=$(pg "repos/$PRIVATE_REPO/issues?labels=ci-run&state=open&per_page=100" | jq '[.[] | select(.pull_request | not)]') || exit 0
last_of() { # comment cuối khớp mẫu của issue $1 (số comment $2)
  local page=$(( ($2 + 99) / 100 )); [ "$page" -lt 1 ] && page=1
  pg "repos/$PRIVATE_REPO/issues/$1/comments?per_page=100&page=$page" | jq -r --arg re "$3" '[.[] | select(.body | test($re))] | last | .body // ""'
}
lc='{}'
while IFS=$'\t' read -r n c; do [ -n "$n" ] || continue
  lc=$(jq --arg n "$n" --arg b "$(last_of "$n" "$c" '^(▶|✎|✔|BỎ QUA|CẦN-MODEL-MẠNH|Runner:)')" '. + {($n): $b}' <<<"$lc")
done < <(jq -r '.[] | select([.labels[].name] | index("ci-running")) | "\(.number)\t\(.comments)"' <<<"$open")
since=$(date -u -d '-48 hours' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-48H +%Y-%m-%dT%H:%M:%SZ)
closed=$(pg "repos/$PRIVATE_REPO/issues?labels=ci-run&state=closed&since=$since&per_page=15&sort=updated" | jq '[.[] | select(.pull_request | not)]') || closed='[]'
rep='{}'
while IFS=$'\t' read -r n c; do [ -n "$n" ] || continue
  rep=$(jq --arg n "$n" --arg b "$(last_of "$n" "$c" '^[*][*]Runner[*][*]')" '. + {($n): $b}' <<<"$rep")
done < <(jq -r '.[] | "\(.number)\t\(.comments)"' <<<"$closed")
runs=${runs:-[]}; open=${open:-[]}; closed=${closed:-[]}
# Ghi ra file rồi --slurpfile: Linux giới hạn 128KB MỖI tham số → --argjson với 80 issue sẽ hỏng âm thầm.
w=$(mktemp -d); for v in runs open lc closed rep; do printf '%s' "${!v}" > "$w/$v.json"; done
out=$(jq -n --slurpfile runs "$w/runs.json" --slurpfile open "$w/open.json" --slurpfile lc "$w/lc.json" \
  --slurpfile closed "$w/closed.json" --slurpfile rep "$w/rep.json" \
  '{runs:$runs[0], open:$open[0], lastComment:$lc[0], closed:$closed[0], closedReport:$rep[0]}' | node scripts/status.js) || out=""
rm -rf "$w"
[ -n "$out" ] || { echo "không dựng được trạng thái"; exit 0; }
[ -n "${DRY:-}" ] && { printf '%s' "$out"; exit 0; }
d=$(mktemp -d); printf '%s' "$out" > "$d/status.json"
( cd "$d" && git init -q -b status && git add status.json && git -c user.name=runner -c user.email=runner@users.noreply.github.com \
  commit -qm status && git push -qf "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" status ) && echo "đã đăng trạng thái"
rm -rf "$d"
