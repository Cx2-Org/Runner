#!/bin/bash
# Mỗi 3 giờ: chị Queenie tóm tắt 2 dòng (việc xong 3h qua, đang chạy, còn, kẹt, chi phí). 3h qua không xong gì và
# không chạy gì thì im. Env: REPO, GH_TOKEN, TG_*. Log PUBLIC: chỉ in số.
set -uo pipefail
R=$(cd "$(dirname "$0")/.." && pwd)
H=${DIGEST_HOURS:-3}
since=$(date -u -d "-$H hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"$H"H +%Y-%m-%dT%H:%M:%SZ)
done_j=$(gh issue list -R "$REPO" -L 200 --state closed --label ci-run --search "closed:>=$since" --json number) || done_j='[]'
open_j=$(gh issue list -R "$REPO" -L 300 --state open --label ci-run --json labels) || open_j='[]'
n_done=$(jq length <<<"$done_j"); n_left=$(jq length <<<"$open_j")
n_run=$(jq '[.[] | select([.labels[].name] | index("ci-running"))] | length' <<<"$open_j")
n_human=$(gh issue list -R "$REPO" --state open --label need-human --json number -q length 2>/dev/null || echo 0)
echo "digest: xong $n_done, chạy $n_run, còn $n_left, kẹt $n_human"
[ "$n_done" = 0 ] && [ "$n_run" = 0 ] && { echo "im lặng: không có gì mới"; exit 0; }
cost=$(bash "$R/scripts/leaderboard.sh" "$H" 2>/dev/null | jq '.total.cost // 0' 2>/dev/null); cost=${cost:-0}
nums=$(jq -r '[.[].number] | sort | .[:12] | map("#\(.)") | join(", ")' <<<"$done_j"); [ "$n_done" -gt 12 ] && nums="$nums…"
from=$(TZ=Asia/Ho_Chi_Minh date -d "-$H hours" +%Hh 2>/dev/null || TZ=Asia/Ho_Chi_Minh date -v-"$H"H +%Hh); to=$(TZ=Asia/Ho_Chi_Minh date +%Hh)
BOT_NO=1 ${DRY:+echo} bash "$R/scripts/tg.sh" "🕒 **${from}–${to}** · ✅ Xong **$n_done**${nums:+: $nums}
⚙️ Chạy $n_run · 📋 Còn $n_left · 🚧 Kẹt $n_human · $(LC_ALL=C printf '💰 $%.2f' "$cost")"
