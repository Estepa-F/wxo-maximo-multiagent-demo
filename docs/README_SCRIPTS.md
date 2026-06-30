# Scripts de Déploiement watsonx Orchestrate

Ce document décrit les scripts conservés pour configurer les connexions et déployer les composants principaux du projet.

## Scripts disponibles

### 1. Scripts de configuration des connexions

#### [`scripts/configure_maximo_connection.sh`](scripts/configure_maximo_connection.sh:1)
Configure la connexion Maximo.

#### [`scripts/configure_servicenow_connection.sh`](scripts/configure_servicenow_connection.sh:1)
Configure la connexion ServiceNow.

#### [`scripts/configure_supabase_connection.sh`](scripts/configure_supabase_connection.sh:1)
Configure la connexion Supabase.

### 2. Scripts d'import et de réimport

#### [`scripts/reimport_maximo_tools.sh`](scripts/reimport_maximo_tools.sh:1)
Réimporte les tools Maximo.

#### [`scripts/import_supabase_tools.sh`](scripts/import_supabase_tools.sh:1)
Importe les tools Supabase.

#### [`scripts/import_all_agents.sh`](scripts/import_all_agents.sh:1)
Importe les agents principaux du projet.

### 3. Scripts de déploiement global

#### [`scripts/create_connections.sh`](scripts/create_connections.sh:1)
Importe et configure les connexions du projet.

#### [`scripts/deploy_complete.sh`](scripts/deploy_complete.sh:1)
Script principal de déploiement complet.

## Workflow recommandé

### Déploiement complet

```bash
./scripts/deploy_complete.sh
```

### Déploiement par étapes

```bash
./scripts/create_connections.sh
./scripts/reimport_maximo_tools.sh
./scripts/import_supabase_tools.sh
./scripts/import_all_agents.sh
```

## Scripts supprimés

Les scripts suivants ont été retirés pour simplifier le projet et conserver uniquement les scripts de déploiement principaux :

- `scripts/clean_demo_wo.sh`
- `scripts/deploy_maximo.sh`
- `scripts/doctor.sh`
- `scripts/precheck.sh`
- `scripts/reimport_all.sh`
- `scripts/test_servicenow_connection.sh`
- `scripts/import_servicenow_tools.sh`

## Remarque

Si un README plus ancien référence encore un script supprimé, il faut désormais utiliser [`scripts/deploy_complete.sh`](scripts/deploy_complete.sh:1) ou l'un des scripts conservés ci-dessus selon le besoin.

## Notes importantes

1. **Ordre de déploiement**: Toujours déployer les connexions avant les outils
2. **Credentials**: Les credentials ServiceNow sont automatiques via `.env.sdk`, mais Maximo nécessite une configuration manuelle
3. **Réimport**: Les outils et agents peuvent être réimportés sans problème (écrasement)
4. **OAuth2**: ServiceNow utilise OAuth 2.0 Password Grant (moins sécurisé, à remplacer par Authorization Code en production)
5. **Pattern de confirmation**: Les outils ServiceNow utilisent un pattern en 2 temps pour les modifications (propose → confirm → update)

---

**Créé avec Bob - watsonx Orchestrate Agent Architect**