---
description: Rapport de consommation énergétique estimée des sessions Claude Code du jour
argument-hint: [YYYY-MM-DD | 1h | 2d | 1w | 2m]
allowed-tools: [Bash]
---

# Rapport Énergie Claude Code

Génère un rapport détaillé de consommation énergétique estimée pour les sessions Claude Code.

## Instructions

1. Détermine le chemin du script :
   ```
   PLUGIN_DIR="$HOME/.claude/plugins/marketplaces/claude-plugins-official/plugins/energy-monitor"
   SCRIPT="$PLUGIN_DIR/scripts/stats.sh"
   ```

2. Si `$ARGUMENTS` est fourni, exécute :
   ```
   bash "$SCRIPT" $ARGUMENTS
   ```
   Sinon, exécute sans argument (rapport du jour) :
   ```
   bash "$SCRIPT"
   ```

3. Affiche le résultat tel quel, sans reformatage.

4. Si le script n'existe pas, indique que le plugin `energy-monitor` n'est pas installé
   et renvoie l'utilisateur vers `install.sh`.
