# Architecture multi-agents

Ce document décrit l'architecture du projet : 1 orchestrateur, 5 agents spécialisés, 4 systèmes connectés (ServiceNow, IBM Maximo, ERP Supabase, Slack).

## Vue d'ensemble

L'architecture utilise un pattern d'orchestration où l'utilisateur interagit avec un **agent unique** (l'orchestrateur) qui délègue chaque tâche à un **agent spécialisé** responsable d'un seul système métier.

```
                       ┌─────────────────────────────────┐
                       │      maximo_orchestrator        │
                       │   (Point d'entrée utilisateur)  │
                       └────────────────┬────────────────┘
                                        │
        ┌──────────────┬────────────────┼────────────────┬──────────────┐
        │              │                │                │              │
        ▼              ▼                ▼                ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐ ┌────────────┐
│ servicenow_  │ │   maximo_    │ │   maximo_    │ │  maximo_   │ │   slack_   │
│ ITSM_agent   │ │ diagnostic_  │ │  planning_   │ │  stock_    │ │ notifier_  │
│              │ │    agent     │ │    agent     │ │  agent     │ │   agent    │
│ Tickets      │ │ Lecture      │ │ Écriture     │ │ Stock &    │ │ Notif.     │
│ ITSM         │ │ Maximo       │ │ Maximo       │ │ commandes  │ │ équipe     │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └─────┬──────┘ └─────┬──────┘
       │                │                │                │              │
       ▼                ▼                ▼                ▼              ▼
┌──────────────┐ ┌──────────────────────────────┐ ┌────────────┐ ┌────────────┐
│  ServiceNow  │ │     IBM Maximo Application   │ │  Supabase  │ │   Slack    │
│   (OAuth 2.0 │ │   Suite (OSLC + API key)     │ │ PostgreSQL │ │  Webhook   │
│ password gr.)│ │                              │ │  + REST    │ │  + Blocks  │
└──────────────┘ └──────────────────────────────┘ └────────────┘ └────────────┘
```

**Principes** :
- 1 agent = 1 responsabilité métier
- 1 agent = 1 système backend
- Aucun couplage croisé entre agents
- L'orchestrateur ne fait que router et coordonner — il n'a aucun tool propre

## Les six agents

### 1. `maximo_orchestrator`

**Rôle** : point d'entrée unique de l'utilisateur. Comprend la demande en langage naturel et délègue à l'agent spécialiste pertinent. Conserve le contexte de la conversation (asset en cours, incident, WO, pièce mentionnée) pour éviter à l'utilisateur de répéter.

**Tools** : aucun. L'orchestrateur ne fait que router.

**Collaborateurs** :
- `servicenow_ITSM_agent`
- `maximo_diagnostic_agent`
- `maximo_planning_agent`
- `maximo_stock_agent`
- `slack_notifier_agent`

**Logique de routage** :

| Type de demande | Mots-clés typiques | Agent appelé |
|-----------------|--------------------|--------------|
| Lire un ticket d'incident | "ticket", "INC...", "incident", "de quoi il s'agit" | `servicenow_ITSM_agent` |
| Lire un asset / une WO / un guide PDF | "interventions", "asset", "guide", "worklog" | `maximo_diagnostic_agent` |
| Créer une work order | "crée une WO", "ouvre une intervention", "planifie" | `maximo_planning_agent` |
| Vérifier un stock / commander une pièce | "stock", "disponibilité", "rupture", "commande fournisseur" | `maximo_stock_agent` |
| Notifier l'équipe d'astreinte | déclenché **automatiquement** par cascade depuis ServiceNow à la clôture | `slack_notifier_agent` |

### 2. `servicenow_ITSM_agent`

**Rôle** : interagit avec ServiceNow pour la gestion des incidents (lecture et écriture).

**Tools** :
- `get_incident` — récupère les détails d'un incident par son numéro
- `list_open_incidents` — liste les incidents ouverts
- `propose_incident_update` — prépare une mise à jour (DRY-RUN)
- `update_incident` — applique la mise à jour (après confirmation)

