# Configuration de la Connexion Supabase

Ce guide explique comment configurer une connexion à Supabase dans watsonx Orchestrate.

## Qu'est-ce que Supabase ?

Supabase est une alternative open-source à Firebase qui fournit :
- Base de données PostgreSQL
- Authentification
- Storage de fichiers
- API REST et Realtime automatiques
- Edge Functions

## Informations de connexion

- **URL** : `https://your-project.supabase.co`
- **ANON KEY** : Clé API publique pour l'accès client, à fournir via [`.env.sdk`](.env.sdk)
- **Type de connexion** : `api_key` (la clé ANON KEY est utilisée comme API key)

## Configuration

### Méthode 1 : Script automatique (Recommandé)

```bash
./scripts/configure_supabase_connection.sh
```

Le script va :
1. Importer la connexion depuis [`connections/supabase_conn.yaml`](connections/supabase_conn.yaml:1)
2. Lire `SUPABASE_URL` et `SUPABASE_KEY` depuis [`.env.sdk`](.env.sdk)
3. Configurer les environnements `draft` et `live`
4. Définir les credentials

### Méthode 2 : Configuration manuelle

#### Étape 1 : Importer la connexion

```bash
orchestrate connections import --file connections/supabase_conn.yaml
```

#### Étape 2 : Configurer l'environnement draft

```bash
orchestrate connections configure \
    --app-id supabase_conn \
    --environment draft \
    --type team \
    --kind api_key \
    --server-url https://your-project.supabase.co
```

#### Étape 3 : Définir les credentials pour draft

```bash
orchestrate connections set-credentials \
    --app-id supabase_conn \
    --environment draft \
    --api-key "your-supabase-anon-key"
```

#### Étape 4 : Répéter pour l'environnement live

```bash
orchestrate connections configure \
    --app-id supabase_conn \
    --environment live \
    --type team \
    --kind api_key \
    --server-url https://your-project.supabase.co

orchestrate connections set-credentials \
    --app-id supabase_conn \
    --environment live \
    --api-key "your-supabase-anon-key"
```

## Vérification

```bash
orchestrate connections list | grep supabase
```

Vous devriez voir `supabase_conn` dans la liste.

## Utilisation dans les outils Python

### Structure de base d'un outil Supabase

```python
from ibm_watsonx_orchestrate.agent_builder.tools import tool
from ibm_watsonx_orchestrate.agent_builder.connections import ConnectionType
from ibm_watsonx_orchestrate.run import connections
import requests

SUPABASE_APP_ID = "supabase_conn"

def _get_connection():
    """Get Supabase connection credentials."""
    return connections.api_key_auth(SUPABASE_APP_ID)

def _base_url() -> str:
    """Get Supabase base URL."""
    conn = _get_connection()
    return conn.url.rstrip("/")

def _headers() -> dict:
    """Get HTTP headers with Supabase API key."""
    conn = _get_connection()
    return {
        "apikey": conn.api_key,
        "Authorization": f"Bearer {conn.api_key}",
        "Content-Type": "application/json",
    }

@tool(
    expected_credentials=[
        {"app_id": SUPABASE_APP_ID, "type": ConnectionType.API_KEY_AUTH}
    ]
)
def query_supabase_table(table_name: str, limit: int = 10) -> list:
    """
    Query a Supabase table using the REST API.
    
    :param table_name: Name of the table to query
    :param limit: Maximum number of rows to return
    :returns: List of rows from the table
    """
    url = f"{_base_url()}/rest/v1/{table_name}"
    params = {"limit": limit}
    
    resp = requests.get(url, headers=_headers(), params=params)
    resp.raise_for_status()
    
    return resp.json()
```

### Import d'un outil Supabase

```bash
orchestrate tools import \
    --kind python \
    --file tools/supabase_tools.py \
    --requirements-file tools/requirements.txt \
    --app-id supabase_conn
```

## API Supabase

### Endpoints disponibles

Avec l'URL de base `https://your-project.supabase.co` :

- **REST API** : `/rest/v1/{table_name}`
- **Auth** : `/auth/v1/`
- **Storage** : `/storage/v1/`
- **Realtime** : `/realtime/v1/`

### Exemples de requêtes

#### Lire des données d'une table

```bash
curl -X GET \
  "https://your-project.supabase.co/rest/v1/your_table?limit=10" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Insérer des données

```bash
curl -X POST \
  "https://your-project.supabase.co/rest/v1/your_table" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"column1": "value1", "column2": "value2"}'
```

#### Mettre à jour des données

```bash
curl -X PATCH \
  "https://your-project.supabase.co/rest/v1/your_table?id=eq.1" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"column1": "new_value"}'
```

#### Supprimer des données

```bash
curl -X DELETE \
  "https://your-project.supabase.co/rest/v1/your_table?id=eq.1" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Sécurité

### ANON KEY vs SERVICE_ROLE KEY

- **ANON KEY** (utilisée ici) : 
  - Clé publique, peut être exposée côté client
  - Respecte les Row Level Security (RLS) policies
  - Accès limité selon les règles de sécurité définies dans Supabase

- **SERVICE_ROLE KEY** (non utilisée) :
  - Clé privée, ne doit JAMAIS être exposée
  - Bypass les RLS policies
  - Accès complet à la base de données

### Row Level Security (RLS)

Assurez-vous que vos tables Supabase ont des policies RLS configurées pour :
- Contrôler qui peut lire/écrire les données
- Protéger les données sensibles
- Limiter l'accès selon les rôles utilisateurs

## Dépannage

### Erreur 401 Unauthorized

Vérifiez que :
- La clé ANON KEY est correctement configurée
- Les headers `apikey` et `Authorization` sont présents
- La clé n'a pas expiré

### Erreur 404 Not Found

Vérifiez que :
- L'URL de base est correcte
- Le nom de la table existe dans votre projet Supabase
- L'endpoint API est correct (`/rest/v1/` pour les tables)

### Erreur 403 Forbidden

Vérifiez que :
- Les policies RLS permettent l'opération demandée
- L'utilisateur a les permissions nécessaires
- La table est accessible avec la clé ANON KEY

## Ressources

- [Documentation Supabase](https://supabase.com/docs)
- [API REST Supabase](https://supabase.com/docs/guides/api)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Guide des connexions watsonx Orchestrate](docs/README_CONNECTION.md)

## Fichiers

- [`connections/supabase_conn.yaml`](connections/supabase_conn.yaml:1) - Configuration de la connexion
- [`scripts/configure_supabase_connection.sh`](scripts/configure_supabase_connection.sh:1) - Script de configuration