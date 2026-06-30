# Tools

Ce dossier contient les implémentations Python des tools utilisés par les agents dans watsonx Orchestrate.

## Utilité des tools

Les tools sont les briques d'action et d'accès aux données du projet. Là où un agent porte la logique conversationnelle et la prise de décision, un tool exécute une opération concrète sur un système externe.

Les tools servent notamment à :
- interroger des systèmes métier
- lire ou écrire des données via des API
- encapsuler la logique technique d'intégration
- sécuriser les actions d'écriture avec des flux de confirmation
- exposer des capacités réutilisables à plusieurs agents

En pratique, les agents ne parlent pas directement aux APIs : ils appellent les tools définis dans ce dossier.

## Fichiers présents dans ce dossier

### [`maximo_tools.py`](tools/maximo_tools.py)
Implémente les tools pour IBM Maximo.

Il sert à :
- rechercher des assets
- lire les work orders d'un équipement
- lire les worklogs
- lister les documents attachés
- extraire le texte d'une pièce jointe
- proposer puis créer une work order

### [`servicenow_tools.py`](tools/servicenow_tools.py)
Implémente les tools pour ServiceNow.

Il sert à :
- lire un incident
- lister les incidents ouverts
- préparer une mise à jour d'incident
- appliquer une mise à jour après confirmation

### [`supabase_tools.py`](tools/supabase_tools.py)
Implémente les tools pour le stock et les commandes fournisseur via Supabase.

Il sert à :
- consulter une pièce détachée
- lister les pièces sous le seuil de stock
- consulter l'historique des commandes
- proposer puis créer une commande fournisseur

### [`slack_tools.py`](tools/slack_tools.py)
Implémente les tools de notification Slack.

Il sert à :
- envoyer un message simple
- envoyer un récapitulatif formaté de fin de traitement

### [`requirements.txt`](tools/requirements.txt)
Liste les dépendances Python nécessaires pour exécuter ces intégrations.

## En pratique

Le dossier [`tools/`](tools/) regroupe donc la couche d'intégration technique du projet. Chaque fichier y définit des fonctions exposées comme tools Orchestrate, avec leurs schémas d'entrée et de sortie, leurs appels API et leurs règles d'usage.

Cette organisation permet de séparer clairement :
- la logique conversationnelle dans les agents
- la logique technique dans les tools
- les accès aux systèmes externes dans des modules dédiés

Le résultat est plus lisible, plus maintenable et plus simple à faire évoluer.