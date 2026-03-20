#!/bin/bash
# status.sh — Lecture rapide du cache pour la barre de statut Claude Code.
# Appelé par statusLine dans settings.json (~toutes les 3 secondes).

CACHE="$HOME/.claude/energy-monitor-cache.json"
STATE_FILE="/tmp/.claude-energy-state"
TODAY=$(date +%Y-%m-%d)

if [[ ! -f "$CACHE" ]]; then
  echo "⚡ —"
  exit 0
fi

if command -v jq &>/dev/null; then
  cache_date=$(jq -r '.date // ""' "$CACHE")
  requests=$(jq -r '.requests // 0' "$CACHE")
  tokens_in=$(jq -r '.tokens_in // 0' "$CACHE")
  tokens_out=$(jq -r '.tokens_out // 0' "$CACHE")
  time_from=$(jq -r '.time_from // ""' "$CACHE")
  time_to=$(jq -r '.time_to // ""' "$CACHE")
else
  cache_date=$(grep -o '"date":"[^"]*"' "$CACHE" | head -1 | cut -d'"' -f4)
  requests=$(grep -o '"requests":[0-9]*' "$CACHE" | head -1 | cut -d: -f2)
  tokens_in=$(grep -o '"tokens_in":[0-9]*' "$CACHE" | head -1 | cut -d: -f2)
  tokens_out=$(grep -o '"tokens_out":[0-9]*' "$CACHE" | head -1 | cut -d: -f2)
  time_from=$(grep -o '"time_from":"[^"]*"' "$CACHE" | head -1 | cut -d'"' -f4)
  time_to=$(grep -o '"time_to":"[^"]*"' "$CACHE" | head -1 | cut -d'"' -f4)
fi

if [[ "$cache_date" != "$TODAY" ]]; then
  echo "⚡ —"
  exit 0
fi

requests=${requests:-0}
tokens_in=${tokens_in:-0}
tokens_out=${tokens_out:-0}
total_tokens=$((tokens_in + tokens_out))

# Delta depuis le dernier prompt (via state file de update-stats.sh)
prev_count=0
if [[ -f "$STATE_FILE" ]]; then
  state_line=$(cat "$STATE_FILE" 2>/dev/null)
  state_date=${state_line%%:*}
  [[ "$state_date" == "$TODAY" ]] && prev_count=${state_line##*:}
fi
delta=$((requests - prev_count))
[[ "$delta" -lt 1 ]] && delta=1

awk -v req="$requests" -v tok="$total_tokens" -v delta="$delta" \
    -v from="$time_from" -v to="$time_to" 'BEGIN {
  car_kwh    = 6.3
  kwh_per_req = 0.0015

  # Ligne 1 — dernier prompt
  p_m = delta * kwh_per_req / car_kwh * 10 * 1000
  if (p_m >= 1000)
    prompt_str = sprintf("%.1f km", p_m / 1000)
  else
    prompt_str = sprintf("%.0f mètres", p_m)
  printf "⚡ Dernier prompt : ~%s en voiture\n", prompt_str

  # Ligne 2 — journée
  tok_k = (tok >= 1000) ? int(tok / 1000) "K" : tok
  day_kwh = req * kwh_per_req
  day_km = day_kwh / car_kwh * 10
  printf "📊 Journée %s–%s : %d req | %s tok | ~%.2f kWh (~%.1f km)\n", \
    from, to, req, tok_k, day_kwh, day_km
}'
