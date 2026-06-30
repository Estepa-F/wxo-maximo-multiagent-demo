# Guide de Réimportation des Outils Maximo

Ce guide explique comment réimporter vos outils Python Maximo après avoir configuré la connexion API Key.

## Changements Effectués

Les outils Maximo ont été mis à jour pour utiliser une connexion de type `api_key` au lieu de `key_value` :

### Avant (key_value)
```python
conn = connections.key_value(MAXIMO_APP_ID)
url = conn.entries.get("MAXIMO_BASE_URL")
apikey = conn.entries.get("MAXIMO_APIKEY")
```

### Après (api_key)
```python
conn = connections.api_key(MAXIMO_APP_ID)
url = conn.server_url
apikey = conn.api_key
```

## Prérequis

1. La connexion `maximo_conn` doit être configurée (voir [`README_CONNECTION.md`](README_CONNECTION.md:1))
2. Vos credentials Maximo (URL et clé API) doivent être définis dans la connexion

## Méthode 1 : Script Automatique (Recommandé)

Utilisez le script automatique qui gère tout le processus :

```bash
./scripts/reimport_maximo_tools.sh
```

Le script va :
1. Vérifier que la connexion existe
2. Lister les outils Maximo existants
3. Vous demander si vous voulez supprimer les anciens outils
4. Importer les nouveaux outils avec la connexion `api_key`
5. Vérifier que les outils sont bien importés

## Méthode 2 : Commandes Manuelles

### Étape 1 : Supprimer les anciens outils (optionnel)

Si vous avez déjà importé les outils avec l'ancienne configuration :

```bash
# Lister les outils existants
orchestrate tools list | grep -i maximo

# Supprimer chaque outil
orchestrate tools remove --name get_work_orders_for_asset
orchestrate tools remove --name get_worklogs_for_workorder
orchestrate tools remove --name list_asset_attachments
orchestrate tools remove --name get_attachment_text
```

### Étape 2 : Importer les nouveaux outils

```bash
orchestrate tools import \
    --kind python \
    --file tools/maximo_tools.py \
    --requirements-file tools/requirements.txt \
    --app-id maximo_conn
```

### Étape 3 : Vérifier l'import

```bash
orchestrate tools list | grep -i maximo
```

Vous devriez voir les 4 outils :
- `get_work_orders_for_asset`
- `get_worklogs_for_workorder`
- `list_asset_attachments`
- `get_attachment_text`

## Outils Disponibles

### 1. get_work_orders_for_asset
Récupère les ordres de travail (interventions) pour un asset donné.

**Paramètres :**
- `assetnum` (requis) : Numéro de l'asset (ex: "11430")
- `siteid` (optionnel) : ID du site Maximo
- `limit` (optionnel) : Nombre max de résultats (défaut: 10)

**Exemple :**
```python
get_work_orders_for_asset(assetnum="11430", limit=5)
```

### 2. get_worklogs_for_workorder
Lit les entrées de worklog (notes d'intervention) d'un ordre de travail.

**Paramètres :**
- `wonum` (requis) : Numéro de l'ordre de travail
- `siteid` (optionnel) : ID du site Maximo

**Exemple :**
```python
get_worklogs_for_workorder(wonum="1234")
```

### 3. list_asset_attachments
Liste les documents attachés à un asset (manuels, photos, procédures).

**Paramètres :**
- `assetnum` (requis) : Numéro de l'asset
- `siteid` (optionnel) : ID du site Maximo

**Exemple :**
```python
list_asset_attachments(assetnum="11430")
```

### 4. get_attachment_text
Récupère le contenu textuel d'une pièce jointe pour répondre à des questions.

**Paramètres :**
- `assetnum` (requis) : Numéro de l'asset
- `attachment_id` (requis) : ID de la pièce jointe (obtenu via `list_asset_attachments`)
- `siteid` (optionnel) : ID du site Maximo
- `max_chars` (optionnel) : Nombre max de caractères (défaut: 20000)

**Exemple :**
```python
get_attachment_text(assetnum="11430", attachment_id="12345")
```

## Test des Outils

Pour tester un outil individuellement :

```bash
orchestrate tools test --name get_work_orders_for_asset
```

Le CLI vous demandera les paramètres requis et exécutera l'outil.

## Utilisation avec un Agent

Une fois les outils importés, vous pouvez les associer à votre agent Maximo :

```yaml
# agents/maximo_diagnostic_agent.yaml
spec_version: v1
name: maximo_diagnostic_agent
description: Agent de consultation Maximo
kind: native
llm: groq/openai/gpt-oss-120b
tools:
  - get_work_orders_for_asset
  - get_worklogs_for_workorder
  - list_asset_attachments
  - get_attachment_text
```

Puis importez l'agent :

```bash
orchestrate agents import --file agents/maximo_diagnostic_agent.yaml
```

## Dépannage

### Erreur : "Connection not found"

La connexion `maximo_conn` n'est pas configurée. Exécutez d'abord :
```bash
./scripts/configure_maximo_connection.sh
```

### Erreur : "api_key is not set in connection"

Les credentials ne sont pas définis dans la connexion. Vérifiez avec :
```bash
orchestrate connections list --verbose
```

Puis reconfigurez si nécessaire :
```bash
orchestrate connections set-credentials \
    --app-id maximo_conn \
    --environment draft \
    --api-key VOTRE_CLE_API
```

### Erreur d'import : "Module not found"

Les dépendances Python ne sont pas installées. Vérifiez que [`tools/requirements.txt`](tools/requirements.txt:1) contient :
```
requests
pydantic
pypdf
```

### Les outils n'apparaissent pas

Vérifiez les logs d'import pour voir s'il y a des erreurs :
```bash
orchestrate tools import \
    --kind python \
    --file tools/maximo_tools.py \
    --requirements-file tools/requirements.txt \
    --app-id maximo_conn \
    --verbose
```

## Différences entre key_value et api_key

| Aspect | key_value | api_key |
|--------|-----------|---------|
| **Usage** | Paires clé-valeur arbitraires | Authentification API standard |
| **Accès URL** | `conn.entries.get("MAXIMO_BASE_URL")` | `conn.server_url` |
| **Accès clé** | `conn.entries.get("MAXIMO_APIKEY")` | `conn.api_key` |
| **Configuration** | Flexible mais moins structuré | Structuré et standardisé |
| **Injection** | Variables d'environnement | Header HTTP automatique |

## Commandes Utiles

```bash
# Lister tous les outils
orchestrate tools list

# Voir les détails d'un outil
orchestrate tools list --verbose | grep -A 20 get_work_orders_for_asset

# Supprimer un outil
orchestrate tools remove --name TOOL_NAME

# Exporter un outil
orchestrate tools export --name TOOL_NAME --output-path backup.zip

# Tester un outil
orchestrate tools test --name TOOL_NAME
```

## Prochaines Étapes

1. ✅ Configurer la connexion ([`./scripts/configure_maximo_connection.sh`](scripts/configure_maximo_connection.sh:1))
2. ✅ Réimporter les outils ([`./scripts/reimport_maximo_tools.sh`](scripts/reimport_maximo_tools.sh:1))
3. 📝 Importer l'agent (`orchestrate agents import --file agents/maximo_diagnostic_agent.yaml`)
4. 🧪 Tester l'agent (`orchestrate agents chat --name maximo_diagnostic_agent`)

## Ressources

- [Documentation des outils Python](https://developer.watson-orchestrate.ibm.com/tools/create_python_tool)
- [Documentation des connexions](https://developer.watson-orchestrate.ibm.com/connections/overview)
- [Guide de configuration de la connexion](README_CONNECTION.md)