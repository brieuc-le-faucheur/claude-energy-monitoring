#!/bin/bash
# uninstall.sh — Désinstalle le plugin energy-monitor de Claude Code.
#
# Actions :
#   1. Supprime le lien symbolique du plugin
#   2. Supprime la commande /energy de ~/.claude/commands/
#   3. Retire statusLine + hooks energy-monitor de ~/.claude/settings.json
#   4. Retire le prompt energy-monitor de ~/.claude/CLAUDE.md
#   5. Supprime le cache et le state file (uniquement avec --purge)
#
# Usage :
#   ./uninstall.sh           # désinstalle, conserve le cache
#   ./uninstall.sh --purge   # désinstalle et supprime le cache

PLUGIN_NAME="energy-monitor"
PLUGIN_DEST="$HOME/.claude/plugins/marketplaces/claude-plugins-official/plugins/$PLUGIN_NAME"
SETTINGS="$HOME/.claude/settings.json"
COMMANDS_DIR="$HOME/.claude/commands"
CACHE="$HOME/.claude/energy-monitor-cache.json"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
CLAUDE_MD_MARKER="# energy-monitor"
STATE_FILE="/tmp/.claude-energy-state"

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

errors=0

echo "======================================"
echo " Désinstallation energy-monitor"
echo "======================================"
echo ""

# ── 1. Lien symbolique du plugin ──────────────────────────────────────────────
if [[ -L "$PLUGIN_DEST" ]]; then
  rm "$PLUGIN_DEST"
  echo "✓ Lien symbolique supprimé : $PLUGIN_DEST"
elif [[ -e "$PLUGIN_DEST" ]]; then
  echo "⚠ $PLUGIN_DEST existe mais n'est pas un symlink — ignoré (supprimez manuellement)"
  (( errors++ )) || true
else
  echo "✓ Lien symbolique déjà absent"
fi

# ── 2. Commande /energy ───────────────────────────────────────────────────────
if [[ -f "$COMMANDS_DIR/energy.md" ]]; then
  rm "$COMMANDS_DIR/energy.md"
  echo "✓ Commande /energy supprimée"
else
  echo "✓ Commande /energy déjà absente"
fi

# ── 3. settings.json ─────────────────────────────────────────────────────────
if [[ ! -f "$SETTINGS" ]]; then
  echo "✓ settings.json absent — rien à nettoyer"
elif ! command -v jq &>/dev/null; then
  echo "⚠ jq non trouvé — retirez manuellement de $SETTINGS :"
  echo "   • statusLine (si valeur contient \"energy-monitor\")"
  echo "   • hooks UserPromptSubmit et Stop contenant \"energy-monitor\""
  (( errors++ )) || true
else
  current_status=$(jq -r '.statusLine.command // ""' "$SETTINGS")

  tmp=$(mktemp)
  jq '
    if ((.statusLine.command // "") | test("energy-monitor")) then
      del(.statusLine)
    else . end |

    if .hooks.UserPromptSubmit then
      .hooks.UserPromptSubmit |= map(
        select(.hooks | map(.command | test("energy-monitor")) | any | not)
      )
      | if (.hooks.UserPromptSubmit | length) == 0 then del(.hooks.UserPromptSubmit) else . end
    else . end |

    if .hooks.Stop then
      .hooks.Stop |= map(
        select(.hooks | map(.command | test("energy-monitor")) | any | not)
      )
      | if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end
    else . end |

    if .hooks == {} then del(.hooks) else . end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

  if [[ "$current_status" == *"energy-monitor"* ]]; then
    echo "✓ statusLine retiré"
  else
    echo "✓ statusLine inchangé (n'appartenait pas au plugin)"
  fi
  echo "✓ Hooks energy-monitor retirés de settings.json"
fi

# ── 4. Prompt CLAUDE.md ───────────────────────────────────────────────────────
if [[ -f "$CLAUDE_MD" ]] && grep -q "^$CLAUDE_MD_MARKER" "$CLAUDE_MD" 2>/dev/null; then
  tmp=$(mktemp)
  awk "
    /^$CLAUDE_MD_MARKER/ { found=1; pending=\"\"; next }
    found && /^#/ && !/^$CLAUDE_MD_MARKER/ { found=0 }
    !found {
      if (/^[[:space:]]*\$/) { pending = pending \$0 ORS; next }
      printf \"%s\", pending; pending=\"\"
      print
    }
    END { printf \"%s\", pending }
  " "$CLAUDE_MD" > "$tmp" && mv "$tmp" "$CLAUDE_MD"
  echo "✓ Prompt energy-monitor retiré de $CLAUDE_MD"
else
  echo "✓ Prompt energy-monitor déjà absent de $CLAUDE_MD"
fi

# ── 5. Cache et state file ────────────────────────────────────────────────────
if [[ "$PURGE" == true ]]; then
  if [[ -f "$CACHE" ]]; then
    rm "$CACHE"
    echo "✓ Cache supprimé : $CACHE"
  else
    echo "✓ Cache déjà absent"
  fi
  if [[ -f "$STATE_FILE" ]]; then
    rm "$STATE_FILE"
    echo "✓ State file supprimé : $STATE_FILE"
  fi
else
  echo "  Cache conservé : $CACHE"
  echo "  (utilisez --purge pour le supprimer)"
fi

# ── Bilan ─────────────────────────────────────────────────────────────────────
echo ""
echo "======================================"
if (( errors > 0 )); then
  echo " Désinstallation terminée avec $errors avertissement(s)."
else
  echo " Désinstallation terminée !"
fi
echo "======================================"
echo ""
echo "Redémarre Claude Code pour désactiver le plugin."
echo ""
