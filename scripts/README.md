# Scripts

Ce dossier contient les scripts shell utilisés pour configurer les connexions, importer les composants et déployer le projet dans watsonx Orchestrate.

## Utilité des scripts

Les scripts servent à automatiser les opérations répétitives du projet. Ils évitent de rejouer manuellement de longues suites de commandes CLI pour configurer les connexions, importer les tools et publier les agents.

Les scripts permettent notamment de :
- configurer les connexions aux systèmes externes
- importer ou réimporter les tools Python
- importer les agents dans le bon ordre
- déployer l'ensemble du projet plus rapidement
- réduire les erreurs manuelles pendant la mise en place

## Fichiers présents dans ce dossier

### [`configure_maximo_connection.sh`](scripts/configure_maximo_connection.sh)
Configure la connexion Maximo dans watsonx Orchestrate.

### [`configure_servicenow_connection.sh`](scripts/configure_servicenow_connection.sh)
Configure la connexion ServiceNow dans watsonx Orchestrate.

### [`configure_supabase_connection.sh`](scripts/configure_supabase_connection.sh)
Configure la connexion Supabase dans watsonx Orchestrate.

### [`create_connections.sh`](scripts/create_connections.sh)
Importe puis configure l'ensemble des connexions du projet.

### [`reimport_maximo_tools.sh`](scripts/reimport_maximo_tools.sh)
Réimporte les tools Maximo avec la bonne connexion.

### [`import_supabase_tools.sh`](scripts/import_supabase_tools.sh)
Importe les tools Supabase.

### [`import_all_agents.sh`](scripts/import_all_agents.sh)
Importe les agents principaux du projet dans le bon ordre.

### [`deploy_complete.sh`](scripts/deploy_complete.sh)
Lance le déploiement complet du projet : connexions, tools et agents.

## En pratique

Le dossier [`scripts/`](scripts/) regroupe donc la couche d'automatisation opérationnelle du projet. Ces scripts s'appuient principalement sur le CLI `orchestrate` pour exécuter les tâches de configuration et de déploiement.

Cette organisation permet de séparer clairement :
- la configuration d'accès dans [`connections/`](connections/)
- la logique technique d'intégration dans [`tools/`](tools/)
- la logique conversationnelle dans [`agents/`](agents/)
- l'automatisation des opérations dans [`scripts/`](scripts/)

Le résultat est un projet plus simple à installer, plus cohérent à déployer et plus facile à maintenir.