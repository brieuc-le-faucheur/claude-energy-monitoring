#!/bin/bash
# update.sh — Met à jour le plugin energy-monitor via git pull.
#
# Usage : bash update.sh
#
# Actions :
#   1. Lit la version actuelle (plugin.json)
#   2. git pull pour récupérer les dernières modifications
#   3. Ré-applique les étapes idempotentes d'installation
#      (chmod scripts, commande /energy, settings.json)

set -e

PLUGIN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="energy-monitor"
PLUGIN_DEST="$HOME/.claude/plugins/marketplaces/claude-plugins-official/plugins/$PLUGIN_NAME"
SETTINGS="$HOME/.claude/settings.json"
COMMANDS_DIR="$HOME/.claude/commands"

STATUS_CMD="bash $PLUGIN_DEST/scripts/status.sh"
HOOK_STATS="bash $PLUGIN_DEST/hooks/update-stats.sh"
HOOK_INTERCEPT="bash $PLUGIN_DEST/hooks/intercept-energy.sh"

echo "======================================"
echo " Mise à jour energy-monitor"
echo "======================================"
echo ""

# ── Vérification que le plugin est installé ───────────────────────────────────
if [[ ! -L "$PLUGIN_DEST" ]]; then
  echo "✗ Plugin non installé. Lancez d'abord : bash install.sh"
  exit 1
fi

# ── 1. Version actuelle ───────────────────────────────────────────────────────
if command -v jq &>/dev/null && [[ -f "$PLUGIN_SRC/.claude-plugin/plugin.json" ]]; then
  version_before=$(jq -r '.version' "$PLUGIN_SRC/.claude-plugin/plugin.json")
else
  version_before="inconnue"
fi
echo "Version actuelle : $version_before"
echo ""

# ── 2. git pull ───────────────────────────────────────────────────────────────
echo "Récupération des mises à jour..."
cd "$PLUGIN_SRC"

if ! git pull --ff-only 2>&1; then
  echo ""
  echo "✗ git pull a échoué. Vérifiez votre connexion ou résolvez les conflits."
  exit 1
fi

echo ""

# ── Version après mise à jour ─────────────────────────────────────────────────
if command -v jq &>/dev/null && [[ -f "$PLUGIN_SRC/.claude-plugin/plugin.json" ]]; then
  version_after=$(jq -r '.version' "$PLUGIN_SRC/.claude-plugin/plugin.json")
else
  version_after="inconnue"
fi

if [[ "$version_before" == "$version_after" ]]; then
  echo "Déjà à jour (version $version_after)."
else
  echo "Mise à jour : $version_before → $version_after"
fi
echo ""

# ── 3. Rendre les scripts exécutables ────────────────────────────────────────
chmod +x "$PLUGIN_SRC/scripts/status.sh" \
         "$PLUGIN_SRC/scripts/stats.sh" \
         "$PLUGIN_SRC/hooks/update-stats.sh" \
         "$PLUGIN_SRC/hooks/intercept-energy.sh"
echo "✓ Scripts rendus exécutables"

# ── 4. Commande /energy dans ~/.claude/commands/ ─────────────────────────────
mkdir -p "$COMMANDS_DIR"
if [[ -f "$COMMANDS_DIR/energy.md" ]] && cmp -s "$PLUGIN_SRC/commands/energy.md" "$COMMANDS_DIR/energy.md"; then
  echo "✓ Commande /energy déjà à jour"
else
  cp "$PLUGIN_SRC/commands/energy.md" "$COMMANDS_DIR/energy.md"
  echo "✓ Commande /energy mise à jour dans $COMMANDS_DIR"
fi

# ── 5. Configurer settings.json ──────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo ""
  echo "⚠ jq non trouvé — vérifiez manuellement $SETTINGS si les chemins des hooks ont changé."
else
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

    echo "✓ settings.json mis à jour (statusLine + hooks)"
  else
    echo "✓ settings.json déjà à jour"
  fi
fi

echo ""
echo "======================================"
echo " Mise à jour terminée !"
echo "======================================"
echo ""
echo "Redémarre Claude Code pour appliquer les changements."
echo ""
