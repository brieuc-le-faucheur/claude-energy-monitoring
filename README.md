# energy-monitor — plugin Claude Code

Estime la consommation énergétique de vos sessions Claude Code et l'exprime en kilomètres équivalents parcourus en voiture thermique.

> 🤖 Ce projet est entièrement **vibe codé** — conçu et développé en collaboration avec Claude Code, sans écrire une seule ligne de code à la main.

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

| Paramètre | Valeur | Source |
|---|---|---|
| Énergie par requête — optimiste | 0,0003 kWh/req (0,3 Wh) | Epoch AI, fév. 2025 |
| Énergie par requête — pessimiste | 0,003 kWh/req (3 Wh) | IEA, jan. 2024 |
| **Valeur moyenne retenue** | **0,0015 kWh/req (1,5 Wh)** | Milieu de fourchette 2024-2025 |
| Voiture thermique | 6,5 L/100 km → 6,3 kWh/10 km | ADEME, Bilan Carbone® 2023 |

### Sources détaillées

#### Énergie par requête IA

- **[Epoch AI — « How much energy does ChatGPT use? »](https://epoch.ai/gradient-updates/how-much-energy-does-chatgpt-use)** (fév. 2025)
  Estimation pour GPT-4o : **≈ 0,3 Wh/requête** (modèles récents optimisés). Constitue la borne basse de la fourchette.

- **[IEA — *Electricity 2024*, chap. Data Centres and Energy](https://www.iea.org/reports/electricity-2024)** (jan. 2024)
  Estimation pour ChatGPT (modèles larges) : **≈ 3 Wh/requête** (environ 10× une recherche Google). Constitue la borne haute de la fourchette.

- **OpenAI (déclaration publique)**
  2,5 milliards de requêtes/jour pour une consommation déclarée de 850 MWh/jour → **≈ 0,34 Wh/requête**, cohérent avec la borne basse Epoch AI.

- **[Luccioni et al. — *Power Hungry Processing: Watts Driving the Cost of AI Deployment?*](https://arxiv.org/abs/2311.16863)** (arXiv:2311.16863, nov. 2023)
  Mesure empirique sur 88 tâches NLP : de 0,002 Wh (modèles légers) à 4,3 Wh/requête (modèles génératifs larges). Référence académique de base pour la fourchette.

#### Consommation de la voiture thermique

- **[ADEME — Base Carbone® / Bilan Carbone®](https://bilans-ges.ademe.fr/)** (parc automobile FR, 2023)
  Consommation moyenne du parc thermique français : **6,5 L/100 km**, soit **6,3 kWh/10 km** (PCI essence : 9,7 kWh/L).

> ⚠ Ces estimations sont approximatives. Elles ne tiennent pas compte du mix énergétique du datacenter (renouvelables vs fossiles), ni du refroidissement, ni de l'amortissement du matériel.

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
