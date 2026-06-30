# Agents

Ce dossier contient les définitions YAML des agents utilisés dans la démonstration watsonx Orchestrate.

## Utilité des agents

Les agents permettent de découper le parcours utilisateur en rôles spécialisés, chacun responsable d'un domaine métier précis. Cette séparation apporte plusieurs bénéfices :

- meilleure lisibilité des responsabilités
- routage plus simple des demandes utilisateur
- contrôle plus strict des actions en lecture et en écriture
- prompts plus courts et plus spécialisés
- workflows multi-étapes plus faciles à orchestrer

Dans ce projet, un agent orchestrateur reçoit la demande utilisateur puis délègue vers les agents spécialisés selon l'intention détectée.

## Agents présents dans ce dossier

### [`maximo_orchestrator.yaml`](maximo_orchestrator.yaml)
Agent principal exposé à l'utilisateur.

Il sert à :
- analyser la demande
- choisir le bon agent collaborateur
- conserver la logique globale du workflow
- enchaîner les actions entre plusieurs systèmes quand c'est nécessaire

### [`maximo_diagnostic_agent.yaml`](maximo_diagnostic_agent.yaml)
Agent de consultation Maximo en lecture seule.

Il sert à :
- rechercher des assets
- consulter les work orders
- lire les worklogs
- lister et lire les documents attachés
- aider au diagnostic avant une action

### [`maximo_planning_agent.yaml`](maximo_planning_agent.yaml)
Agent de création d'interventions dans Maximo.

Il sert à :
- préparer une work order
- présenter un résumé avant validation
- créer la work order après confirmation explicite

### [`maximo_stock_agent.yaml`](maximo_stock_agent.yaml)
Agent dédié au stock de pièces détachées.

Il sert à :
- vérifier la disponibilité d'une pièce
- identifier les ruptures de stock
- proposer une commande fournisseur
- créer la commande après confirmation

### [`servicenow_ITSM_agent.yaml`](servicenow_ITSM_agent.yaml)
Agent dédié aux tickets ServiceNow.

Il sert à :
- lire un incident
- préparer une mise à jour
- ajouter des work notes
- résoudre un incident avec un résumé de clôture

### [`slack_notifier_agent.yaml`](slack_notifier_agent.yaml)
Agent de notification Slack.

Il sert à :
- envoyer un message simple à l'équipe
- publier un récapitulatif de traitement d'incident

## En pratique

Ce dossier regroupe donc les comportements IA du projet. Chaque fichier YAML définit :
- le nom de l'agent
- sa description
- ses instructions
- ses outils autorisés
- sa configuration

Cette organisation permet d'avoir des agents plus fiables, plus faciles à maintenir et plus simples à faire évoluer.