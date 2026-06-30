# Project Demo Maximo

Projet de démonstration watsonx Orchestrate autour d'un parcours multi-agents de maintenance industrielle.

Le projet combine plusieurs systèmes :
- IBM Maximo pour la maintenance
- ServiceNow pour les incidents ITSM
- Supabase pour le stock de pièces
- Slack pour les notifications d'équipe

## Structure du projet

- [`agents/`](agents/) : définitions des agents Orchestrate
- [`tools/`](tools/) : tools Python appelés par les agents
- [`connections/`](connections/) : définitions des connexions aux systèmes externes
- [`scripts/`](scripts/) : scripts de configuration, d'import et de déploiement

## Démarrage rapide

### 1. Préparer l'environnement

- créer un fichier local [`.env.sdk`](.env.sdk) à partir de [`.env.sdk.exemple`](.env.sdk.exemple)
- configurer les accès nécessaires pour Maximo, ServiceNow, Supabase et Slack
- activer votre environnement watsonx Orchestrate

### 2. Déployer le projet

```bash
./scripts/deploy_complete.sh
```

### 3. Déployer étape par étape

```bash
./scripts/create_connections.sh
./scripts/reimport_maximo_tools.sh
./scripts/import_supabase_tools.sh
./scripts/import_all_agents.sh
```

## Documentation

### Documentation par dossier

- [`agents/README.md`](agents/README.md)
- [`tools/README.md`](tools/README.md)
- [`connections/README.md`](connections/README.md)
- [`scripts/README.md`](scripts/README.md)

### Guides détaillés conservés à la racine

- [`README_AGENTS.md`](README_AGENTS.md)
- [`README_CONNECTION.md`](README_CONNECTION.md)
- [`README_DEPLOY.md`](README_DEPLOY.md)
- [`README_MAXIMO.md`](README_MAXIMO.md)
- [`README_REIMPORT_TOOLS.md`](README_REIMPORT_TOOLS.md)
- [`README_SCRIPTS.md`](README_SCRIPTS.md)
- [`README_SERVICENOW.md`](README_SERVICENOW.md)
- [`README_STOCK.md`](README_STOCK.md)
- [`README_SUPABASE.md`](README_SUPABASE.md)

### Organisation recommandée à moyen terme

Pour un dépôt Git plus lisible, tu peux garder [`README.md`](README.md) comme point d'entrée principal et, plus tard, déplacer les guides détaillés de la racine vers un futur dossier `docs/`.

Ce n'est pas obligatoire avant le premier commit, mais c'est une bonne évolution si la documentation continue de grossir.


## Recommandation Git

Avant le premier commit :
- vérifier que [`.env.sdk`](.env.sdk) n'est pas versionné
- vérifier que [`venv/`](venv/) et [`bin/`](bin/) ne sont pas versionnés
- relire les README pour éviter de publier des informations sensibles ou obsolètes

Le fichier [`.gitignore`](.gitignore) a été ajouté pour couvrir les fichiers locaux et artefacts courants.