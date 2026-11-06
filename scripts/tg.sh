#!/bin/bash
# Gửi Telegram ngắn: bash tg.sh "1 dòng"; kèm file đọc chi tiết: bash tg.sh --file <file.md> "1 dòng".
# Bot theo tài khoản Claude đang chạy (BOT_NO): TG_BOT_TOKEN_<n> nếu có, không thì TG_BOT_TOKEN chung.
# TG_THREAD_ID = topic trong group forum. Thiếu token/chat → im lặng bỏ qua. Log PUBLIC: không in gì.
source "$(dirname "$0")/lib.sh"; n=${BOT_NO:-0}; v="TG_BOT_TOKEN_$n"; tok=${!v:-${TG_BOT_TOKEN:-}}
[ -n "$tok" ] && [ -n "${TG_CHAT_ID:-}" ] || exit 0
file=""; [ "${1:-}" = "--file" ] && { file=$2; shift 2; }
# --kb <inline_keyboard json>: gửi bằng bot Queenie — chỉ Queenie đọc getUpdates nên nút bấm/trả lời mới về tới intake.
kbarg=(); [ "${1:-}" = "--kb" ] && { kbarg=(--data-urlencode "reply_markup={\"inline_keyboard\":$2}"); shift 2; tok=${TG_BOT_TOKEN_1:-$tok}; }
# HTML: thoát & < > rồi đổi **đậm** → <b>đậm</b>. Icon theo bot.
case "$n" in 1) ic="👩‍✈️" ;; 2) ic="🦾" ;; 3) ic="🕷" ;; *) ic="🤖" ;; esac
body=$(printf '%s' "${1:0:900}" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/\*\*\([^*]*\)\*\*/<b>\1<\/b>/g')
msg="$ic <b>$(bot_name "$n")</b> · $body"
if [ -n "$file" ] && [ -s "$file" ]; then
  curl -s -m 30 -o /dev/null "https://api.telegram.org/bot$tok/sendDocument" -F chat_id="$TG_CHAT_ID" \
    ${TG_THREAD_ID:+-F message_thread_id=$TG_THREAD_ID} -F parse_mode=HTML -F caption="$msg" -F document=@"$file" || true
else
  curl -s -m 15 -o /dev/null "https://api.telegram.org/bot$tok/sendMessage" \
    --data-urlencode chat_id="$TG_CHAT_ID" ${TG_THREAD_ID:+-d message_thread_id=$TG_THREAD_ID} \
    --data-urlencode text="$msg" -d parse_mode=HTML -d disable_web_page_preview=true \
    "${kbarg[@]}" || true
fi
