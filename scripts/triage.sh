#!/bin/bash
# Trưởng nhóm: issue gốc `inbox` → kế hoạch (phiên Claude 1) → duyệt (phiên 2, ≤2 vòng) → tạo issue con + giao bot.
# Dùng: triage.sh <số issue gốc>. Env: REPO, TOK_1..3, VIBECUT_DIR (checkout vibecut). Log PUBLIC: chỉ in số.
set -uo pipefail
R=$(cd "$(dirname "$0")/.." && pwd); source "$R/scripts/lib.sh"
export ISSUE=$1 PLAN="/tmp/plan-$1.json"
tg() { BOT_NO=1 bash "$R/scripts/tg.sh" "$@"; }

# claude -p với xoay token 1 → 2 → 3 khi hết hạn mức. Trả 0 xong, 2 hết hạn mức cả 3, 1 lỗi khác.
# Trưởng nhóm chỉ đọc issue + ghi file kế hoạch: quyền HẸP (không cần bỏ chặn như nhân viên).
toks=(); for t in "${TOK_1:-}" "${TOK_2:-}" "${TOK_3:-}"; do [ -n "$t" ] && toks+=("$t"); done
ask() {
  local prompt out err; err=$(mktemp)
  prompt=$(sed "s|\$ISSUE|$ISSUE|g; s|\$REPO|$REPO|g; s|\$PLAN|$PLAN|g" "$R/prompts/$1.md")
  for t in "${toks[@]}"; do
    out=$(cd "${VIBECUT_DIR:-$R/../vibecut}" && CLAUDE_CODE_OAUTH_TOKEN="$t" claude -p "$prompt" --model opus \
      --allowedTools "Read,Write,Edit,Glob,Grep,Bash(gh issue view:*),Bash(gh issue list:*),Bash(git log:*),Bash(ls:*),Bash(cat:*),Bash(find:*),Bash(grep:*),Bash(head:*),Bash(jq:*)" \
      --add-dir /tmp --output-format json 2>"$err")
    TCOST=$(jq -n --argjson a "${TCOST:-0}" --argjson b "$(jq '.total_cost_usd // 0' <<<"$out" 2>/dev/null || echo 0)" '$a + $b')
    if jq -e '.is_error == false' <<<"$out" >/dev/null 2>&1; then rm -f "$err"; return 0; fi
    printf '%s\n' "$out" | cat - "$err" | grep -qiE 'usage limit|limit reached|rate.?limit|overloaded' || { rm -f "$err"; return 1; }
  done; rm -f "$err"; return 2
}
# Lỗi không phải hạn mức → gắn need-human + báo 1 lần, kẻo intake 5 phút/lần chạy lại opus mãi.
fail() { tg "🚧 **Việc #$ISSUE**: $1 — cần mày xem (gỡ need-human là tách lại)"; gh issue edit "$ISSUE" -R "$REPO" --add-label need-human >/dev/null; exit 1; }

rm -f "$PLAN"
ask triage; rc=$?
[ $rc = 2 ] && { echo "triage #$ISSUE: hết hạn mức, để lượt sau"; exit 0; }
[ $rc = 0 ] || fail "trưởng nhóm lỗi khi tách việc"
# Việc mơ hồ → hỏi owner NGAY (không đem đi duyệt). Owner trả lời bằng comment ở issue rồi gỡ need-human là tách lại.
ask_owner() {
  local q; q=$(jq -r '.question // empty' "$PLAN" 2>/dev/null); [ -n "$q" ] || return 1
  tg "❓ **Việc #$ISSUE cần hỏi lại:** $q"$'\n'"👉 Trả lời bằng comment ở issue #$ISSUE rồi gỡ nhãn need-human"
  gh issue comment "$ISSUE" -R "$REPO" --body "Trưởng nhóm hỏi: $q" >/dev/null
  gh issue edit "$ISSUE" -R "$REPO" --add-label need-human >/dev/null; exit 0
}
ask_owner
for _ in 1 2; do validate_plan "$PLAN" && jq -e '.ok == true' "$PLAN" >/dev/null && break; ask review || break; ask_owner; done
validate_plan "$PLAN" && jq -e '.ok == true' "$PLAN" >/dev/null || fail "kế hoạch chưa đạt sau 2 vòng duyệt"

