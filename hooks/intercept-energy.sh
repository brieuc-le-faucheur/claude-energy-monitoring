#!/bin/bash
# intercept-energy.sh — Intercepte /energy et génère le rapport sans passer par Claude.
# Exit 2 = bloque la requête (0 token consommé).

INPUT=$(cat)

# Extraire le prompt depuis le JSON { "prompt": "..." }
if command -v jq &>/dev/null; then
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')
else
  PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | sed 's/"prompt":"//;s/"//')
fi

# Détecte /energy (avec ou sans date en argument)
if echo "$PROMPT" | grep -qE '^[[:space:]]*/energy([[:space:]]|$)'; then
  DATE_ARG=$(echo "$PROMPT" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/stats.sh"
  bash "$SCRIPT" ${DATE_ARG:+"$DATE_ARG"} >&2
  exit 2
fi

exit 0
