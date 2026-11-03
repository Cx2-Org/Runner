#!/bin/bash
# Làm trọn 1 issue trên runner đang chạy: nhánh → các vòng Claude → báo cáo (PR, comment, ảnh, label).
# Gọi lặp cho nhiều issue trong cùng 1 job (máy ảo/Xcode/plugin chỉ dựng 1 lần).
# Chạy trong thư mục vibecut. Cần env: ISSUE REPO PLATFORM DEADLINE TEST_CMD ALLOWED GITHUB_RUN_ID.
# Log PUBLIC: chỉ in số issue + đếm task.
set -uo pipefail
export BRANCH=ci/issue-$ISSUE
left() { gh issue view "$ISSUE" -R "$REPO" --json body -q .body | grep -c -- '- \[ \]' || true; }
echo "$ISSUE" > /tmp/current_issue

# Nhánh sạch cho issue này: tiếp nhánh cũ nếu có, không thì từ main.
git reset -q --hard; git clean -fdq
if git fetch -q --depth 1 origin "$BRANCH" 2>/dev/null; then git checkout -qB "$BRANCH" FETCH_HEAD
else git fetch -q --depth 1 origin main && git checkout -qB "$BRANCH" FETCH_HEAD; fi
rm -rf /tmp/shots ../claude-*.json ../claude.err; mkdir -p /tmp/shots
before=$(left)

# Chọn model (công thức ở README): label model:* thắng; bug/perf → opus; documentation/i18n → haiku; còn lại sonnet.
# Vòng nào không tiến triển mà chưa phải opus → nâng lên opus làm tiếp 1 lần nữa thay vì bỏ.
labels=",$(gh issue view "$ISSUE" -R "$REPO" --json labels -q '[.labels[].name] | join(",")'),"
case "$labels" in
  *,model:opus,*) MODEL=opus ;; *,model:sonnet,*) MODEL=sonnet ;; *,model:haiku,*) MODEL=haiku ;;
  *,bug,*|*,perf,*) MODEL=opus ;;
  *,documentation,*|*,i18n,*) MODEL=haiku ;;
  *) MODEL=sonnet ;;
esac

# Vòng Claude: dừng sớm mà còn task + còn giờ → phiên MỚI làm tiếp.
# ponytail: thôi khi 1 vòng không có commit lẫn tick nào (task còn lại đều BỎ QUA / bế tắc hạ tầng).
round=0
while :; do
  round=$((round + 1)); c0=$(git rev-list --count HEAD); l0=$(left)
  # Output chỉ ghi ra file — KHÔNG in console.
  claude -p "$(cat ../runner/prompt.md)" --model "$MODEL" --allowedTools "$ALLOWED" --add-dir /tmp \
    --output-format json > "../claude-$round.json" 2>> ../claude.err
  rc=$?; l1=$(left); echo "issue #$ISSUE vòng $round ($MODEL): exit=$rc còn $l1 task"
  # Hết hạn mức Claude: dừng hẳn, KHÔNG coi là bế tắc (giữ ci-run cho lượt sau).
  # Chỉ xét khi phiên kết thúc LỖI (is_error / không ra JSON), kẻo chữ "429" trong tóm tắt bình thường bị bắt nhầm.
  if ! jq -e '.is_error == false' "../claude-$round.json" >/dev/null 2>&1 \
     && cat "../claude-$round.json" ../claude.err 2>/dev/null | grep -qiE 'usage limit|limit reached|rate.?limit|overloaded'; then QUOTA=1; break; fi
  [ "$l1" = 0 ] && break
  [ $(( DEADLINE - $(date +%s) )) -lt 1200 ] && break
  if [ "$(git rev-list --count HEAD)" = "$c0" ] && [ "$l1" = "$l0" ]; then
    [ "$MODEL" = opus ] && break
    MODEL=opus; echo "issue #$ISSUE: không tiến triển, nâng lên opus"
  fi
done

# Báo cáo.
git push -q origin "HEAD:$BRANCH" 2>/dev/null || true
pr=$(gh pr view "$BRANCH" -R "$REPO" --json url -q .url 2>/dev/null \
  || gh pr create -R "$REPO" --head "$BRANCH" --base main --title "CI: issue #$ISSUE" --body "Closes #$ISSUE" 2>/dev/null || true)
summary=$(for f in ../claude-*.json; do jq -r '.result // empty' "$f" 2>/dev/null; done)
[ -n "$summary" ] || summary="Claude dừng không có tóm tắt (có thể hết hạn mức hoặc hết giờ). $(tail -c 400 ../claude.err 2>/dev/null)"

# Ảnh → nhánh mồ côi ci-shots của repo PRIVATE, nhúng vào comment.
shots=""
if ls /tmp/shots/*.png >/dev/null 2>&1; then
  dir="issue-$ISSUE/$GITHUB_RUN_ID"
  git worktree remove --force ../shots 2>/dev/null; rm -rf ../shots
  if git fetch -q --depth 1 origin ci-shots 2>/dev/null; then git worktree add -q ../shots FETCH_HEAD
  else git worktree add -q --detach ../shots && (cd ../shots && git checkout -q --orphan ci-shots && git rm -rfq .); fi
  mkdir -p "../shots/$dir" && cp /tmp/shots/*.png "../shots/$dir/"
  if (cd ../shots && git add -A && git -c core.hooksPath=/dev/null commit -qm "ảnh issue #$ISSUE" && git push -q origin HEAD:ci-shots); then
    for f in /tmp/shots/*.png; do
      n=$(basename "$f"); cap=$(cat "${f%.png}.md" 2>/dev/null)
      shots="$shots"$'\n\n'"**${cap:-$n}**"$'\n'"![$n](https://github.com/$REPO/blob/ci-shots/$dir/$n?raw=true)"
    done
  fi
fi
gh issue comment "$ISSUE" -R "$REPO" --body "**Runner** (${PLATFORM})${pr:+ — $pr}"$'\n\n'"$summary$shots" >/dev/null

l=$(left)
if [ "${QUOTA:-0}" = 1 ]; then
  gh issue comment "$ISSUE" -R "$REPO" --body "Runner: hết hạn mức Claude, dừng. Giữ \`ci-run\`, lượt sau làm tiếp." >/dev/null
elif [ "$l" = 0 ]; then gh issue close "$ISSUE" -R "$REPO" --comment "Xong hết task.${pr:+ PR: $pr}" >/dev/null
elif [ "$l" = "$before" ]; then
  # Không tick thêm ô nào → gỡ ci-run, kẻo bị nhặt lại đốt hạn mức vô ích.
  gh issue edit "$ISSUE" -R "$REPO" --remove-label ci-run >/dev/null || true
  gh issue comment "$ISSUE" -R "$REPO" --body "Runner: lượt này không xong thêm task nào nên đã gỡ \`ci-run\`. Xử lý chỗ vướng ở trên rồi gắn lại." >/dev/null
fi
gh issue edit "$ISSUE" -R "$REPO" --remove-label ci-running >/dev/null || true
rm -f /tmp/current_issue
echo "issue #$ISSUE: còn $l task"
[ "${QUOTA:-0}" = 1 ] && exit 3 || exit 0
