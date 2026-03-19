#!/bin/bash
# summary.sh — Résumé énergétique compact affiché après chaque réponse Claude.
# Lit depuis le cache (mis à jour par update-stats.sh juste avant).

CACHE="$HOME/.claude/energy-monitor-cache.json"
STATE_FILE="/tmp/.claude-energy-state"
TODAY=$(date +%Y-%m-%d)

[[ ! -f "$CACHE" ]] && exit 0

if command -v jq &>/dev/null; then
  cache_date=$(jq -r '.date // ""' "$CACHE")
  total_messages=$(jq -r '.requests // 0' "$CACHE")
  time_from=$(jq -r '.time_from // ""' "$CACHE")
  time_to=$(jq -r '.time_to // ""' "$CACHE")
else
  cache_date=$(grep -o '"date":"[^"]*"' "$CACHE" | head -1 | cut -d'"' -f4)
  total_messages=$(grep -o '"requests":[0-9]*' "$CACHE" | head -1 | cut -d: -f2)
  time_from=$(grep -o '"time_from":"[^"]*"' "$CACHE" | head -1 | cut -d'"' -f4)
  time_to=$(grep -o '"time_to":"[^"]*"' "$CACHE" | head -1 | cut -d'"' -f4)
fi

total_messages=${total_messages:-0}
[[ "$cache_date" != "$TODAY" || "$total_messages" -eq 0 ]] && exit 0

# Delta depuis la dernière réponse (réinitialisé au changement de jour)
prev_count=0
if [[ -f "$STATE_FILE" ]]; then
  state_line=$(cat "$STATE_FILE" 2>/dev/null)
  state_date=${state_line%%:*}
  [[ "$state_date" == "$TODAY" ]] && prev_count=${state_line##*:}
fi
delta=$((total_messages - prev_count))
[[ "$delta" -lt 1 ]] && delta=1
echo "$TODAY:$total_messages" > "$STATE_FILE"

awk -v req="$total_messages" -v delta="$delta" -v from="$time_from" -v to="$time_to" 'BEGIN {
  car_kwh = 6.3
  kwh_per_req = 0.0015
  p_m = delta * kwh_per_req / car_kwh * 10 * 1000
  if (p_m >= 1000)
    prompt_str = sprintf("%.1f km", p_m / 1000)
  else
    prompt_str = sprintf("%.0f mètres", p_m)
  day_kwh = req * kwh_per_req
  day_km = day_kwh / car_kwh * 10
  printf "⚡ Ce prompt ≈ %s en voiture  |  Journée %s–%s : %d req | ~%.2f kWh (~%.1f km)\n", prompt_str, from, to, req, day_kwh, day_km
}'
