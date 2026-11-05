#!/bin/bash
# Nhận việc: tin /giao trong topic Telegram → issue `inbox` ở $REPO (1 tin = 1 issue, chống trùng bằng khoá tg:<chat>:<msg>).
# Bot Queenie (TG_BOT_TOKEN_1) là người duy nhất đọc getUpdates. Log PUBLIC: chỉ in số.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
source scripts/lib.sh
api="https://api.telegram.org/bot${TG_BOT_TOKEN_1}"
upd=$(mktemp)
curl -s -m 30 "$api/getUpdates?allowed_updates=%5B%22message%22%5D" > "$upd" || exit 0
jq -e .ok "$upd" >/dev/null 2>&1 || { echo "getUpdates lỗi"; exit 0; }
# Không đọc được danh sách → dừng, KHÔNG ack (lượt sau đọc lại), kẻo tạo trùng.
known=$(gh issue list -R "$REPO" --state all --label inbox -L 500 --json body -q '.[].body') || exit 0
known="$known"$'\n'$(gh issue list -R "$REPO" --state all --label planned -L 500 --json body -q '.[].body') || exit 0
ack=$(( $(tg_max_update_id "$upd" || echo -1) + 1 ))
n_new=0
while IFS= read -r m; do
  [ -n "$m" ] || continue
  key=$(jq -r .key <<<"$m")
  grep -qF "<!-- $key -->" <<<"$known" && continue
  text=$(jq -r .text <<<"$m"); from=$(jq -r .from <<<"$m"); msg=$(jq -r .msg_id <<<"$m")
  title="Việc: $(jq -r '.text | split("\n")[0][0:80]' <<<"$m")"
  body="$text"$'\n\n'"— giao bởi $from qua Telegram, $(date -u -r "$(jq -r .date <<<"$m")" +%F\ %H:%MZ 2>/dev/null || date -u -d "@$(jq -r .date <<<"$m")" +%F\ %H:%MZ)"$'\n'"<!-- $key -->"
  # Tạo lỗi → chỉ ack các tin TRƯỚC tin này (lượt sau thử lại), báo owner 1 lần.
  url=$(gh issue create -R "$REPO" --label inbox --title "$title" --body "$body") || {
    ack=$(jq -r .update_id <<<"$m"); BOT_NO=1 bash scripts/tg.sh "Không tạo được issue cho /giao (GitHub lỗi), sẽ thử lại."; break; }
  known="$known"$'\n'"<!-- $key -->"; n_new=$((n_new + 1))
  curl -s -m 15 -o /dev/null "$api/sendMessage" --data-urlencode chat_id="$TG_CHAT_ID" ${TG_THREAD_ID:+-d message_thread_id=$TG_THREAD_ID} \
    --data-urlencode text="📥 Đã nhận, đang phân tích → #${url##*/}" \
    --data-urlencode reply_parameters="{\"message_id\":$msg}" -d disable_web_page_preview=true || true
done < <(tg_parse_giao "$upd" "$TG_CHAT_ID" "$TG_THREAD_ID")
# /duyet N… → đề xuất thành việc thật (gỡ de-xuat, gắn ci-run); /bo N… → đóng đề xuất. CHỈ nhận issue đang có nhãn de-xuat.
while IFS= read -r m; do
  [ -n "$m" ] || continue
  cmd=$(jq -r .cmd <<<"$m"); msg=$(jq -r .msg_id <<<"$m"); ok=""; skip=""
  for n in $(jq -r '.nums[]' <<<"$m"); do
    if ! gh issue view "$n" -R "$REPO" --json labels -q '[.labels[].name] | index("de-xuat")' 2>/dev/null | grep -q '[0-9]'; then skip="$skip #$n"; continue; fi
    if [ "$cmd" = duyet ]; then gh issue edit "$n" -R "$REPO" --remove-label de-xuat --add-label ci-run >/dev/null && ok="$ok #$n"
    else gh issue close "$n" -R "$REPO" --reason "not planned" --comment "Owner bỏ đề xuất." >/dev/null && gh issue edit "$n" -R "$REPO" --remove-label de-xuat >/dev/null; ok="$ok #$n"; fi
  done
  txt=$([ "$cmd" = duyet ] && echo "👍 Đã duyệt, bắt tay làm:" || echo "🗑 Đã bỏ:")
  curl -s -m 15 -o /dev/null "$api/sendMessage" --data-urlencode chat_id="$TG_CHAT_ID" ${TG_THREAD_ID:+-d message_thread_id=$TG_THREAD_ID} \
    --data-urlencode text="${ok:+$txt$ok}${skip:+${ok:+ · }không phải đề xuất:$skip}" --data-urlencode reply_parameters="{\"message_id\":$msg}" || true
done < <(tg_parse_cmd "$upd" "$TG_CHAT_ID" "$TG_THREAD_ID")
for msg in $(tg_parse_giao_empty "$upd" "$TG_CHAT_ID" "$TG_THREAD_ID"); do
  curl -s -m 15 -o /dev/null "$api/sendMessage" --data-urlencode chat_id="$TG_CHAT_ID" ${TG_THREAD_ID:+-d message_thread_id=$TG_THREAD_ID} \
    --data-urlencode text="✍️ Ghi kèm việc nha: /giao <việc cần làm>" \
    --data-urlencode reply_parameters="{\"message_id\":$msg}" || true
done
[ "$ack" -gt 0 ] && curl -s -m 15 -o /dev/null "$api/getUpdates?offset=$ack&timeout=0" || true
rm -f "$upd"
echo "intake: $n_new việc mới"
