# energy-monitor — plugin Claude Code

Estime la consommation énergétique de vos sessions Claude Code et l'exprime en kilomètres équivalents parcourus en voiture thermique.

## Ce que ça fait

**Après chaque réponse Claude** (0 token consommé) :
```
⚡ Ce prompt ≈ 16m en voiture  |  Journée 10:01–16:21 : 1712 req ≈ 13.6 km
```

**Barre de statut** (mise à jour en continu) :
```
⚡ 1712 req | 389K tok | ~1.712–17.120 kWh
```

**`/energy`** — rapport détaillé, intercepté avant Claude (0 token) :
```
======================================
 Rapport Claude Code — 2026-03-19
======================================
Fenêtre               : 10:01 – 16:21
Sessions              : 21
Requêtes totales      : 1712
...
Fourchette estimée    : 1.71 – 17.12 kWh
Équiv. voiture        : 2.7 – 27.2 km (thermique, 6,5L/100km)
```

## Installation

```bash
git clone <url-du-repo> energy-monitor
bash energy-monitor/install.sh
```

Puis redémarrer Claude Code.

**Prérequis :** `jq` (pour la mise à jour automatique de `settings.json`)

```bash
# Debian/Ubuntu
sudo apt install jq

# macOS
brew install jq
```

## Méthodologie

| Paramètre | Valeur |
|---|---|
| Énergie par requête | 0,0003 – 0,003 kWh (études 2024-2025) |
| Valeur moyenne utilisée | 0,0015 kWh/req |
| Voiture thermique | 6,5 L/100 km → 6,3 kWh/10 km |

> ⚠ Ces estimations sont approximatives et ne tiennent pas compte du mix énergétique du datacenter.

## Structure

```
energy-monitor/
├── install.sh                  # Script d'installation
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   └── energy.md               # Définition de la commande /energy
├── hooks/
│   ├── intercept-energy.sh     # Intercepte /energy (0 token)
│   └── update-stats.sh         # Met à jour le cache après chaque réponse
└── scripts/
    ├── stats.sh                 # Rapport détaillé
    ├── status.sh                # Barre de statut
    └── summary.sh               # Résumé après chaque réponse
```
