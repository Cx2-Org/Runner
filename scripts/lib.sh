#!/bin/bash
# Hàm dùng chung cho runner — chỉ định nghĩa hàm, source không chạy gì.

# Nhãn bot:* → số bot (1 queenie, 2 ironman, 3 spiderman); rỗng nếu không có. Đầu vào: ",nhãn1,nhãn2,".
bot_no_from_labels() {
  case "$1" in *,bot:queenie,*) echo 1 ;; *,bot:ironman,*) echo 2 ;; *,bot:spiderman,*) echo 3 ;; esac
}
bot_name() { case "$1" in 1) echo "Captain Queenie" ;; 2) echo "Iron Man" ;; 3) echo "Spider Man" ;; *) echo "Runner" ;; esac; }
bot_label() { case "$1" in 1) echo bot:queenie ;; 2) echo bot:ironman ;; 3) echo bot:spiderman ;; esac; }

# Chạy lệnh, stdout → outfile; outfile không lớn thêm trong <idle> giây thì giết cả nhóm tiến trình, trả 124.
# Dùng: run_with_idle_kill <idle_giây> <outfile> -- <lệnh...>. perl setpgrp vì macOS không có setsid.
run_with_idle_kill() {
  local idle=$1 out=$2; shift 3
  : > "$out"
  perl -e 'setpgrp(0,0); exec @ARGV or die' "$@" >> "$out" &
  local pid=$! last=0 size step=$(( idle / 3 )); [ "$step" -gt 60 ] && step=60; [ "$step" -lt 1 ] && step=1
  local quiet=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$step"
    size=$(wc -c < "$out" | tr -d ' ')
    if [ "$size" != "$last" ]; then last=$size; quiet=0; else quiet=$(( quiet + step )); fi
    if [ "$quiet" -ge "$idle" ]; then
      kill -TERM -- "-$pid" 2>/dev/null; sleep 2; kill -KILL -- "-$pid" 2>/dev/null
      wait "$pid" 2>/dev/null; return 124
    fi
  done
  wait "$pid"
}

# Tin /giao hợp lệ (đúng chat + topic, có nội dung) từ JSON getUpdates → mỗi tin 1 dòng JSON.
tg_parse_giao() {
  jq -c --arg c "$2" --arg t "$3" '.result[] | .update_id as $u | .message // empty
    | select((.chat.id|tostring) == $c and ((.message_thread_id // "")|tostring) == $t)
    | select((.text // "") | test("^/giao(@[A-Za-z0-9_]+)?(\\s|$)"))
    | {key: "tg:\(.chat.id):\(.message_id)", msg_id: .message_id, update_id: $u, date: .date,
       from: ([.from.first_name, .from.last_name] | map(select(.)) | join(" ")),
       text: (.text | sub("^/giao(@[A-Za-z0-9_]+)?\\s*"; "") | sub("\\s+$"; ""))}
    | select(.text != "")' "$1"
}
tg_max_update_id() { jq -r '[.result[].update_id] | max // empty' "$1"; }
