#!/bin/bash
# Bộ điều phối: lấy issue có ci-run ở repo private, mở job tới khi chạm trần.
# Trần ở platforms.json → "_limits": tổng (total) + từng loại máy (macOS free tối đa 5, tổng free tối đa 20).
# Log repo này PUBLIC: chỉ in số issue, không in tiêu đề/nội dung.
# GH_TOKEN = token repo runner (mở job); PRIV_TOKEN = PAT repo private.
set -euo pipefail
PLATFORMS='["ios","mac","android","windows","linux"]'
priv() { GH_TOKEN="$PRIV_TOKEN" gh "$@" -R "$PRIVATE_REPO"; }
lim() { jq -r --arg k "$1" '._limits[$k] // ._limits.total' platforms.json; }

# Job đang chạy, run-name dạng "issue-<n> <runs_on>".
active=$(gh run list --workflow run-cluster.yml -L 200 --json status,displayTitle \
  -q '[.[] | select(.status != "completed") | .displayTitle]')
issues=$(priv issue list --label ci-run --state open -L 200 --json number,labels,updatedAt,body)
source scripts/lib.sh
tg() { BOT_NO=1 bash scripts/tg.sh "$1"; }

# Dọn ci-running treo (job chết cứng không kịp gỡ label). Runner nhận tiếp issue khác nên run-name không khớp
# số issue → chỉ coi là treo khi KHÔNG khớp run nào VÀ issue im quá 6.5 giờ (job dài nhất 6 giờ).
stale=$(date -u -d '-390 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-390M +%Y-%m-%dT%H:%M:%SZ)
for n in $(jq -r --arg s "$stale" '.[] | select(([.labels[].name] | index("ci-running")) and .updatedAt < $s) | .number' <<<"$issues"); do
  if ! jq -e --arg t "issue-$n" 'any(.[]; . == $t or startswith($t + " "))' <<<"$active" >/dev/null; then
    priv issue edit "$n" --remove-label ci-running >/dev/null
    echo "issue #$n: gỡ ci-running treo"
  fi
done

# Số job đang chạy theo loại máy, dạng " macos-26=2 ubuntu-latest=1 " (bash 3 không có mảng kết hợp).
used=" "
uget() { local v; v=$(sed -n "s/.* $1=\([0-9]*\) .*/\1/p" <<<"$used"); echo "${v:-0}"; }
uinc() { local v; v=$(( $(uget "$1") + 1 )); used=$(sed "s/ $1=[0-9]* / /" <<<"$used")"$1=$v "; }
total=0
while read -r os; do [ -n "$os" ] && uinc "$os" && total=$((total + 1)); done \
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
  # Issue con chờ issue khác (dòng "Chờ: #a") → để sau khi #a đóng.
  wait=$(GH_TOKEN="$PRIV_TOKEN" blocked_open "$PRIVATE_REPO" "$(jq -r --argjson n "$n" '.[] | select(.number == $n) | .body' <<<"$issues")" | sed 's/^/#/' | xargs)
  if [ -n "$wait" ]; then echo "issue #$n: chờ $wait"; continue; fi
  os=$(jq -r --arg p "$p" '.[$p].runs_on' platforms.json)
  if [ "$(uget "$os")" -ge "$(lim "$os")" ]; then echo "issue #$n: $os đủ $(lim "$os") job, chờ"; continue; fi
  priv issue edit "$n" --add-label ci-running >/dev/null
  gh workflow run run-cluster.yml -f issue="$n" -f platform="$p" -f runs_on="$os"
  uinc "$os"; total=$((total + 1))
  echo "issue #$n → $p ($os)"
done < <(jq -c --argjson P "$PLATFORMS" '.[] | select([.labels[].name] | index("ci-running") | not)
  | {n: .number, p: ([.labels[].name] | map(select(. as $x | $P | index($x))) | .[0])}' <<<"$issues")

# Watchdog ngoài: job "issue-N" đang chạy mà issue + nhánh ci/issue-N im > 180 phút → huỷ run (bước release của job
# tự nhả nhãn), lượt sau chạy lại. Quá 3 lần → need-human. Issue do job khác nhận tiếp (run-name không khớp) thì để
# watchdog trong job (45 phút) + dọn treo 6.5 giờ lo. ponytail: không lưu run id theo issue.
quiet=$(date -u -d '-180 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-180M +%Y-%m-%dT%H:%M:%SZ)
for n in $(jq -r --arg q "$quiet" '.[] | select(([.labels[].name] | index("ci-running")) and .updatedAt < $q) | .number' <<<"$issues"); do
  run=$(gh run list --workflow run-cluster.yml -L 100 --json databaseId,status,displayTitle \
    -q "[.[] | select(.status == \"in_progress\" and (.displayTitle | startswith(\"issue-$n \")))][0].databaseId // empty" || true)
  [ -n "$run" ] || continue
  last=$(GH_TOKEN="$PRIV_TOKEN" gh api "repos/$PRIVATE_REPO/commits?sha=ci/issue-$n&per_page=1" -q '.[0].commit.committer.date' 2>/dev/null || true)
  [ -n "$last" ] && [[ "$last" > "$quiet" ]] && continue
  k=$(( $(priv issue view "$n" --json comments -q '[.comments[].body | select(startswith("Runner: khởi động lại"))] | length') + 1 ))
  gh run cancel "$run" >/dev/null || continue
  if [ "$k" -gt 3 ]; then
    priv issue edit "$n" --remove-label ci-run --add-label need-human >/dev/null
    priv issue comment "$n" --body "Runner: khởi động lại quá 3 lần, chờ owner xem." >/dev/null
    tg "#$n đứng hình quá 3 lần, cần mày xem."; echo "issue #$n: need-human"
  else
    priv issue comment "$n" --body "Runner: khởi động lại (lần $k/3) — job im hơn 180 phút." >/dev/null
    tg "#$n đứng hình hơn 180 phút, khởi động lại (lần $k/3)."; echo "issue #$n: huỷ run kẹt, lần $k"
  fi
done

# Nhắc hàng chờ sắp cạn. Trạng thái nằm trong issue ghim nhãn runner-state ở repo private.
waiting=$(priv issue list --label ci-run --state open -L 200 --json labels -q '[.[] | select([.labels[].name] | index("ci-running") | not)] | length')
running=$(priv issue list --label ci-running --state open -L 200 --json number -q length)
sn=$(priv issue list --label runner-state --state open -L 1 --json number -q '.[0].number // empty')
[ -n "$sn" ] || sn=$(priv issue create --label runner-state --title "Runner trạng thái (đừng đóng)" --body '{}' | sed 's|.*/||')
state=$(priv issue view "$sn" --json body -q .body | jq -c . 2>/dev/null || echo '{}')
r=$(queue_alert "$waiting" "$running" "$state" "$(date +%s)")
case "$(head -1 <<<"$r")" in
  low) tg "Sắp hết việc: còn $running đang làm, $waiting chờ. Giao thêm bằng /giao <việc>." ;;
  idle) tg "Đội rảnh, chưa có việc. Giao bằng /giao <việc>." ;;
esac
new=$(tail -1 <<<"$r"); [ "$new" = "$state" ] || priv issue edit "$sn" --body "$new" >/dev/null
echo "hàng chờ: $waiting chờ, $running chạy"
