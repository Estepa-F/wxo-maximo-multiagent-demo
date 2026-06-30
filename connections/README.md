# Connections

Ce dossier contient les définitions des connexions utilisées par les tools et les agents dans watsonx Orchestrate.

## Utilité des connexions

Les connexions permettent de déclarer comment le projet accède aux systèmes externes. Elles centralisent les informations de connexion nécessaires aux tools sans les coder directement dans les fichiers Python.

Les connexions servent à :
- configurer l'accès aux systèmes externes
- séparer la configuration de la logique applicative
- stocker les paramètres techniques par environnement
- permettre aux tools d'utiliser les bons identifiants et URLs
- faciliter le déploiement et la maintenance des intégrations

En pratique, les tools lisent ces connexions via watsonx Orchestrate pour appeler Maximo, ServiceNow, Slack ou Supabase.

## Fichiers présents dans ce dossier

### [`maximo_conn.yaml`](maximo_conn.yaml)
Définit la connexion vers IBM Maximo.

Elle sert à :
- déclarer l'URL du serveur Maximo
- configurer une authentification de type API key
- fournir la base de connexion utilisée par [`maximo_tools.py`](../tools/maximo_tools.py)

### [`servicenow_conn.yaml`](servicenow_conn.yaml)
Définit la connexion vers ServiceNow.

Elle sert à :
- déclarer l'URL de l'instance ServiceNow
- configurer une authentification OAuth password flow
- fournir la connexion utilisée par [`servicenow_tools.py`](../tools/servicenow_tools.py)

### [`slack_conn.yaml`](slack_conn.yaml)
Définit la connexion vers Slack.

Elle sert à :
- stocker les variables nécessaires à l'envoi de notifications
- configurer une connexion de type key/value
- fournir la configuration utilisée par [`slack_tools.py`](../tools/slack_tools.py)

### [`supabase_conn.yaml`](supabase_conn.yaml)
Définit la connexion vers Supabase.

Elle sert à :
- stocker l'URL et la clé d'accès Supabase
- configurer une connexion de type key/value
- fournir la configuration utilisée par [`supabase_tools.py`](../tools/supabase_tools.py)

## En pratique

Ce dossier regroupe donc la configuration d'accès aux services externes du projet. Chaque fichier YAML définit un `app_id`, un type de connexion et les environnements disponibles, généralement `draft` et `live`.

Cette organisation permet de séparer clairement :
- les secrets et paramètres d'accès dans les connexions
- la logique technique dans les tools
- la logique conversationnelle dans les agents

Le résultat est plus propre, plus sécurisé et plus simple à administrer.