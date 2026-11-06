#!/bin/bash
# 8h sáng: Captain Queenie báo tiến độ (xong 24h / đang chạy / còn / kẹt) + đề xuất 3–5 việc mới (nhãn de-xuat, CHƯA chạy).
# Owner duyệt trong topic: /duyet <số…> hoặc /bo <số…>. Env: REPO, GH_TOKEN, TOK_1..3, VIBECUT_DIR, TG_*. Log PUBLIC: chỉ in số.
set -uo pipefail
R=$(cd "$(dirname "$0")/.." && pwd); source "$R/scripts/lib.sh"
export ISSUE=0 PLAN=/tmp/ideas.json
tg() { BOT_NO=1 bash "$R/scripts/tg.sh" "$@"; }
since=$(date -u -d '-24 hours' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)
gl() { gh issue list -R "$REPO" -L 300 --json number,title,labels,body,closedAt "$@"; }
done_j=$(gl --state closed --label ci-run --search "closed:>=$since" ) || done_j='[]'
open_j=$(gl --state open --label ci-run) || open_j='[]'
human_j=$(gl --state open --label need-human) || human_j='[]'
idea_j=$(gl --state open --label de-xuat) || idea_j='[]'
n_done=$(jq length <<<"$done_j"); n_run=$(jq '[.[] | select([.labels[].name] | index("ci-running"))] | length' <<<"$open_j")
n_left=$(jq length <<<"$open_j"); n_human=$(jq length <<<"$human_j")
score() { gh issue view "$1" -R "$REPO" --json comments -q '[.comments[].body | select(startswith("**Runner**"))] | last // ""' | grep -m1 -oE 'ĐIỂM: [0-9.]+/10 \| TỰ TIN: [0-9]+%' || true; }

# Đề xuất việc mới (phiên Claude, xoay token 1→2→3 khi hết hạn mức). Lỗi thì vẫn gửi báo cáo, chỉ thiếu đề xuất.
new_ideas=""; note=""
toks=(); for t in "${TOK_1:-}" "${TOK_2:-}" "${TOK_3:-}"; do [ -n "$t" ] && toks+=("$t"); done
prompt=$(sed "s|\$REPO|$REPO|g; s|\$PLAN|$PLAN|g" "$R/prompts/ideas.md"); rm -f "$PLAN"
for t in ${toks[@]+"${toks[@]}"}; do
  out=$(cd "${VIBECUT_DIR:-$R/../vibecut}" && CLAUDE_CODE_OAUTH_TOKEN="$t" claude -p "$prompt" --model opus --add-dir /tmp \
    --allowedTools "Read,Write,Glob,Grep,Bash(gh issue list:*),Bash(gh issue view:*),Bash(git log:*),Bash(git fetch:*),Bash(git show:*),Bash(ls:*)" \
    --output-format json 2>/dev/null)
  jq -e '.is_error == false' <<<"$out" >/dev/null 2>&1 && break
  grep -qiE 'usage limit|limit reached|rate.?limit|overloaded' <<<"$out" || break
done
if validate_plan "$PLAN"; then
  note=$(jq -r '.note // ""' "$PLAN")
  counts=$(gh issue list -R "$REPO" --state open --label ci-run -L 300 --json labels -q '[.[].labels[].name]' \
    | jq -c '{"1": map(select(.=="bot:queenie"))|length, "2": map(select(.=="bot:ironman"))|length, "3": map(select(.=="bot:spiderman"))|length}')
  while IFS= read -r c; do
    b=$(pick_bot "$counts"); counts=$(jq -c --arg b "$b" '.[$b] += 1' <<<"$counts")
    url=$(gh issue create -R "$REPO" --title "$(jq -r .title <<<"$c")" --body "$(jq -r .body <<<"$c")" \
      --label "$(jq -r .platform <<<"$c")" --label "model:$(jq -r .model <<<"$c")" --label "$(bot_label "$b")" --label de-xuat) || continue
    new_ideas="$new_ideas #${url##*/}"
  done < <(jq -c '.children[]' "$PLAN")
fi

lb7=$(bash "$R/scripts/leaderboard.sh" 168 2>/dev/null) || lb7='null'; [ -n "$lb7" ] || lb7='null'
cost24=$(bash "$R/scripts/leaderboard.sh" 24 2>/dev/null | jq '.total.cost' 2>/dev/null); cost24=${cost24:-0}
best=$(jq -r '[.bots[] | select(.ptsPerUsd != null)][0] | if . then "\(.bot) — \(.ptsPerUsd) điểm/$" else empty end' <<<"$lb7" 2>/dev/null)
case "$best" in "Captain Queenie"*) bi="👩‍✈️" ;; "Iron Man"*) bi="🦾" ;; "Spider Man"*) bi="🕷" ;; *) bi="" ;; esac
tg "☀️ **Báo cáo sáng $(TZ=Asia/Ho_Chi_Minh date +%d/%m)**
✅ Xong $n_done · ⚙️ Chạy $n_run · 📋 Còn $n_left · 🚧 Kẹt $n_human
$(LC_ALL=C printf '💰 24h: $%.2f' "$cost24")${best:+ · 🏆 $bi $best}${new_ideas:+
💡 Đề xuất:$new_ideas
👉 /duyet <số> · /bo <số>}"
echo "báo cáo sáng: xong $n_done, đề xuất $(wc -w <<<"$new_ideas")"
