#!/bin/bash
# install.sh — Installe le plugin energy-monitoring dans Claude Code.
#
# Prérequis : Claude Code >= 2.1.0 (statusLine object dans settings.json)
#
# Actions :
#   1. Crée un lien symbolique vers ce dossier dans le répertoire des plugins Claude
#   2. Copie la commande /energy dans ~/.claude/commands/
#   3. Configure statusLine + hooks dans ~/.claude/settings.json

set -e

PLUGIN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="energy-monitoring"
PLUGIN_DEST="$HOME/.claude/plugins/marketplaces/claude-plugins-official/plugins/$PLUGIN_NAME"
SETTINGS="$HOME/.claude/settings.json"
COMMANDS_DIR="$HOME/.claude/commands"
CACHE="$HOME/.claude/energy-monitoring-cache.json"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
CLAUDE_MD_MARKER="# energy-monitoring"

STATUS_CMD="[ -f $PLUGIN_DEST/scripts/status.sh ] && bash $PLUGIN_DEST/scripts/status.sh || echo '⚠ energy-monitoring KO'"
HOOK_STATS="[ -f $PLUGIN_DEST/hooks/update-stats.sh ] && bash $PLUGIN_DEST/hooks/update-stats.sh || echo '⚠ energy-monitoring: lien symbolique cassé. Relancez install.sh depuis le repo energy-extension.'"
HOOK_INTERCEPT="[ -f $PLUGIN_DEST/hooks/intercept-energy.sh ] && bash $PLUGIN_DEST/hooks/intercept-energy.sh || echo '⚠ energy-monitoring: lien symbolique cassé. Relancez install.sh depuis le repo energy-extension.'"

echo "======================================"
echo " Installation energy-monitoring"
echo "======================================"
echo ""

# ── 0. Vérification version Claude Code ───────────────────────────────────────
MIN_MAJOR=2; MIN_MINOR=1
if command -v claude &>/dev/null; then
  claude_ver=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  ver_major=$(echo "$claude_ver" | cut -d. -f1)
  ver_minor=$(echo "$claude_ver" | cut -d. -f2)
  if [[ -n "$claude_ver" ]]; then
    if (( ver_major < MIN_MAJOR || (ver_major == MIN_MAJOR && ver_minor < MIN_MINOR) )); then
      echo "⚠ Claude Code $claude_ver détecté — version >= $MIN_MAJOR.$MIN_MINOR.0 requise (statusLine)."
      echo "  Mettez à jour avec : npm update -g @anthropic-ai/claude-code"
      exit 1
    else
      echo "✓ Claude Code $claude_ver (>= $MIN_MAJOR.$MIN_MINOR.0)"
    fi
  else
    echo "⚠ Impossible de lire la version Claude Code — assurez-vous d'avoir >= $MIN_MAJOR.$MIN_MINOR.0"
  fi
else
  echo "⚠ claude non trouvé dans PATH — assurez-vous d'avoir Claude Code >= $MIN_MAJOR.$MIN_MINOR.0"
fi
echo ""

# ── 1. Lien symbolique du plugin ──────────────────────────────────────────────
mkdir -p "$(dirname "$PLUGIN_DEST")"
if [[ -L "$PLUGIN_DEST" && "$(readlink "$PLUGIN_DEST")" == "$PLUGIN_SRC" ]]; then
  echo "✓ Plugin déjà lié : $PLUGIN_DEST"
elif [[ -L "$PLUGIN_DEST" ]]; then
  rm "$PLUGIN_DEST"
  ln -s "$PLUGIN_SRC" "$PLUGIN_DEST"
  echo "✓ Lien symbolique mis à jour : $PLUGIN_DEST"
elif [[ -e "$PLUGIN_DEST" ]]; then
  echo "⚠ Un dossier existe déjà à $PLUGIN_DEST (pas un symlink)."
  echo "  Supprimez-le manuellement si vous voulez recréer le lien."
else
  ln -s "$PLUGIN_SRC" "$PLUGIN_DEST"
  echo "✓ Plugin lié : $PLUGIN_DEST"
fi

# ── 2. Rendre les scripts exécutables ────────────────────────────────────────
chmod +x "$PLUGIN_SRC/scripts/status.sh" \
         "$PLUGIN_SRC/scripts/stats.sh" \
         "$PLUGIN_SRC/hooks/update-stats.sh" \
         "$PLUGIN_SRC/hooks/intercept-energy.sh"
