# Agent Maximo pour watsonx Orchestrate

Agent intelligent pour interroger IBM Maximo Application Suite via des questions en langage naturel.

## 🎯 Objectif de la démo

Démontrer deux capacités principales :

1. **Logs d'interventions** : Consultation des work orders (MXAPIWODETAIL) et leurs worklogs
2. **Attachments d'assets** : Liste et consultation des documents attachés (MXAPIASSET/DOCLINKS)

## 📁 Structure du projet

```
.
├── tools/
│   ├── maximo_tools.py      # Tools Python pour l'API Maximo
│   └── requirements.txt     # Dépendances Python
├── connections/
│   └── maximo_conn.yaml     # Configuration de la connexion
├── agents/
│   └── maximo_diagnostic_agent.yaml # Définition de l'agent de consultation
└── scripts/
    ├── configure_maximo_connection.sh
    ├── reimport_maximo_tools.sh
    └── deploy_complete.sh
```

## 🔧 Tools disponibles

### 1. `get_work_orders_for_asset`
Récupère les interventions (work orders) pour un asset donné.
- **Paramètres** : `assetnum`, `siteid` (optionnel), `limit`
- **Retour** : Liste des work orders avec numéro, description, statut, type, date

### 2. `get_worklogs_for_workorder`
Lit les logs détaillés d'une intervention.
- **Paramètres** : `wonum`, `siteid` (optionnel)
- **Retour** : Liste des entrées de worklog avec type, description, détails, auteur, date

### 3. `list_asset_attachments`
Liste les documents attachés à un asset.
- **Paramètres** : `assetnum`, `siteid` (optionnel)
- **Retour** : Liste des attachments avec id, nom de fichier, description, lien

### 4. `get_attachment_text`
Extrait le contenu textuel d'un document (supporte PDF et texte).
- **Paramètres** : `assetnum`, `attachment_id`, `siteid` (optionnel), `max_chars`
- **Retour** : Contenu textuel du document

## 🚀 Déploiement

### Prérequis

1. **Environnement Python** :
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # macOS/Linux
   # ou
   .\venv\Scripts\activate.ps1  # Windows
   ```

2. **Installation du SDK watsonx Orchestrate** :
   ```bash
   pip install ibm-watsonx-orchestrate
   ```

3. **Configuration de l'environnement WXO** :
   ```bash
   # Ajouter votre environnement
   orchestrate env add -n production -u <votre-url-wxo> --activate
   
   # Activer l'environnement
   orchestrate env activate production
   ```

4. **Obtenir votre API key Maximo** :
   ```bash
   # Créer une API key Maximo (expiration infinie)
   POST {MAXIMO_BASE_URL}/oslc/apitoken/create
   Body: {"expiration": -1}
   ```

### Déploiement recommandé

```bash
./scripts/configure_maximo_connection.sh
./scripts/reimport_maximo_tools.sh
./scripts/import_all_agents.sh
```

Ces scripts permettent de configurer la connexion Maximo, réimporter les tools, puis importer les agents du projet.

### Déploiement manuel

Si vous préférez exécuter les commandes une par une :

```bash
# 1. Importer la connection
orchestrate connections import -f connections/maximo_conn.yaml

# 2. Configurer la connection
orchestrate connections configure -a maximo_conn --env draft -t team -k key_value

# 3. Définir les credentials (remplacez par vos vraies valeurs)
orchestrate connections set-credentials -a maximo_conn --env draft \
  --entries '{"MAXIMO_BASE_URL":"https://manage.inst1.apps.mas.example.com/maximo","MAXIMO_APIKEY":"votre-api-key"}'

# 4. Importer les tools
orchestrate tools import -k python -f tools/maximo_tools.py \
  -r tools/requirements.txt --app-id maximo_conn

