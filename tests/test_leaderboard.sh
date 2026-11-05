test_leaderboard() {
  ( source tests/stubs.sh; make_stubs
    cat > "$STUB/bin/gh" <<'G'
#!/bin/bash
q=""; a=("$@"); for ((i=0;i<${#a[@]};i++)); do [ "${a[$i]}" = -q ] && q="${a[$((i+1))]}"; done
{ case "$*" in
  *"/comments"*) case "$*" in *issues/1/*) echo '[{"created_at":"2099","body":"**Runner** (linux)\nĐIỂM: 8/10 | TỰ TIN: 80%\nCHI PHÍ: $2.00 | PHÚT: 30"}]';;
                             *issues/2/*) echo '[{"created_at":"2099","body":"**Runner**\nĐIỂM: 6/10 | TỰ TIN: 50%\nCHI PHÍ: $6.00"},{"created_at":"2099","body":"Runner: trưởng nhóm tách việc. CHI PHÍ: $1.50 | BOT: queenie"}]';;
                             *) echo '[]';; esac;;
  *) echo '[{"number":1,"state":"closed","closed_at":"2099-01-01","labels":[{"name":"ci-run"},{"name":"bot:ironman"}]},{"number":2,"state":"open","closed_at":null,"labels":[{"name":"ci-run"},{"name":"bot:spiderman"}]}]';;
esac; } | if [ -n "$q" ]; then jq -c "$q"; else cat; fi
G
    chmod +x "$STUB/bin/gh"; export REPO=x/y
    local out; out=$(bash scripts/leaderboard.sh 24)
    assert_eq 9.5 "$(jq '.total.cost' <<<"$out")" lb_total
    assert_eq "Iron Man" "$(jq -r '.bots[0].bot' <<<"$out")" lb_best_first
    assert_eq 4 "$(jq '.bots[0].ptsPerUsd' <<<"$out")" lb_pts_per_usd
    assert_eq 1.5 "$(jq '[.bots[] | select(.bot=="Captain Queenie")][0].cost' <<<"$out")" lb_queenie_triage
    echo "$PASS $FAIL" > /tmp/t_counts ); read -r PASS FAIL < /tmp/t_counts
}
