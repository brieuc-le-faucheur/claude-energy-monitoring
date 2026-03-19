#!/bin/bash
# stats.sh — Rapport détaillé de consommation énergétique Claude Code.
# Usage : bash stats.sh [YYYY-MM-DD]

DATE=${1:-$(date +%Y-%m-%d)}
if [[ -n "$1" ]] && ! echo "$1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "Format de date invalide : $1 (attendu : YYYY-MM-DD)" >&2
  exit 1
fi
CLAUDE_DIR="$HOME/.claude/projects"

echo "======================================"
echo " Rapport Claude Code — $DATE"
echo "======================================"
echo ""
echo "  Méthodologie & sources :"
echo "  · Énergie/req (0,0003–0,003 kWh) — sources 2024-2025 :"
echo "    - Epoch AI, fév. 2025 : GPT-4o ≈ 0,3 Wh/req (modèles optimisés)"
echo "      https://epoch.ai/gradient-updates/how-much-energy-does-chatgpt-use"
echo "    - IEA, jan. 2024 : ChatGPT ≈ 3 Wh/req (modèles larges)"
echo "      https://www.iea.org/reports/electricity-2024"
echo "    - OpenAI déclaré : 2,5 Mrd req/jour = 850 MWh → 0,34 Wh/req"
echo "    - Luccioni et al., 2023 (arXiv:2311.16863) — référence historique"
echo "  · Voiture thermique (6,5 L/100km → 6,3 kWh/10km) :"
echo "    ADEME, Bilan Carbone® — consommation moyenne parc FR 2023"
echo "  · Moyenne retenue : 0,0015 kWh/req (milieu de fourchette 2024-2025)"

total_messages=0
total_tokens_in=0
total_tokens_out=0
total_sessions=0
earliest=""
latest=""

while IFS= read -r -d '' file; do
  file_date=$(date -r "$file" +%Y-%m-%d 2>/dev/null)
  [[ "$file_date" != "$DATE" ]] && continue

  session_id=$(basename "$file" .jsonl)
  project=$(basename "$(dirname "$file")")

  msgs=$(grep -c '"role":"user"' "$file" 2>/dev/null || echo 0)
  tokens_in=$(grep -o '"input_tokens":[0-9]*' "$file" | awk -F: '{s+=$2} END {print s+0}')
  tokens_out=$(grep -o '"output_tokens":[0-9]*' "$file" | awk -F: '{s+=$2} END {print s+0}')

  if [[ "$msgs" -gt 0 ]]; then
    mtime=$(date -r "$file" +%s 2>/dev/null)
    [[ -z "$earliest" || "$mtime" -lt "$earliest" ]] && earliest=$mtime
    [[ -z "$latest"   || "$mtime" -gt "$latest"   ]] && latest=$mtime

    echo ""
    echo "  Projet   : $project"
    echo "  Session  : ${session_id:0:8}..."
    printf "  Requêtes : %d" "$msgs"
    [[ "$tokens_in"  -gt 0 ]] && printf "  |  Tokens in : %d" "$tokens_in"
    [[ "$tokens_out" -gt 0 ]] && printf "  |  Tokens out : %d" "$tokens_out"
    echo ""

    total_messages=$((total_messages + msgs))
    total_tokens_in=$((total_tokens_in + tokens_in))
    total_tokens_out=$((total_tokens_out + tokens_out))
    total_sessions=$((total_sessions + 1))
  fi
done < <(find "$CLAUDE_DIR" -name "*.jsonl" -print0 2>/dev/null)

[[ "$total_messages" -eq 0 ]] && echo "" && echo "Aucune session trouvée pour $DATE." && echo "" && exit 0

time_from=$(date -d "@$earliest" +%H:%M 2>/dev/null || date -r "$earliest" +%H:%M)
time_to=$(date -d "@$latest"   +%H:%M 2>/dev/null || date -r "$latest"   +%H:%M)

echo ""
echo "======================================"
echo " TOTAUX  ($time_from – $time_to)"
echo "======================================"
printf "  Sessions    : %d\n" "$total_sessions"
printf "  Requêtes    : %d\n" "$total_messages"
[[ "$total_tokens_in"  -gt 0 ]] && printf "  Tokens in   : %d\n" "$total_tokens_in"
[[ "$total_tokens_out" -gt 0 ]] && printf "  Tokens out  : %d\n" "$total_tokens_out"

awk -v req="$total_messages" -v tok_in="$total_tokens_in" -v tok_out="$total_tokens_out" 'BEGIN {
  car_kwh  = 6.3   # kWh pour 10km en voiture thermique (6,5L/100km)
  min_kwh  = req * 0.0003
  avg_kwh  = req * 0.0015
  max_kwh  = req * 0.003
  min_km   = min_kwh / car_kwh * 10
  avg_km   = avg_kwh / car_kwh * 10
  max_km   = max_kwh / car_kwh * 10

  print ""
  print "======================================"
  print " ESTIMATION ÉNERGÉTIQUE"
  print "======================================"
  print "  Hypothèses (études 2024-2025) :"
  printf "    Optimiste  : 0,0003 kWh/req  →  %.4f kWh  ≈  %.2f km voiture\n", min_kwh, min_km
  printf "    Moyenne    : 0,0015 kWh/req  →  %.4f kWh  ≈  %.2f km voiture\n", avg_kwh, avg_km
  printf "    Pessimiste : 0,003  kWh/req  →  %.4f kWh  ≈  %.2f km voiture\n", max_kwh, max_km
  print ""
  printf "  En retenant la moyenne : ~%.2f km en voiture thermique\n", avg_km
  print "  (soit l'"'"'équivalent des " req " requêtes ci-dessus)"
  print ""
  print "  ⚠ Ne tient pas compte du mix énergétique du datacenter"
}'

echo ""
