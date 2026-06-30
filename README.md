<h1 align="center">WatsonX Orchestrate × Maximo — Multi-Agent Demo</h1>
<p align="center">
<strong>Une démo concrète d'IA agentique pour la maintenance industrielle.<br>
  Un assistant. Quatre systèmes. Zéro silo.</strong>
</p>
<!-- BADGES -->
<p align="center">
<img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version">
<img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
<img src="https://img.shields.io/badge/python-3.12+-blue.svg" alt="Python">
<img src="https://img.shields.io/badge/IBM-WatsonX_Orchestrate-052FAD.svg?logo=ibm&logoColor=white" alt="IBM WatsonX Orchestrate">
<img src="https://img.shields.io/badge/IBM-Maximo-052FAD.svg?logo=ibm&logoColor=white" alt="IBM Maximo">
<img src="https://img.shields.io/badge/ServiceNow-grey?logo=servicenow&logoColor=white" alt="ServiceNow">
<img src="https://img.shields.io/badge/Slack-4A154B?logo=slack&logoColor=white" alt="Slack">
</p>
<!-- CTA VIDÉO -->
<p align="center">
<a href="https://youtu.be/5qgKqxjqO4A">
<img src="https://img.shields.io/badge/▶️_Watch_Demo_on_YouTube-red?style=for-the-badge&logo=youtube&logoColor=white" alt="Watch demo on YouTube" height="50">
</a>
  &nbsp;&nbsp;
  <a href="https://www.linkedin.com/in/estepa/">
<img src="https://img.shields.io/badge/💬_Discuss_on_LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" alt="Discuss on LinkedIn" height="50">
</a>
</p>
<!-- GIF DÉMO -->
<p align="center">
<em>La cascade automatique : à la clôture du ticket ServiceNow, l'orchestrateur déclenche la notification Slack — sans intervention humaine.</em>
</p>

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
        ┌──────────────┬───────┴───────┬─────────────┬─────────────┐
        ▼              ▼               ▼             ▼             ▼
  ┌──────────┐  ┌─────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ServiceNow│  │  Maximo     │  │  Maximo  │  │  Stock   │  │  Slack   │
  │   ITSM   │  │ Diagnostic  │  │ Planning │  │ (Supabase│  │ Notifier │
  │  Agent   │  │   Agent     │  │  Agent   │  │  Agent)  │  │  Agent   │
  └────┬─────┘  └──────┬──────┘  └─────┬────┘  └────┬─────┘  └─────┬────┘
       │               │               │            │              │
       ▼               ▼               ▼            ▼              ▼
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

- créer un fichier local `.env.sdk` à partir de [`.env.sdk.exemple`](.env.sdk.exemple)
- configurer les accès nécessaires pour Maximo, ServiceNow, Supabase et Slack
- activer votre environnement watsonx Orchestrate

### Variables à modifier dans [`.env.sdk.exemple`](.env.sdk.exemple)

Avant d'exécuter les scripts, la personne qui installe le projet doit créer son propre fichier local `.env.sdk` à partir de [`.env.sdk.exemple`](.env.sdk.exemple) puis remplacer les valeurs d'exemple par ses propres informations.

#### watsonx Orchestrate
- `WO_INSTANCE_ALIAS` : alias local de l'environnement watsonx Orchestrate
- `WO_INSTANCE` : URL de l'instance watsonx Orchestrate
- `WO_API_KEY` : clé API watsonx Orchestrate

#### Maximo
- `MAXIMO_URL` : URL de l'instance Maximo
- `MAXIMO_API_KEY` : clé API Maximo

Les scripts utilisent `MAXIMO_URL` depuis le fichier local `.env.sdk`. La valeur présente dans [`connections/maximo_conn.yaml`](connections/maximo_conn.yaml) reste un placeholder public utilisé pour l'import initial.

#### ServiceNow
- `SN_INSTANCE_URL` : URL de l'instance ServiceNow
- `SN_USERNAME` : identifiant du compte de service
- `SN_PASSWORD` : mot de passe du compte de service
- `SN_CLIENT_ID` : identifiant OAuth
- `SN_CLIENT_SECRET` : secret OAuth

Les scripts utilisent `SN_INSTANCE_URL` depuis le fichier local `.env.sdk`. La valeur présente dans [`connections/servicenow_conn.yaml`](connections/servicenow_conn.yaml) reste un placeholder public utilisé pour l'import initial.

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

## 🎥 Ressources externes

- 🎬 [Vidéo démo complète sur YouTube](https://youtu.be/5qgKqxjqO4A)
- 💼 [Profil LinkedIn](https://www.linkedin.com/in/estepa/)

## ⚖️ Licence

Ce projet est distribué sous licence MIT. Voir [LICENSE](LICENSE) pour les détails.

```
MIT License
Copyright (c) 2026 François Estepa

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction [...]
```

## 🙏 Crédits

Construit avec :
- [IBM WatsonX Orchestrate](https://www.ibm.com/products/watsonx-orchestrate) et son [ADK](https://developer.watson-orchestrate.ibm.com/)
- [IBM Maximo Application Suite](https://www.ibm.com/products/maximo)
- [ServiceNow Developer PDI](https://developer.servicenow.com/)
- [Supabase](https://supabase.com/) pour la couche ERP démo
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)

---

<p align="center">
  ⭐ Si ce projet vous a inspiré, mettez une étoile au repo. Ça aide d'autres architectes à le trouver.<br>
  💬 Questions ? Ouvrez une issue ou contactez-moi via <a href="https://www.linkedin.com/in/estepa/">LinkedIn</a>.
</p>
