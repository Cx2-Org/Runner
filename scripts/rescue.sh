#!/bin/bash
# Queenie gỡ kẹt: issue nhãn `cuu` (owner bấm 🧠 trên Telegram) → 1 phiên opus đọc issue + nhánh bot → ghi cách gỡ thành
# comment ưu tiên rồi cho vào lại hàng chờ; cần owner quyết thì hỏi 1 câu qua Telegram. Log PUBLIC: chỉ in số.
# Dùng: rescue.sh <số issue>. Env: REPO, TOK_1..3, VIBECUT_DIR.
set -uo pipefail
R=$(cd "$(dirname "$0")/.." && pwd); source "$R/scripts/lib.sh"
ISSUE=$1 OUT=/tmp/rescue-$1.md; rm -f "$OUT"
tg() { BOT_NO=1 bash "$R/scripts/tg.sh" "$@"; }
prompt=$(sed "s|\$ISSUE|$ISSUE|g; s|\$REPO|$REPO|g; s|\$OUT|$OUT|g" "$R/prompts/rescue.md")
# ponytail: xoay token 1 → 2 → 3 khi hết hạn mức, giống triage.sh (chép lại vì 2 chỗ dùng, gom khi có chỗ thứ 3).
ok=""; quota=1
for t in "${TOK_1:-}" "${TOK_2:-}" "${TOK_3:-}"; do
  [ -n "$t" ] || continue
  out=$(cd "${VIBECUT_DIR:-$R/../vibecut}" && CLAUDE_CODE_OAUTH_TOKEN="$t" claude -p "$prompt" --model opus \
    --allowedTools "Read,Write,Glob,Grep,Bash(gh issue view:*),Bash(git fetch:*),Bash(git log:*),Bash(git diff:*),Bash(git show:*),Bash(ls:*),Bash(cat:*),Bash(find:*),Bash(grep:*),Bash(head:*)" \
    --add-dir /tmp --output-format json 2>/dev/null)
  if jq -e '.is_error == false' <<<"$out" >/dev/null 2>&1; then ok=1; break; fi
  grep -qiE 'usage limit|limit reached|rate.?limit|overloaded' <<<"$out" || { quota=0; break; }
done
if [ -z "$ok" ] || [ ! -s "$OUT" ]; then
  [ "$quota" = 1 ] && { echo "rescue #$ISSUE: hết hạn mức, để lượt sau"; exit 0; }   # giữ nhãn cuu → 5 phút sau thử lại
  gh issue edit "$ISSUE" -R "$REPO" --remove-label cuu >/dev/null
  tg "🚧 **Queenie không gỡ được #$ISSUE** (phiên lỗi) — trả lời tin kẹt để gợi ý, hoặc bấm Chạy lại"; exit 1
fi
q=$(head -1 "$OUT" | sed -n 's/^CẦN-OWNER: *//p')
if [ -n "$q" ]; then
  gh issue comment "$ISSUE" -R "$REPO" --body "Queenie hỏi: $q" >/dev/null
  gh issue edit "$ISSUE" -R "$REPO" --remove-label cuu --add-label need-human >/dev/null
  tg --kb '[[{"text":"🔁 Chạy lại","callback_data":"lai:'"$ISSUE"'"},{"text":"🛑 Bỏ","callback_data":"bo:'"$ISSUE"'"}]]' \
    "❓ **#$ISSUE kẹt — cần mày quyết:** $q"$'\n'"✍️ Trả lời tin này là bot làm lại theo câu trả lời"
  echo "rescue #$ISSUE: hỏi owner"; exit 0
fi
gh issue comment "$ISSUE" -R "$REPO" --body "🧠 **CÁCH GỠ KẸT (Queenie) — làm theo trước tiên:**"$'\n\n'"$(cat "$OUT")" >/dev/null
gh issue edit "$ISSUE" -R "$REPO" --remove-label cuu --add-label ci-run >/dev/null
tg "🧠 **Đã có cách gỡ #$ISSUE**, bot làm lại theo hướng mới (chi tiết trong issue)"
echo "rescue #$ISSUE: xong"