# 5. Importer l'agent de diagnostic
orchestrate agents import -f agents/maximo_diagnostic_agent.yaml
```

## 🧪 Test de l'agent

### Via CLI

```bash
orchestrate agents chat --name maximo_diagnostic_agent
```

### Via l'interface web

1. Connectez-vous à votre instance watsonx Orchestrate
2. Sélectionnez l'agent "maximo_diagnostic_agent"
3. Commencez à poser vos questions

## 💬 Exemples de questions

### Interventions
```
"Quelles sont les dernières interventions sur l'asset 11430 ?"
"Montre-moi les 5 dernières interventions sur l'équipement PUMP-001"
"Quel est le statut des work orders de l'asset 11430 ?"
```

### Logs détaillés
```
"Montre-moi les logs de l'intervention WO12345"
"Quels sont les détails de la work order 1234 ?"
"Qui a travaillé sur l'intervention WO12345 ?"
```

### Documents
```
"Quels documents sont attachés à l'asset 11430 ?"
"Liste-moi les manuels de l'équipement PUMP-001"
"Y a-t-il des photos de l'asset 11430 ?"
```

### Consultation de documents
```
"Que dit le manuel d'utilisation de cet équipement ?"
"Montre-moi le contenu du document maintenance_procedure.pdf"
"Résume-moi le manuel de l'asset 11430"
```

## 🔐 Sécurité

- Les credentials Maximo sont stockés dans une connection WXO de type `key_value`
- Les credentials ne sont jamais hardcodés dans le code
- L'API key Maximo est passée via le header `apikey`
- Utilisez l'endpoint `/maximo/api` (compatible SAML/OIDC) plutôt que `/oslc`

## 📊 Architecture technique

```
┌─────────────────────────────────────────┐
│   watsonx Orchestrate Agent             │
│   (maximo_diagnostic_agent)             │
└──────────────┬──────────────────────────┘
               │
               │ Appelle les tools
               ▼
┌─────────────────────────────────────────┐
│   Python Tools (maximo_tools.py)        │
│   - get_work_orders_for_asset           │
│   - get_worklogs_for_workorder          │
│   - list_asset_attachments              │
│   - get_attachment_text                 │
└──────────────┬──────────────────────────┘
               │
               │ Utilise credentials
               ▼
┌─────────────────────────────────────────┐
│   Connection WXO (maximo_conn)          │
│   - MAXIMO_BASE_URL                     │
│   - MAXIMO_APIKEY                       │
└──────────────┬──────────────────────────┘
               │
               │ API REST
               ▼
┌─────────────────────────────────────────┐
│   IBM Maximo Application Suite          │
│   - /api/os/mxapiwodetail               │
│   - /api/os/mxapiasset                  │
└─────────────────────────────────────────┘
```

## 🛠️ Maintenance

### Mettre à jour les tools

```bash
# Après modification de maximo_tools.py
orchestrate tools import -k python -f tools/maximo_tools.py \
  -r tools/requirements.txt --app-id maximo_conn
```

### Mettre à jour l'agent

```bash
# Après modification de maximo_diagnostic_agent.yaml
orchestrate agents import -f agents/maximo_diagnostic_agent.yaml
```

### Mettre à jour les credentials

```bash
orchestrate connections set-credentials -a maximo_conn --env draft \
  --entries '{"MAXIMO_BASE_URL":"nouvelle-url","MAXIMO_APIKEY":"nouvelle-key"}'
```

## 🐛 Dépannage

### Erreur "MAXIMO_BASE_URL is not set"
- Vérifiez que la connection est bien configurée
- Vérifiez que les credentials sont définis pour l'environnement actif

### Erreur "No asset found"
- Vérifiez le numéro d'asset
- Ajoutez le paramètre `siteid` si nécessaire

### Erreur d'authentification
- Vérifiez que votre API key Maximo est valide
- Vérifiez que l'URL de base est correcte (doit se terminer par `/maximo`)

### Les tools ne sont pas disponibles
- Vérifiez que l'import des tools a réussi : `orchestrate tools list`
- Vérifiez que l'agent référence bien les tools dans sa définition

## 📝 Notes techniques

- **API Maximo** : Utilise l'endpoint `/api` (headless-friendly) plutôt que `/oslc`
- **Authentification** : API key dans le header `apikey`
- **Format de données** : JSON avec support OSLC (where, select, orderBy)
- **Extraction PDF** : Utilise la bibliothèque `pypdf` pour extraire le texte
- **Gestion des erreurs** : Toutes les requêtes utilisent `raise_for_status()`

## 📚 Ressources

- [Documentation watsonx Orchestrate ADK](https://developer.watson-orchestrate.ibm.com)
- [Documentation IBM Maximo API](https://www.ibm.com/docs/en/maximo-manage)
- [Guide OSLC](https://www.ibm.com/docs/en/maximo-manage/continuous-delivery?topic=apis-oslc-api)

## 👥 Support

Pour toute question ou problème, contactez l'équipe de développement.