echo "✓ Scripts rendus exécutables"

# ── 3. Commande /energy dans ~/.claude/commands/ ─────────────────────────────
mkdir -p "$COMMANDS_DIR"
if [[ -f "$COMMANDS_DIR/energy.md" ]] && cmp -s "$PLUGIN_SRC/commands/energy.md" "$COMMANDS_DIR/energy.md"; then
  echo "✓ Commande /energy déjà à jour"
else
  cp "$PLUGIN_SRC/commands/energy.md" "$COMMANDS_DIR/energy.md"
  echo "✓ Commande /energy installée dans $COMMANDS_DIR"
fi

# ── 4. Configurer settings.json ──────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo ""
  echo "⚠ jq non trouvé — ajoutez manuellement dans $SETTINGS :"
  cat <<EOF
{
  "statusLine": { "type": "command", "command": "$STATUS_CMD" },
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "$HOOK_INTERCEPT", "timeout": 15 }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "$HOOK_STATS", "timeout": 30 }] }
    ]
  }
}
EOF
  exit 1
fi

[[ ! -f "$SETTINGS" ]] && echo '{}' > "$SETTINGS"

_hook_present() {
  local event="$1" cmd="$2"
  jq -e --arg event "$event" --arg cmd "$cmd" \
    '(.hooks[$event] // []) | any(.hooks | any(.command == $cmd))' \
    "$SETTINGS" &>/dev/null
}

needs_update=false

current_status=$(jq -r '.statusLine.command // ""' "$SETTINGS")
[[ "$current_status" != "$STATUS_CMD" ]] && needs_update=true

_hook_present "UserPromptSubmit" "$HOOK_INTERCEPT" || needs_update=true
_hook_present "Stop"             "$HOOK_STATS"     || needs_update=true

if [[ "$needs_update" == true ]]; then
  tmp=$(mktemp)
  jq \
    --arg status    "$STATUS_CMD" \
    --arg stats     "$HOOK_STATS" \
    --arg intercept "$HOOK_INTERCEPT" \
    '
    .statusLine = {"type": "command", "command": $status} |
    .hooks.UserPromptSubmit = (
      (.hooks.UserPromptSubmit // [])
      | map(select(.hooks | map(.command | test("energy-monitor")) | any | not))
      + [{ "hooks": [{ "type": "command", "command": $intercept, "timeout": 15 }] }]
    ) |
    .hooks.Stop = (
      (.hooks.Stop // [])
      | map(select(.hooks | map(.command | test("energy-monitor")) | any | not))
      + [{ "hooks": [{ "type": "command", "command": $stats, "timeout": 30 }] }]
    )
    ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

  echo "✓ statusLine configuré"
  echo "✓ Hook UserPromptSubmit configuré (interception /energy sans token)"
  echo "✓ Hook Stop configuré (mise à jour du cache)"
else
  echo "✓ settings.json déjà à jour (statusLine + hooks)"
fi

# ── 5. Prompt dans ~/.claude/CLAUDE.md ───────────────────────────────────────
touch "$CLAUDE_MD"
if grep -q "^$CLAUDE_MD_MARKER" "$CLAUDE_MD" 2>/dev/null; then
  echo "✓ Prompt energy-monitoring déjà présent dans CLAUDE.md"
else
  printf '\n%s\nUtilise le skill `energy` pour afficher un rapport de consommation énergétique des sessions Claude Code du jour.\n' \
    "$CLAUDE_MD_MARKER" >> "$CLAUDE_MD"
  echo "✓ Prompt energy-monitoring ajouté à $CLAUDE_MD"
fi

# ── 6. Initialisation du cache ───────────────────────────────────────────────
if [[ ! -f "$CACHE" ]]; then
  printf '{"date":"","requests":0,"tokens_in":0,"tokens_out":0,"updated":""}\n' > "$CACHE"
  echo "✓ Cache initialisé"
fi

echo ""
echo "======================================"
echo " Installation terminée !"
echo "======================================"
echo ""
echo "Redémarre Claude Code pour activer le plugin."
echo ""
echo "  • Barre de statut     → conso en temps réel"
echo "  • /energy             → rapport détaillé du jour (0 token)"
echo "  • /energy 2026-03-18  → rapport pour une date précise"
echo ""
