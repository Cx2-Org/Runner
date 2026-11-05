#!/bin/bash
# Hàm dùng chung cho runner — chỉ định nghĩa hàm, source không chạy gì.

# Nhãn bot:* → số bot (1 queenie, 2 ironman, 3 spiderman); rỗng nếu không có. Đầu vào: ",nhãn1,nhãn2,".
bot_no_from_labels() {
  case "$1" in *,bot:queenie,*) echo 1 ;; *,bot:ironman,*) echo 2 ;; *,bot:spiderman,*) echo 3 ;; esac
}
bot_name() { case "$1" in 1) echo "Captain Queenie" ;; 2) echo "Iron Man" ;; 3) echo "Spider Man" ;; *) echo "Runner" ;; esac; }
bot_label() { case "$1" in 1) echo bot:queenie ;; 2) echo bot:ironman ;; 3) echo bot:spiderman ;; esac; }
