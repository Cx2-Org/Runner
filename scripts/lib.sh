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

# Kế hoạch tách việc hợp lệ: nền tảng đã biết, mỗi issue con có "## Task" với ≥1 ô "- [ ]" và "## Xong khi".
validate_plan() {
  jq -e '(.children | type == "array") and all(.children[];
    (.platform | IN("ios","android","mac","windows","linux"))
    and (.body | test("## Task") and test("- \\[ \\]") and test("## Xong khi"))
    and (.model | IN("opus","sonnet","haiku")))' "$1" >/dev/null 2>&1
}
# Bot ít việc nhất theo {"1":n,"2":n,"3":n}; hoà thì ưu tiên 2, 3 rồi 1 (Queenie là trưởng nhóm).
pick_bot() { jq -r '. as $c | ["2","3","1"] | min_by($c[.] // 0)' <<<"$1"; }
# Issue con xếp sao cho nền tảng được chờ (depends_on) tạo trước — để biết số # mà ghi "Chờ: #a".
order_children() {
  jq -c '.children as $c | [$c[] | .platform] as $all
    | def lvl($p; $d): if $d > 5 then 0 else ([$c[] | select(.platform == $p) | .depends_on[]? | select(IN($all[])) | 1 + lvl(.; $d + 1)] | max // 0) end;
    $c | map(. + {lvl: lvl(.platform; 0)}) | sort_by(.lvl) | .[] | del(.lvl)' "$1"
}

# Số issue phải chờ, từ dòng "Chờ: #12, #15" trong body.
blocked_by() { grep -m1 '^Chờ: ' <<<"$1" | grep -o '#[0-9]*' | tr -d '#'; }
# Nhắc hàng chờ: queue_alert <đang chờ> <đang chạy> <state json> <epoch> → dòng 1 low|idle|none, dòng 2 state mới.
# low: chờ ≤ 1, đã từng > 1 (armed), cách lần nhắc trước ≥ 3 giờ. idle: hết sạch, nhắc 1 lần tới khi có việc lại.
queue_alert() {
  jq -r --argjson w "$1" --argjson r "$2" --argjson now "$4" '
    (.last // 0) as $last | (.armed // true) as $armed | (.idle_sent // false) as $idle |
    if $w > 1 then ["none", {last: $last, armed: true, idle_sent: false}]
    elif $w == 0 and $r == 0 then
      if $idle then ["none", .] else ["idle", {last: $now, armed: false, idle_sent: true}] end
    elif $armed and ($now - $last) >= 10800 then ["low", {last: $now, armed: false, idle_sent: false}]
    else ["none", {last: $last, armed: $armed, idle_sent: false}] end
    | .[0], (.[1] | tojson)' <<<"$3"
}
