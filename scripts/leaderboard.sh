#!/bin/bash
# Bảng hiệu quả theo bot trong <giờ> gần nhất → JSON {total:{cost,done,sessions}, bots:[{bot,cost,sessions,done,avg,perDone,ptsPerUsd}]}.
# Nguồn: comment "**Runner**" (chi phí + điểm mỗi lượt làm) và "Runner: trưởng nhóm" (tách việc, tính cho Queenie).
# Dùng: REPO=… GH_TOKEN=… bash leaderboard.sh 168
set -uo pipefail
H=${1:-168}
since=$(date -u -d "-$H hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"$H"H +%Y-%m-%dT%H:%M:%SZ)
issues=$(gh api "repos/$REPO/issues?state=all&since=$since&per_page=100" --paginate \
  -q '[.[] | select(.pull_request | not) | {number, state, closed_at, labels: [.labels[].name]}]' | jq -s 'add // []') || issues='[]'
rows='[]'
while IFS=$'\t' read -r n bot; do
  [ -n "$n" ] || continue
  c=$(gh api "repos/$REPO/issues/$n/comments?since=$since&per_page=100" --paginate \
    -q '[.[] | select(.body | test("CHI PHÍ: \\$")) | {at: .created_at, body}]' 2>/dev/null | jq -s 'add // []') || continue
  rows=$(jq --argjson c "$c" --arg n "$n" --arg bot "$bot" '. + [$c[] | {issue: ($n|tonumber),
    bot: (if (.body | test("BOT: queenie")) then "Captain Queenie" else $bot end),
    cost: (.body | capture("CHI PHÍ: \\$(?<v>[0-9.]+)").v | tonumber),
    score: ((.body | capture("ĐIỂM: (?<s>[0-9.]+)/10") | .s | tonumber)? // null)}]' <<<"$rows")
done < <(jq -r '.[] | "\(.number)\t\(if (.labels|index("bot:queenie")) then "Captain Queenie" elif (.labels|index("bot:ironman")) then "Iron Man" elif (.labels|index("bot:spiderman")) then "Spider Man" else "Captain Queenie" end)"' <<<"$issues")
jq -n --argjson rows "$rows" --argjson issues "$issues" --arg since "$since" '
  [$issues[] | select(.state == "closed" and .closed_at >= $since and (.labels | index("ci-run")))] as $closed |
  def botof(l): if (l|index("bot:ironman")) then "Iron Man" elif (l|index("bot:spiderman")) then "Spider Man" else "Captain Queenie" end;
  ["Captain Queenie","Iron Man","Spider Man"] | map(. as $b |
    ([$rows[] | select(.bot == $b)]) as $r | ([$closed[] | select(botof(.labels) == $b)] | length) as $done |
    ([$r[] | .score | select(. != null)]) as $sc | ($r | map(.cost) | add // 0) as $cost |
    {bot: $b, cost: ($cost*100|round/100), sessions: ($r|length), done: $done,
     avg: (if ($sc|length) > 0 then (($sc|add)/($sc|length)*10|round/10) else null end),
     perDone: (if $done > 0 then ($cost/$done*100|round/100) else null end),
     ptsPerUsd: (if $cost > 0 and ($sc|length) > 0 then (($sc|add)/$cost*10|round/10) else null end)}) as $bots |
  {hours: ($since), total: {cost: ([$bots[].cost]|add*100|round/100), done: ([$bots[].done]|add), sessions: ([$bots[].sessions]|add)},
   bots: ($bots | sort_by(-(.ptsPerUsd // -1)))}'
