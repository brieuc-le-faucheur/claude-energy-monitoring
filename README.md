# energy-monitor — plugin Claude Code

Estime la consommation énergétique de vos sessions Claude Code et l'exprime en kilomètres équivalents parcourus en voiture thermique.

## Aperçu

![Aperçu energy-monitor](example.png)

## Ce que ça fait

**Sous le champ d'écriture**, mis à jour après chaque réponse :
```
⚡ Dernier prompt : ~17 mètres en voiture
📊 Journée 10:01–16:21 : 1712 req | 389K tok | ~2.57 kWh (~4.1 km)
```

**`/energy`** — rapport détaillé, intercepté avant Claude (0 token) :
```
======================================
 Rapport Claude Code — 2026-03-19
======================================

  Projet   : my-project
  Session  : a1b2c3d4...
  Requêtes : 42  |  Tokens in : 128450  |  Tokens out : 31200

  ...

======================================
 TOTAUX  (10:01 – 16:21)
======================================
  Sessions    : 21
  Requêtes    : 1712
  Tokens in   : 4521000
  Tokens out  : 890000

======================================
 ESTIMATION ÉNERGÉTIQUE
======================================
  Hypothèses (études 2024-2025) :
    Optimiste  : 0,0003 kWh/req  →  0.5136 kWh  ≈  0.82 km voiture
    Moyenne    : 0,0015 kWh/req  →  2.5680 kWh  ≈  4.08 km voiture
    Pessimiste : 0,003  kWh/req  →  5.1360 kWh  ≈  8.15 km voiture

  En retenant la moyenne : ~4.08 km en voiture thermique
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
│   ├── intercept-energy.sh     # Intercepte /energy avant Claude (0 token)
│   └── update-stats.sh         # Met à jour le cache après chaque réponse
└── scripts/
    ├── stats.sh                 # Rapport détaillé (/energy)
    └── status.sh                # Affichage sous le champ d'écriture (statusLine)
```