**Particularité** : à la clôture d'un incident (état Résolu / Fermé), le tool `update_incident` retourne dans son champ `message` une **directive structurée** demandant à l'orchestrateur de déléguer ensuite à `slack_notifier_agent`. Voir [`patterns.md`](patterns.md) pour le détail du pattern "Tools chaining déclaratif".

### 3. `maximo_diagnostic_agent`

**Rôle** : opérations de **lecture** sur Maximo. Consulte les assets, les work orders, les notes d'intervention et les documents attachés.

**Tools** :
- `search_assets_by_keyword` — cherche un asset par mot-clé
- `get_work_orders_for_asset` — liste des WO d'un asset
- `get_worklogs_for_workorder` — notes d'intervention d'une WO
- `list_asset_attachments` — documents attachés à un asset
- `get_attachment_text` — extrait le contenu textuel d'un PDF / document

**Cas d'usage** :
- "Quelles sont les dernières interventions sur l'asset 11430 ?"
- "Le worklog mentionne la vanne d'admission, que dit le guide à ce sujet ?"
- "Résume-moi les notes de la WO 1208."

### 4. `maximo_planning_agent`

**Rôle** : opérations d'**écriture** sur Maximo. Crée des work orders correctives ou préventives.

**Tools** :
- `propose_work_order` — prépare une WO (DRY-RUN), retourne un résumé à confirmer
- `create_work_order` — crée réellement la WO (après confirmation utilisateur)

**Particularité** : suit strictement le pattern propose / confirm. Voir [`patterns.md`](patterns.md).

**Cas d'usage** :
- "Crée une work order corrective sur l'asset 11430 pour remplacer la vanne d'admission, priorité haute, date cible dans 7 jours."

### 5. `maximo_stock_agent`

**Rôle** : gestion d'un système **séparé de Maximo** — le catalogue des pièces de rechange et les commandes fournisseurs (stocké dans Supabase). C'est le système qui matérialise l'ERP de stock.

**Tools** :
- `get_spare_part` — consultation d'une pièce par référence
- `list_low_stock_parts` — pièces en rupture (stock ≤ min_stock)
- `list_orders_for_part` — historique des commandes d'une pièce
- `propose_supplier_order` — propose une commande fournisseur (DRY-RUN)
- `create_supplier_order` — crée réellement la commande (après confirmation)

**Cas d'usage** :
- "Quelle est la disponibilité de la pièce DRV-100-AS en stock ?"
- "Passe la commande fournisseur pour 1 unité de DRV-100-AS."

### 6. `slack_notifier_agent`

**Rôle** : envoi de notifications structurées (Slack Block Kit) sur le canal de l'équipe maintenance. Déclenché à la clôture d'un incident ServiceNow via le pattern de tools chaining déclaratif.

**Tools** :
- `send_incident_summary` — envoie un message Block Kit récapitulant l'incident clôturé, la WO Maximo, la commande fournisseur et les actions menées

**Cas d'usage** : aucune intervention humaine directe. L'agent est appelé par l'orchestrateur sur directive de `servicenow_ITSM_agent`.

## Patterns architecturaux

Deux patterns clés sous-tendent toute l'architecture. Ils sont documentés en détail dans [`patterns.md`](patterns.md).

### Propose / Confirm

Aucune écriture dans aucun système ne se déclenche sans validation explicite de l'utilisateur. Chaque écriture (création de WO, mise à jour de ticket, clôture, commande fournisseur) est précédée d'un appel à un tool `propose_*` qui retourne un résumé. L'utilisateur confirme par "oui" / "confirme", puis et seulement alors le tool `*_create` ou `update_*` est appelé.

### Tools Chaining déclaratif

