#!/bin/bash
# Trưởng nhóm: issue gốc `inbox` → kế hoạch (phiên Claude 1) → duyệt (phiên 2, ≤2 vòng) → tạo issue con + giao bot.
# Dùng: triage.sh <số issue gốc>. Env: REPO, TOK_1..3, VIBECUT_DIR (checkout vibecut). Log PUBLIC: chỉ in số.
set -uo pipefail
R=$(cd "$(dirname "$0")/.." && pwd); source "$R/scripts/lib.sh"
export ISSUE=$1 PLAN="/tmp/plan-$1.json"
tg() { BOT_NO=1 bash "$R/scripts/tg.sh" "$1"; }

# claude -p với xoay token 1 → 2 → 3 khi hết hạn mức. In 0 nếu chạy được.
toks=(); for t in "${TOK_1:-}" "${TOK_2:-}" "${TOK_3:-}"; do [ -n "$t" ] && toks+=("$t"); done
ask() {
  local prompt; prompt=$(envsubst '$ISSUE $REPO $PLAN' < "$R/prompts/$1.md" 2>/dev/null || sed "s|\$ISSUE|$ISSUE|g; s|\$REPO|$REPO|g; s|\$PLAN|$PLAN|g" "$R/prompts/$1.md")
  for t in "${toks[@]}"; do
    out=$(cd "${VIBECUT_DIR:-$R/../vibecut}" && CLAUDE_CODE_OAUTH_TOKEN="$t" claude -p "$prompt" --model opus \
      --dangerously-skip-permissions --add-dir /tmp --output-format json 2>&1)
    jq -e '.is_error == false' <<<"$(tail -1 <<<"$out")" >/dev/null 2>&1 && return 0
    grep -qiE 'usage limit|limit reached|rate.?limit|overloaded' <<<"$out" || return 1
  done; return 1
}

children() { gh issue list -R "$REPO" --state all -L 200 --json number,body -q ".[] | select(.body | contains(\"parent:#$ISSUE \")) | .number"; }
# Kế hoạch: chạy lại triage mà con đã đủ (có plan cũ) thì bỏ qua phiên Claude.
if [ ! -s "$PLAN" ] || ! validate_plan "$PLAN"; then
  rm -f "$PLAN"; ask triage || { echo "triage #$ISSUE: Claude lỗi"; exit 1; }
  for _ in 1 2; do ask review; validate_plan "$PLAN" && jq -e .ok "$PLAN" >/dev/null && break; done
fi
validate_plan "$PLAN" || { tg "Việc #$ISSUE: kế hoạch không hợp lệ sau 2 vòng duyệt, cần owner xem."; gh issue edit "$ISSUE" -R "$REPO" --add-label need-human >/dev/null; exit 1; }

q=$(jq -r '.question // empty' "$PLAN")
if [ -n "$q" ]; then
  tg "Việc #$ISSUE cần hỏi lại: $q"; gh issue edit "$ISSUE" -R "$REPO" --add-label need-human >/dev/null; exit 0
fi

# Đếm việc đang giữ của từng bot để rải đều.
counts=$(gh issue list -R "$REPO" --state open --label ci-run -L 200 --json labels -q '[.[].labels[].name]' 2>/dev/null \
  | jq -c '{"1": map(select(.=="bot:queenie"))|length, "2": map(select(.=="bot:ironman"))|length, "3": map(select(.=="bot:spiderman"))|length}' 2>/dev/null || echo '{}')
nums=" "; list=""; ann=""
num_of() { sed -n "s/.* $1=\([0-9]*\) .*/\1/p" <<<"$nums"; }
while IFS= read -r c; do
  p=$(jq -r .platform <<<"$c")
  existing=$(gh issue list -R "$REPO" --state all -L 200 --json number,body -q ".[] | select(.body | contains(\"parent:#$ISSUE platform:$p \")) | .number" | head -1)
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
  gh issue create -R "$REPO" --label need-human --title "Cần duyệt: $(jq -r .title <<<"$h")" \
    --body "$(jq -r .body <<<"$h")"$'\n\n'"Từ việc #$ISSUE <!-- parent:#$ISSUE platform:need-human -->" >/dev/null
done

if [ -n "$list" ]; then
  f=$(mktemp); { gh issue view "$ISSUE" -R "$REPO" --json body -q .body; printf '\n\n## Đã tách%s\n' "$list"; } > "$f"
  gh issue edit "$ISSUE" -R "$REPO" --body-file "$f" >/dev/null; rm -f "$f"
  tg "Đã duyệt việc #$ISSUE: tách $(grep -c '^- #' <<<"$list") issue${ann#,}."
fi
gh issue edit "$ISSUE" -R "$REPO" --remove-label inbox --add-label planned >/dev/null
echo "triage #$ISSUE: xong"
