#!/bin/bash
# Gửi ảnh chụp vào Telegram (album ≤10 ảnh/tin): bash tg-album.sh "<chú thích>" a.png b.png …
# Ảnh ở nhánh ci-shots của repo PRIVATE không xem được ngoài trình duyệt đã đăng nhập (app GitHub, Telegram) → gửi thẳng file.
# Cùng token/chat như tg.sh; thiếu thì im lặng bỏ qua. Log PUBLIC: không in gì.
source "$(dirname "$0")/lib.sh"; n=${BOT_NO:-0}; v="TG_BOT_TOKEN_$n"; tok=${!v:-${TG_BOT_TOKEN:-}}
[ -n "$tok" ] && [ -n "${TG_CHAT_ID:-}" ] || exit 0
cap=$1; shift; [ $# -gt 0 ] || exit 0
while [ $# -gt 0 ]; do
  args=(); media="["; i=0
  while [ $# -gt 0 ] && [ $i -lt 10 ]; do
    f=$1; shift; [ -s "$f" ] || continue
    c=$(cat "${f%.*}.md" 2>/dev/null | head -c 200); [ $i = 0 ] && c="$cap${c:+ — $c}"
    media="$media$([ $i -gt 0 ] && echo ,)$(jq -cn --arg m "attach://p$i" --arg c "$c" '{type:"photo",media:$m,caption:$c}')"
    args+=(-F "p$i=@$f"); i=$((i + 1))
  done
  [ $i -gt 0 ] || continue
  curl -s -m 120 -o /dev/null "https://api.telegram.org/bot$tok/sendMediaGroup" -F chat_id="$TG_CHAT_ID" \
    ${TG_THREAD_ID:+-F message_thread_id=$TG_THREAD_ID} -F media="$media]" "${args[@]}" || true
done