Quand un tool exécute une écriture qui doit déclencher un effet de bord (par exemple : notification Slack à la clôture d'incident), le tool retourne dans sa réponse une **directive structurée** que l'orchestrateur lit et exécute. C'est plus fiable qu'une règle dans le prompt système, qui peut être ignorée par le LLM.

## Workflows de référence

### Workflow A — Consultation simple

```
Utilisateur → Orchestrateur → Agent spécialiste → Réponse
```

Exemple : "Quelles sont les dernières interventions sur l'asset 11430 ?"

→ orchestrateur délègue à `maximo_diagnostic_agent`
→ `get_work_orders_for_asset(assetnum="11430")`
→ liste des WO formatée et retournée à l'utilisateur

### Workflow B — Création avec validation

```
Utilisateur → Orchestrateur → Agent spécialiste → propose_* → Confirmation utilisateur → create_* → Confirmation système
```

Exemple : "Passe la commande fournisseur pour 1 unité de DRV-100-AS."

→ orchestrateur délègue à `maximo_stock_agent`
→ `propose_supplier_order` : résumé avec prix, délai, fournisseur, date de livraison
→ utilisateur : "oui, confirme"
→ `create_supplier_order` : commande créée avec id, status PENDING

### Workflow C — Cross-système avec cascade automatique

C'est le workflow phare de la démo. Toutes les écritures et la cascade Slack sont enchaînées par l'orchestrateur sur la base d'une seule conversation utilisateur :

```
1. Utilisateur lit l'incident INC0010003 (servicenow_ITSM_agent)
2. Utilisateur consulte l'historique de l'asset 11430 (maximo_diagnostic_agent)
3. Utilisateur consulte le guide PDF de l'asset (maximo_diagnostic_agent)
4. Utilisateur vérifie le stock de DRV-100-AS (maximo_stock_agent)
5. Utilisateur passe la commande (propose + confirm + create — maximo_stock_agent)
6. Utilisateur crée la WO corrective sur l'asset (propose + confirm + create — maximo_planning_agent)
7. Utilisateur ajoute une note de progression au ticket (propose + confirm — servicenow_ITSM_agent)
8. Utilisateur clôture le ticket (propose + confirm + update — servicenow_ITSM_agent)
   ↓ Le tool update_incident détecte une clôture et retourne une directive
   ↓ ATTENTION ORCHESTRATEUR — ACTION RESTANTE OBLIGATOIRE
9. L'orchestrateur lit la directive et délègue à slack_notifier_agent
10. slack_notifier_agent envoie le message Block Kit récapitulatif
```

Le scénario complet en 12 questions (avec les énoncés exacts à utiliser pour rejouer la démo) est dans [`scenario-demo.md`](scenario-demo.md).

## Configuration LLM

Tous les agents utilisent le même modèle en démo : `groq/openai/gpt-oss-120b`.

Pour changer le LLM, modifier le champ `llm:` dans chaque fichier `agents/*.yaml`. L'architecture est indépendante du LLM — Granite, Llama, Mistral et Claude fonctionnent aussi.

**Configuration Chain of Thought** :
- `enable_cot: true` sur l'orchestrateur (raisonnement de routage)
- `enable_cot: true` sur `maximo_stock_agent` et `servicenow_ITSM_agent` (pattern propose / confirm complexe)
- `enable_cot: false` sur les agents purement consultatifs (réponses plus directes)

## Évolutions possibles

L'architecture est conçue pour scaler horizontalement. Ajouter un nouveau système (Teams, SAP PM, Workday, etc.) consiste à :

1. Créer une connection WXO vers le nouveau système (ApiKey, OAuth, etc.)
2. Écrire les tools Python qui exposent les opérations métier
3. Créer un nouvel agent spécialiste qui possède ces tools et ses propres instructions
4. Ajouter cet agent dans la liste `collaborators:` de l'orchestrateur
5. Ajouter la règle de routage correspondante dans les instructions de l'orchestrateur

Aucun agent existant n'a besoin d'être modifié.
