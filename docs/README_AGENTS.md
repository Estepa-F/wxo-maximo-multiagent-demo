# Architecture des Agents Maximo

Ce document décrit l'architecture multi-agents pour IBM Maximo dans watsonx Orchestrate.

## Vue d'ensemble

L'architecture utilise un pattern d'orchestration avec un agent principal qui délègue les tâches à des agents spécialisés :

```
┌─────────────────────────────────┐
│   maximo_orchestrator           │
│   (Point d'entrée principal)    │
└────────────┬────────────────────┘
             │
             ├─────────────────────────────┐
             │                             │
             ▼                             ▼
┌────────────────────────┐    ┌────────────────────────┐
│ maximo_diagnostic_agent│    │ maximo_planning_agent  │
│ (Lecture/Consultation) │    │ (Écriture/Création)    │
└────────────────────────┘    └────────────────────────┘
```

## Agents

### 1. maximo_orchestrator

**Rôle** : Point d'entrée unique pour tous les utilisateurs

**Responsabilités** :
- Router les demandes vers l'agent approprié
- Maintenir le contexte de la conversation
- Coordonner les workflows multi-étapes (diagnostic → action)
- Fournir une expérience utilisateur fluide

**Collaborateurs** :
- `maximo_diagnostic_agent`
- `maximo_planning_agent`

**Fichier** : [`agents/maximo_orchestrator.yaml`](agents/maximo_orchestrator.yaml:1)

**Logique de routage** :
- Demandes d'information → `maximo_diagnostic_agent`
- Demandes de création → `maximo_planning_agent`
- Workflows mixtes → séquence diagnostic puis planification

### 2. maximo_diagnostic_agent

**Rôle** : Agent spécialisé en consultation et analyse (LECTURE SEULE)

