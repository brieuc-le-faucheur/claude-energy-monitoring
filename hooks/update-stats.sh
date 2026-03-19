#!/bin/bash
# update-stats.sh — Déclenché par le hook Stop après chaque réponse Claude.
# Scanne les fichiers JSONL du jour et met à jour le cache JSON.

sleep 1

CACHE="$HOME/.claude/energy-monitor-cache.json"
CLAUDE_DIR="$HOME/.claude/projects"
TODAY=$(date +%Y-%m-%d)

total_requests=0
total_tokens_in=0
total_tokens_out=0
earliest=""
latest=""

while IFS= read -r -d '' file; do
  file_date=$(date -r "$file" +%Y-%m-%d 2>/dev/null)
  [[ "$file_date" != "$TODAY" ]] && continue

  msgs=$(grep -c '"role":"user"' "$file" 2>/dev/null || echo 0)
  [[ "$msgs" -eq 0 ]] && continue

  tokens_in=$(grep -o '"input_tokens":[0-9]*' "$file" | awk -F: '{s+=$2} END {print s+0}')
  tokens_out=$(grep -o '"output_tokens":[0-9]*' "$file" | awk -F: '{s+=$2} END {print s+0}')

  mtime=$(date -r "$file" +%s 2>/dev/null)
  [[ -z "$earliest" || "$mtime" -lt "$earliest" ]] && earliest=$mtime
  [[ -z "$latest"   || "$mtime" -gt "$latest"   ]] && latest=$mtime

  total_requests=$((total_requests + msgs))
  total_tokens_in=$((total_tokens_in + tokens_in))
  total_tokens_out=$((total_tokens_out + tokens_out))
done < <(find "$CLAUDE_DIR" -name "*.jsonl" -print0 2>/dev/null)

time_from=""
time_to=""
if [[ -n "$earliest" ]]; then
  time_from=$(date -d "@$earliest" +%H:%M 2>/dev/null || date -r "$earliest" +%H:%M)
  time_to=$(date -d "@$latest"   +%H:%M 2>/dev/null || date -r "$latest"   +%H:%M)
fi

printf '{"date":"%s","requests":%d,"tokens_in":%d,"tokens_out":%d,"time_from":"%s","time_to":"%s","updated":"%s"}\n' \
  "$TODAY" "$total_requests" "$total_tokens_in" "$total_tokens_out" \
  "$time_from" "$time_to" "$(date -Iseconds)" \
  > "$CACHE"