# Đếm việc đang giữ của từng bot để rải đều.
counts=$(gh issue list -R "$REPO" --state open --label ci-run -L 200 --json labels -q '[.[].labels[].name]' 2>/dev/null \
  | jq -c '{"1": map(select(.=="bot:queenie"))|length, "2": map(select(.=="bot:ironman"))|length, "3": map(select(.=="bot:spiderman"))|length}' 2>/dev/null || echo '{}')
nums=" "; list=""; ann=""
num_of() { sed -n "s/.* $1=\([0-9]*\) .*/\1/p" <<<"$nums"; }
while IFS= read -r c; do
  p=$(jq -r .platform <<<"$c")
  existing=$(gh issue list -R "$REPO" --state all -L 500 --json number,body -q ".[] | select(.body | contains(\"parent:#$ISSUE platform:$p \")) | .number") || fail "không đọc được danh sách issue"
  existing=$(head -1 <<<"$existing")
  if [ -n "$existing" ]; then nums="$nums$p=$existing "; continue; fi
  b=$(pick_bot "$counts"); counts=$(jq -c --arg b "$b" '.[$b] = ((.[$b] // 0) + 1)' <<<"$counts")
  m=$(jq -r .model <<<"$c")
  wait=$(jq -r '.depends_on[]?' <<<"$c" | while read -r d; do n=$(num_of "$d"); [ -n "$n" ] && printf '#%s, ' "$n"; done | sed 's/, $//')
  body=$(jq -r .body <<<"$c")${wait:+$'\n\n'"Chờ: $wait"}$'\n\n'"<!-- parent:#$ISSUE platform:$p -->"
  url=$(gh issue create -R "$REPO" --title "$(jq -r .title <<<"$c")" --body "$body" \
    --label "$p" --label "model:$m" --label "$(bot_label "$b")" --label ci-run) || continue
  n=${url##*/}; nums="$nums$p=$n "; list="$list"$'\n'"- #$n $p"
  ann="$ann, #$n $p → $(bot_name "$b") ($m)${wait:+ chờ $wait}"
done < <(order_children "$PLAN")
jq -c '.need_human[]?' "$PLAN" | while IFS= read -r h; do
  gh issue list -R "$REPO" --state all -L 200 --json body -q '.[].body' | grep -qF "parent:#$ISSUE platform:need-human $(jq -r .title <<<"$h" | cksum | cut -d' ' -f1)" && continue
  gh issue create -R "$REPO" --label need-human --title "Cần duyệt: $(jq -r .title <<<"$h")" \
    --body "$(jq -r .body <<<"$h")"$'\n\n'"Từ việc #$ISSUE <!-- parent:#$ISSUE platform:need-human $(jq -r .title <<<"$h" | cksum | cut -d' ' -f1) -->" >/dev/null
done

if [ -n "$list" ]; then
  f=$(mktemp); { gh issue view "$ISSUE" -R "$REPO" --json body -q .body; printf '\n\n## Đã tách%s\n' "$list"; } > "$f"
  gh issue edit "$ISSUE" -R "$REPO" --body-file "$f" >/dev/null; rm -f "$f"
  tg "🧩 **Chia #$ISSUE** thành $(grep -c '^- #' <<<"$list") phần"
fi
gh issue edit "$ISSUE" -R "$REPO" --remove-label inbox --add-label planned >/dev/null
gh issue comment "$ISSUE" -R "$REPO" --body "$(LC_ALL=C printf 'Runner: trưởng nhóm tách việc. CHI PHÍ: $%.2f | MODEL: opus | BOT: queenie' "${TCOST:-0}")" >/dev/null
echo "triage #$ISSUE: xong"