**Responsabilités** :
- Consulter les work orders d'un asset
- Lire les worklogs (notes d'intervention)
- Lister et consulter les documents attachés
- Analyser l'historique et identifier les tendances
- Diagnostiquer l'état d'un équipement

**Outils disponibles** :
- `get_work_orders_for_asset` - Récupère les interventions
- `get_worklogs_for_workorder` - Lit les notes d'intervention
- `list_asset_attachments` - Liste les documents
- `get_attachment_text` - Extrait le contenu des documents

**Fichier** : [`agents/maximo_diagnostic_agent.yaml`](agents/maximo_diagnostic_agent.yaml:1)

**Cas d'usage** :
- "Quelles sont les dernières interventions sur l'asset 11430 ?"
- "Résume-moi les notes de la work order 1234"
- "Quels documents sont attachés à cet équipement ?"
- "Y a-t-il des interventions urgentes en cours ?"

### 3. maximo_planning_agent

**Rôle** : Agent spécialisé en création et planification (ÉCRITURE)

**Responsabilités** :
- Créer de nouvelles work orders
- Collecter les informations nécessaires
- Valider les données avant création
- Demander confirmation explicite
- Planifier les interventions

**Outils disponibles** :
- ⚠️ **En développement** - Les outils d'écriture ne sont pas encore implémentés
- À venir : `create_work_order`, `update_work_order_status`

**Fichier** : [`agents/maximo_planning_agent.yaml`](agents/maximo_planning_agent.yaml:1)

**Cas d'usage** :
- "Crée une work order pour l'asset 11430"
- "Planifie une maintenance préventive"
- "Ouvre une intervention urgente"

**Note** : Pour l'instant, cet agent collecte les informations et présente ce qui serait créé, mais ne peut pas encore créer effectivement les work orders.

## Workflow Typique

### Scénario 1 : Consultation simple

```
Utilisateur → Orchestrateur → Diagnostic Agent → Réponse
```

**Exemple** :
```
User: "Quelles sont les interventions sur l'asset 11430 ?"
Orchestrateur: [délègue à diagnostic_agent]
Diagnostic: [utilise get_work_orders_for_asset]
Réponse: "Voici les 5 dernières interventions..."
```

### Scénario 2 : Création simple

```
Utilisateur → Orchestrateur → Planning Agent → Confirmation → Action
```

**Exemple** :
```
User: "Crée une work order pour l'asset 11430"
Orchestrateur: [délègue à planning_agent]
Planning: "Quelle est la description du problème ?"
User: "Fuite d'huile détectée"
Planning: [collecte infos] "Voici le résumé... Confirmez-vous ?"
User: "Oui"
Planning: [crée la WO]
```

### Scénario 3 : Workflow mixte (Diagnostic → Action)

```
Utilisateur → Orchestrateur → Diagnostic Agent → Analyse
                ↓
         [Contexte conservé]
                ↓
         Planning Agent → Création
```

**Exemple** :
```
User: "Vérifie l'état de l'asset 11430"
Orchestrateur: [délègue à diagnostic_agent]
Diagnostic: "3 interventions urgentes, dont 2 non résolues..."
User: "Crée une nouvelle intervention pour ça"
Orchestrateur: [passe le contexte à planning_agent]
Planning: "Basé sur le diagnostic, je propose priorité 1..."
```

## Installation et Déploiement

### Prérequis

1. Connexion Maximo configurée :
   ```bash
   ./scripts/configure_maximo_connection.sh
   ```

2. Outils importés :
   ```bash
   ./scripts/reimport_maximo_tools.sh
   ```

### Import des Agents

**Option 1 : Script automatique (recommandé)**

```bash
./scripts/import_all_agents.sh
```

**Option 2 : Import manuel**

```bash
# 1. Importer les agents collaborateurs d'abord
orchestrate agents import --file agents/maximo_diagnostic_agent.yaml
orchestrate agents import --file agents/maximo_planning_agent.yaml

# 2. Puis l'orchestrateur
orchestrate agents import --file agents/maximo_orchestrator.yaml
```

### Vérification

```bash
# Lister tous les agents
orchestrate agents list

# Tester l'orchestrateur
orchestrate agents chat --name maximo_orchestrator
```

## Configuration

### LLM

Tous les agents utilisent actuellement : `groq/openai/gpt-oss-120b`

Pour changer le modèle, modifiez le champ `llm` dans chaque fichier YAML.

### Chain of Thought (CoT)

- **Orchestrateur** : `enable_cot: true` - Activé pour mieux raisonner sur le routage
- **Agents spécialisés** : `enable_cot: false` - Désactivé pour des réponses plus directes

### Visibilité

Tous les agents ont `hidden: false` - ils sont visibles dans l'interface utilisateur.

Pour cacher un agent (par exemple les agents spécialisés), changez en `hidden: true`.

## Priorités des Work Orders

Les agents comprennent la sémantique des priorités Maximo :

| Priorité | Niveau | Description |
|----------|--------|-------------|
| 1 | 🔴 Critique | Intervention urgente, arrêt de production |
| 2 | 🟠 Haute | Problème important, action rapide requise |
| 3 | 🟡 Moyenne | Maintenance standard |
| 4-5+ | 🟢 Faible | Maintenance préventive, non urgent |

Les agents mettent automatiquement en évidence les interventions urgentes (priorité ≤ 2).

## Évolution Future

### Phase 1 (Actuelle) : Lecture seule
- ✅ Consultation des work orders
- ✅ Lecture des worklogs
- ✅ Accès aux documents
- ✅ Architecture multi-agents

### Phase 2 : Écriture
- ⏳ Création de work orders
- ⏳ Mise à jour de statuts
- ⏳ Ajout de worklogs
- ⏳ Upload de documents

### Phase 3 : Intelligence avancée
- ⏳ Analyse prédictive
- ⏳ Recommandations automatiques
- ⏳ Détection d'anomalies
- ⏳ Optimisation de la planification

## Dépannage

### L'orchestrateur ne trouve pas les agents collaborateurs

Vérifiez que les agents sont bien importés :
```bash
orchestrate agents list | grep maximo
```

Vous devriez voir :
- `maximo_orchestrator`
- `maximo_diagnostic_agent`
- `maximo_planning_agent`

### Les outils ne sont pas disponibles

Vérifiez que les outils sont importés avec la bonne connexion :
```bash
orchestrate tools list | grep -i maximo
```

Si les outils manquent, réimportez-les :
```bash
./scripts/reimport_maximo_tools.sh
```

### Erreur de connexion

Vérifiez que la connexion est configurée :
```bash
orchestrate connections list | grep maximo_conn
```

Si la connexion manque, configurez-la :
```bash
./scripts/configure_maximo_connection.sh
```

## Exemples d'Utilisation

### Consultation

```
User: Quelles sont les interventions sur l'asset 11430 ?
Bot: [Utilise diagnostic_agent]
     Voici les 5 dernières interventions :
     1. WO-1234 (Priorité 1 🔴) - Fuite détectée - 2024-01-15
     2. WO-1233 (Priorité 3 🟡) - Maintenance préventive - 2024-01-10
     ...
```

### Analyse de document

```
User: Que dit le manuel de maintenance de l'asset 11430 ?
Bot: [Utilise diagnostic_agent]
     J'ai trouvé 3 documents attachés. Le manuel de maintenance indique...
```

### Création (workflow complet)

```
User: Vérifie l'asset 11430 et crée une WO si nécessaire
Bot: [Diagnostic] J'analyse l'asset...
     Résultat : 2 interventions urgentes non résolues détectées.
     Souhaitez-vous créer une nouvelle intervention ?
User: Oui
Bot: [Planning] Basé sur l'analyse, je propose :
     - Priorité : 1 (Critique)
     - Type : CM (Corrective Maintenance)
     - Description : Suite aux 2 interventions urgentes...
     Confirmez-vous ?
User: Oui
Bot: ✅ Work order créée : WO-1235
```

## Fichiers Importants

- [`agents/maximo_orchestrator.yaml`](agents/maximo_orchestrator.yaml:1) - Agent principal
- [`agents/maximo_diagnostic_agent.yaml`](agents/maximo_diagnostic_agent.yaml:1) - Agent de consultation
- [`agents/maximo_planning_agent.yaml`](agents/maximo_planning_agent.yaml:1) - Agent de planification
- [`tools/maximo_tools.py`](tools/maximo_tools.py:1) - Outils Python
- [`connections/maximo_conn.yaml`](connections/maximo_conn.yaml:1) - Configuration de connexion
- [`scripts/import_all_agents.sh`](scripts/import_all_agents.sh:1) - Script d'import

## Ressources

- [Documentation watsonx Orchestrate](https://developer.watson-orchestrate.ibm.com/)
- [Guide des connexions](docs/README_CONNECTION.md)
- [Guide de réimportation des outils](docs/README_REIMPORT_TOOLS.md)