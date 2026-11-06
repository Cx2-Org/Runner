#!/bin/bash
# Tạo/cập nhật nhãn cho luồng giao việc ở $REPO (chạy 1 lần, chạy lại vô hại).
set -euo pipefail
R=${REPO:-nguyenphp/vibecut}
while IFS='|' read -r n c d; do gh label create "$n" -R "$R" --color "$c" --description "$d" --force >/dev/null; echo "nhãn $n"; done <<'L'
inbox|FBCA04|Việc mới từ Telegram, chờ trưởng nhóm tách
planned|0E8A16|Việc gốc đã tách thành issue con
linux|1D76DB|Nền tảng Linux
bot:queenie|D93F0B|Captain Queenie làm (tài khoản Claude 1)
bot:ironman|B60205|Iron Man làm (tài khoản Claude 2)
bot:spiderman|5319E7|Spider Man làm (tài khoản Claude 3)
runner-state|C5DEF5|Issue ghim lưu trạng thái runner
de-xuat|BFD4F2|Việc Queenie đề xuất, chờ owner /duyet
cuu|FF7B72|Bot kẹt, Queenie đang tìm cách gỡ (nút 🧠 trên Telegram)
L
