#!/bin/bash
# Đồng bộ issue runner của repo private → bảng GitHub Projects "CutCut Runner", cột theo field "Runner".
# Cần GH_TOKEN có scope project + repo. Idempotent: chạy bao nhiêu lần cũng được.
# Log repo này PUBLIC: chỉ in số issue + cột.
set -euo pipefail
OWNER=nguyenphp; NUM=1; REPO=${PRIVATE_REPO:-nguyenphp/vibecut}

pid=$(gh project view $NUM --owner $OWNER --format json -q .id)
field=$(gh project field-list $NUM --owner $OWNER --format json -q '.fields[] | select(.name=="Runner")')
fid=$(jq -r .id <<<"$field")
opt() { jq -r --arg n "$1" '.options[] | select(.name==$n) | .id' <<<"$field"; }

for st in open closed; do
  gh issue list -R "$REPO" --state $st -L 200 --json number,url,labels,state \
    -q '.[] | select([.labels[].name] | any(. == "ci-run" or . == "ci-running" or . == "need-human" or . == "ios" or . == "mac" or . == "android" or . == "windows"))' | jq -c .
done | jq -s -c 'unique_by(.number)[]' | while read -r it; do
  n=$(jq -r .number <<<"$it"); url=$(jq -r .url <<<"$it"); labels=$(jq -r '[.labels[].name] | join(",")' <<<"$it")
  if [ "$(jq -r .state <<<"$it")" = CLOSED ]; then col="Xong"
  elif [[ ",$labels," == *",ci-running,"* ]]; then col="Đang chạy"
  elif [[ ",$labels," == *",need-human,"* || ",$labels," != *",ci-run,"* ]]; then col="Cần duyệt"  # chờ owner / bị chặn
  else col="Chờ"; fi
  item=$(gh project item-add $NUM --owner $OWNER --url "$url" --format json -q .id)
  gh project item-edit --project-id "$pid" --id "$item" --field-id "$fid" --single-select-option-id "$(opt "$col")" >/dev/null
  echo "issue #$n → $col"
done
