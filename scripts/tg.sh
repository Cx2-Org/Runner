#!/bin/bash
# Gửi 1 tin Telegram: bash tg.sh "nội dung". Bot theo tài khoản Claude đang chạy (BOT_NO):
# TG_BOT_TOKEN_<n> nếu có, không thì TG_BOT_TOKEN chung. Thiếu token/chat → im lặng bỏ qua.
# Log PUBLIC: không in gì (curl -s, bỏ output).
n=${BOT_NO:-0}; v="TG_BOT_TOKEN_$n"; tok=${!v:-${TG_BOT_TOKEN:-}}
[ -n "$tok" ] && [ -n "${TG_CHAT_ID:-}" ] || exit 0
curl -s -m 15 -o /dev/null "https://api.telegram.org/bot$tok/sendMessage" \
  --data-urlencode chat_id="$TG_CHAT_ID" --data-urlencode text="[Bot $n] ${1:0:3900}" \
  -d disable_web_page_preview=true || true
