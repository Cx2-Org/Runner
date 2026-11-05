#!/bin/bash
# Gửi 1 tin Telegram: bash tg.sh "nội dung". Bot theo tài khoản Claude đang chạy (BOT_NO):
# TG_BOT_TOKEN_<n> nếu có, không thì TG_BOT_TOKEN chung. Thiếu token/chat → im lặng bỏ qua.
# TG_THREAD_ID = topic trong group forum (bỏ trống = General).
# Log PUBLIC: không in gì (curl -s, bỏ output).
source "$(dirname "$0")/lib.sh"; n=${BOT_NO:-0}; v="TG_BOT_TOKEN_$n"; tok=${!v:-${TG_BOT_TOKEN:-}}
[ -n "$tok" ] && [ -n "${TG_CHAT_ID:-}" ] || exit 0
curl -s -m 15 -o /dev/null "https://api.telegram.org/bot$tok/sendMessage" \
  --data-urlencode chat_id="$TG_CHAT_ID" ${TG_THREAD_ID:+-d message_thread_id=$TG_THREAD_ID} --data-urlencode text="[$(bot_name "$n")] ${1:0:3900}" \
  -d disable_web_page_preview=true || true
