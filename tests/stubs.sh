# Stub gh/curl/claude qua PATH. Trạng thái issue giả ở $STUB/issues.json, log lệnh ở $STUB/log.
make_stubs() {
  export STUB; STUB=$(mktemp -d); echo '[]' > "$STUB/issues.json"; : > "$STUB/log"
  mkdir -p "$STUB/bin"
  cat > "$STUB/bin/gh" <<'G'
#!/bin/bash
echo "gh $*" >> "$STUB/log"
args=("$@")
val() { for ((i=0;i<${#args[@]};i++)); do [ "${args[$i]}" = "$1" ] && { echo "${args[$((i+1))]}"; return; }; done; }
case "$1 $2" in
  "issue list") jq --arg l "$(val --label)" '[.[] | select($l == "" or (.labels | index($l)))] | map({number, body, title, labels: [.labels[] | {name: .}]})' "$STUB/issues.json" | { q=$(val -q); if [ -n "$q" ]; then jq -r "$q"; else cat; fi; } ;;
  "issue create")
    n=$(( $(jq length "$STUB/issues.json") + 1 ))
    labels=$(for ((i=0;i<${#args[@]};i++)); do [ "${args[$i]}" = "--label" ] && echo "${args[$((i+1))]}"; done | tr ',' '\n' | jq -R . | jq -s .)
    body=$(val --body); bf=$(val --body-file); [ -n "$bf" ] && body=$(cat "$bf")
    jq --argjson n $n --arg t "$(val --title)" --arg b "$body" --argjson l "$labels" '. + [{number:$n,title:$t,body:$b,labels:$l,state:"OPEN"}]' "$STUB/issues.json" > "$STUB/t" && mv "$STUB/t" "$STUB/issues.json"
    echo "https://github.com/x/y/issues/$n" ;;
  "issue view") n=$3; jq --argjson n $n '.[] | select(.number==$n) | {number,title,body,state,labels:[.labels[]|{name:.}]}' "$STUB/issues.json" | { q=$(val -q); if [ -n "$q" ]; then jq -r "$q"; else cat; fi; } ;;
  "issue edit") n=$3
    for ((i=0;i<${#args[@]};i++)); do a="${args[$i]}"; v="${args[$((i+1))]}"
      case "$a" in
        --add-label) jq --argjson n $n --arg v "$v" 'map(if .number==$n then .labels = ((.labels + ($v|split(","))) | unique_by(.))  else . end)' "$STUB/issues.json" > "$STUB/t" ;;
        --remove-label) jq --argjson n $n --arg v "$v" 'map(if .number==$n then .labels -= ($v|split(",")) else . end)' "$STUB/issues.json" > "$STUB/t" ;;
        --body) jq --argjson n $n --arg v "$v" 'map(if .number==$n then .body = $v else . end)' "$STUB/issues.json" > "$STUB/t" ;;
        --body-file) jq --argjson n $n --arg v "$(cat "$v")" 'map(if .number==$n then .body = $v else . end)' "$STUB/issues.json" > "$STUB/t" ;;
        *) continue ;;
      esac; mv "$STUB/t" "$STUB/issues.json"; done ;;
  "run list") echo '[]' | { q=$(val -q); if [ -n "$q" ]; then jq -r "$q"; else cat; fi; } ;;
  *) : ;;
esac
G
  cat > "$STUB/bin/curl" <<'C'
#!/bin/bash
echo "curl $*" >> "$STUB/log"
case "$*" in *getUpdates*offset*) echo '{"ok":true,"result":[]}' ;; *getUpdates*) cat "$STUB/updates.json" ;; *) echo '{"ok":true}' ;; esac
C
  chmod +x "$STUB/bin/"*; export PATH="$STUB/bin:$PATH"
}
