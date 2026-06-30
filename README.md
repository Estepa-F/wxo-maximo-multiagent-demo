# Project Demo Maximo

Projet de démonstration watsonx Orchestrate autour d'un parcours multi-agents de maintenance industrielle.

Le projet combine plusieurs systèmes :
- IBM Maximo pour la maintenance
- ServiceNow pour les incidents ITSM
- Supabase pour le stock de pièces
- Slack pour les notifications d'équipe

## 🎯 Le problème

Dans un site industriel, traiter un incident de maintenance demande au manager de jongler entre **4 systèmes minimum** :

- 🎫 **ServiceNow** pour le ticket d'incident
- 🔧 **IBM Maximo** pour la gestion d'actifs et les work orders
- 📦 **ERP** pour vérifier le stock et passer les commandes
- 💬 **Slack** pour notifier l'équipe d'astreinte

Résultat : **20 minutes minimum par incident**, des erreurs de saisie, des oublis de notification, et zéro traçabilité unifiée.

## 💡 La solution

Une **architecture multi-agents** où :

- **L'utilisateur parle à un seul orchestrateur** dans une conversation naturelle
- L'**orchestrateur délègue** chaque tâche à un agent spécialisé sur un système
- Toute **écriture passe par un protocole propose / confirm** — l'humain reste dans la boucle
- Les **effets de bord** (notifications) sont déclenchés **automatiquement** par les tools eux-mêmes via un pattern de tools chaining déclaratif

## 🏗️ Architecture

```
                  ┌─────────────────────────┐
                  │   maximo_orchestrator   │
                  │   (point d'entrée)      │
                  └────────────┬────────────┘
                               │
        ┌──────────────┬───────┴───────┬──────────────┬──────────────┐
        ▼              ▼               ▼              ▼              ▼
  ┌──────────┐  ┌─────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ServiceNow│  │  Maximo     │  │  Maximo  │  │  Stock   │  │  Slack   │
  │   ITSM   │  │ Diagnostic  │  │ Planning │  │ (Supabase│  │ Notifier │
  │  Agent   │  │   Agent     │  │  Agent   │  │  Agent)  │  │  Agent   │
  └────┬─────┘  └──────┬──────┘  └─────┬────┘  └────┬─────┘  └─────┬────┘
       │               │                │            │              │
       ▼               ▼                ▼            ▼              ▼
  ┌──────────┐  ┌─────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ServiceNow│  │   Maximo    │  │  Maximo  │  │ Supabase │  │  Slack   │
  │   REST   │  │   OSLC      │  │   OSLC   │  │   REST   │  │ Webhook  │
  │  OAuth2  │  │  API Key    │  │ API Key  │  │ API Key  │  │   URL    │
  └──────────┘  └─────────────┘  └──────────┘  └──────────┘  └──────────┘
```

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

### Variables à modifier dans [`.env.sdk`](.env.sdk)

Avant d'exécuter les scripts, la personne qui installe le projet doit remplacer les valeurs d'exemple par ses propres informations.

#### watsonx Orchestrate
- `WO_INSTANCE_ALIAS` : alias local de l'environnement watsonx Orchestrate
- `WO_INSTANCE` : URL de l'instance watsonx Orchestrate
- `WO_API_KEY` : clé API watsonx Orchestrate

#### Maximo
- `MAXIMO_API_KEY` : clé API Maximo

L'URL Maximo utilisée dans [`connections/maximo_conn.yaml`](connections/maximo_conn.yaml:1) est un placeholder public et doit être adaptée à l'instance cible au moment de la configuration.

#### ServiceNow
- `SN_INSTANCE_URL` : URL de l'instance ServiceNow
- `SN_USERNAME` : identifiant du compte de service
- `SN_PASSWORD` : mot de passe du compte de service
- `SN_CLIENT_ID` : identifiant OAuth
- `SN_CLIENT_SECRET` : secret OAuth

#### Supabase
- `SUPABASE_URL` : URL du projet Supabase
- `SUPABASE_KEY` : clé API Supabase utilisée par les scripts de configuration

#### Slack
- `SLACK_WEBHOOK_URL` : URL du webhook Slack utilisé pour les notifications

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

### Guides détaillés dans [`docs/`](docs/)

- [`docs/README_AGENTS.md`](docs/README_AGENTS.md)
- [`docs/README_CONNECTION.md`](docs/README_CONNECTION.md)
- [`docs/README_DEPLOY.md`](docs/README_DEPLOY.md)
- [`docs/README_MAXIMO.md`](docs/README_MAXIMO.md)
- [`docs/README_REIMPORT_TOOLS.md`](docs/README_REIMPORT_TOOLS.md)
- [`docs/README_SCRIPTS.md`](docs/README_SCRIPTS.md)
- [`docs/README_SERVICENOW.md`](docs/README_SERVICENOW.md)
- [`docs/README_STOCK.md`](docs/README_STOCK.md)
- [`docs/README_SUPABASE.md`](docs/README_SUPABASE.md)

### Organisation recommandée à moyen terme

Pour un dépôt Git plus lisible, tu peux garder [`README.md`](README.md) comme point d'entrée principal et, plus tard, déplacer les guides détaillés de la racine vers un futur dossier `docs/`.

Ce n'est pas obligatoire avant le premier commit, mais c'est une bonne évolution si la documentation continue de grossir.


## Recommandation Git

Avant le premier commit :
- vérifier que [`.env.sdk`](.env.sdk) n'est pas versionné
- vérifier que [`venv/`](venv/) et [`bin/`](bin/) ne sont pas versionnés
- relire les README pour éviter de publier des informations sensibles ou obsolètes

Le fichier [`.gitignore`](.gitignore) a été ajouté pour couvrir les fichiers locaux et artefacts courants.