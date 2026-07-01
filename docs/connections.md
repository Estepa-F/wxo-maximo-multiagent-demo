# Configuration des connections

Ce guide explique comment configurer les **quatre connections** nécessaires au projet dans WatsonX Orchestrate :

1. **Maximo** — API key vers IBM Maximo Application Suite
2. **ServiceNow** — OAuth 2.0 Password Grant
3. **Supabase** — API key vers la base de stock (ERP)
4. **Slack** — Webhook URL pour les notifications

Une connection WXO encapsule les credentials et l'URL d'un système externe. Elle est partagée par les tools Python qui s'authentifient grâce à elle.

## Prérequis communs

- WatsonX Orchestrate ADK installé : `pip install ibm-watsonx-orchestrate`
- CLI `orchestrate` configuré et authentifié sur l'environnement cible
- Fichier `.env.sdk` créé à la racine du projet (cf. ci-dessous)

### Fichier `.env.sdk`

Copier le template et remplir avec ses propres valeurs :

```bash
cp .env.sdk.exemple .env.sdk
```

Contenu type :

```bash
# WatsonX Orchestrate
ORCHESTRATE_API_KEY=...
ORCHESTRATE_URL=https://your-instance.watson-orchestrate.ibm.com

# Maximo
MAXIMO_URL=https://your-maximo.example.com/maximo
MAXIMO_API_KEY=...

# ServiceNow (OAuth 2.0 Password Grant)
SN_INSTANCE_URL=https://devXXXXXX.service-now.com
SN_USERNAME=admin
SN_PASSWORD=...
SN_CLIENT_ID=...
SN_CLIENT_SECRET=...

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=...

# Slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../...
```

⚠️ **Ne JAMAIS commiter ce fichier**. Il doit figurer dans `.gitignore`.

---

## 1. Connection Maximo

### Type
`api_key` (la clé API Maximo est passée dans le header `apikey`).

### Création de la clé API Maximo

Sur l'instance Maximo, créer une clé API avec expiration infinie :

```bash
curl -X POST "$MAXIMO_URL/oslc/apitoken/create" \
  -H "Content-Type: application/json" \
  -H "Cookie: <session cookie>" \
  -d '{"expiration": -1}'
```

La réponse contient `apikey`. Stocker dans `.env.sdk` comme `MAXIMO_API_KEY`.

### Import et configuration de la connection

Méthode recommandée (script automatique) :

```bash
./scripts/configure_maximo_connection.sh
```

Méthode manuelle :

```bash
# 1. Importer la définition de la connection
orchestrate connections import -f connections/maximo_conn.yaml

# 2. Configurer l'environnement draft
orchestrate connections configure \
  -a maximo_conn \
  --env draft \
  -t team \
  -k api_key \
  --server-url "$MAXIMO_URL"

# 3. Injecter le credential
orchestrate connections set-credentials \
  -a maximo_conn \
  --env draft \
  --api-key "$MAXIMO_API_KEY"
```

Répéter les étapes 2 et 3 pour l'environnement `live` si nécessaire.

### Vérification

```bash
orchestrate connections list | grep maximo_conn
```

Doit afficher `maximo_conn` avec le type `api_key` et le statut configuré.

Test direct via cURL :

```bash
curl -k "$MAXIMO_URL/api/os/mxapiasset?lean=1&oslc.pageSize=1" \
  -H "apikey: $MAXIMO_API_KEY"
```

Doit renvoyer un asset (ou une liste vide) et un code HTTP 200.

---

## 2. Connection ServiceNow

### Type
`oauth_auth_password_flow` (OAuth 2.0 Resource Owner Password Credentials Grant).

⚠️ **Note de sécurité** : ce flow est moins sécurisé que Authorization Code, mais c'est le seul compatible avec un usage non-interactif simple. En production, préférer Authorization Code avec stockage de tokens, ou un compte technique avec basic auth selon le contexte.

### Préparation côté ServiceNow

Dans l'instance ServiceNow :

1. **System OAuth → Application Registry → New → Create an OAuth API endpoint for external clients**
2. Configurer :
   - Name : `WatsonX Orchestrate Integration`
   - Client ID : généré automatiquement (à noter)
   - Client Secret : généré automatiquement (à noter)
   - Refresh Token Lifespan : `1800` (30 min)
   - Access Token Lifespan : `1800` (30 min)
3. Sauvegarder.

S'assurer que le compte de service utilisé a les rôles ServiceNow suivants :
- `itil` — accès aux incidents
- `rest_service` — autorisation API REST

### Import et configuration de la connection

Méthode recommandée :

```bash
./scripts/configure_servicenow_connection.sh
```

Méthode manuelle :

```bash
# 1. Importer la définition
orchestrate connections import -f connections/servicenow_conn.yaml

# 2. Configurer
orchestrate connections configure \
  -a servicenow_conn \
  --env draft \
  -t team \
  -k oauth_auth_password_flow \
  --token-url "$SN_INSTANCE_URL/oauth_token.do"

# 3. Injecter les credentials
orchestrate connections set-credentials \
  -a servicenow_conn \
  --env draft \
  --username "$SN_USERNAME" \
  --password "$SN_PASSWORD" \
  --client-id "$SN_CLIENT_ID" \
  --client-secret "$SN_CLIENT_SECRET"
```

⚠️ **Si le mot de passe contient des caractères spéciaux** (`!`, `$`, `&`, etc.), utiliser des guillemets simples en zsh/bash pour éviter l'interprétation par le shell : `--password '$2#bC...'`.

### Vérification

Test direct via cURL pour obtenir un token :

```bash
curl -X POST "$SN_INSTANCE_URL/oauth_token.do" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$SN_CLIENT_ID" \
  -d "client_secret=$SN_CLIENT_SECRET" \
  -d "username=$SN_USERNAME" \
  -d "password=$SN_PASSWORD"
```

Doit renvoyer un JSON avec `access_token`.

Puis vérifier qu'on peut lister un incident :

```bash
TOKEN=...  # access_token du retour précédent
curl "$SN_INSTANCE_URL/api/now/table/incident?sysparm_limit=1" \
  -H "Authorization: Bearer $TOKEN"
```

### Mapping des états ServiceNow

Le tool `update_incident` accepte les codes numériques ou les labels (français/anglais) :

| Code | Label français | Label anglais |
|------|----------------|---------------|
| 1 | Nouveau | New |
| 2 | En cours | In Progress |
| 3 | En attente | On Hold |
| 6 | Résolu | Resolved |
| 7 | Fermé | Closed |
| 8 | Annulé | Cancelled |

### Close codes valides à la clôture

À la clôture d'un incident (états 6 ou 7), le champ `close_code` est obligatoire. Valeurs acceptées :

- `Solution provided` ← le plus couramment utilisé dans la démo
- `Resolved by change`
- `Resolved by caller`
- `Resolved by request`
- `Resolved by problem`
- `Workaround provided`
- `Known error`
- `User error`
- `No resolution provided`
- `Duplicate`

Le champ `close_notes` (pas `work_notes`) est lui aussi obligatoire à la clôture.

---

## 3. Connection Supabase (ERP de stock)

Supabase fournit la base PostgreSQL qui héberge le catalogue des pièces de rechange (`spare_parts`) et les commandes fournisseurs (`supplier_orders`). C'est la matérialisation de l'ERP de stock dans la démo.

### Type
`api_key` (la clé `anon` Supabase est passée comme API key).

### Préparation côté Supabase

1. Créer un projet Supabase (région au choix, plan gratuit suffit)
2. Récupérer dans **Project Settings → API** :
   - `Project URL` (ex. `https://oxzfsrzgvgpuwhqhkihs.supabase.co`)
   - `anon` key (JWT public, format `eyJ...`)
3. Créer les tables nécessaires (cf. `data/supabase_schema.sql`) :

```sql
CREATE TABLE spare_parts (
    reference TEXT PRIMARY KEY,
    description TEXT,
    stock_qty INTEGER NOT NULL,
    min_stock INTEGER NOT NULL,
    location TEXT,
    supplier TEXT,
    unit_price NUMERIC(10,2),
    lead_time_days INTEGER,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE supplier_orders (
    id SERIAL PRIMARY KEY,
    reference TEXT NOT NULL REFERENCES spare_parts(reference),
    quantity INTEGER NOT NULL,
    supplier TEXT NOT NULL,
    unit_price NUMERIC(10,2),
    total_amount NUMERIC(10,2),
    status TEXT NOT NULL DEFAULT 'PENDING',
    related_wonum TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expected_delivery DATE
);
```

4. Pour la démo, **désactiver la Row Level Security** sur les deux tables (la clé `anon` ne suffirait sinon pas pour les écritures) :

```sql
ALTER TABLE spare_parts DISABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_orders DISABLE ROW LEVEL SECURITY;
```

⚠️ **En production**, garder RLS activé et utiliser la `service_role` key (à protéger) ou des policies SQL métier.

### Import et configuration de la connection

Méthode recommandée :

```bash
./scripts/configure_supabase_connection.sh
```

Méthode manuelle :

```bash
orchestrate connections import -f connections/supabase_conn.yaml

orchestrate connections configure \
  -a supabase_conn \
  --env draft \
  -t team \
  -k api_key \
  --server-url "$SUPABASE_URL"

orchestrate connections set-credentials \
  -a supabase_conn \
  --env draft \
  --api-key "$SUPABASE_KEY"
```

### Vérification

```bash
curl "$SUPABASE_URL/rest/v1/spare_parts?select=*" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY"
```

Doit renvoyer un tableau JSON avec les pièces de rechange.

---

## 4. Connection Slack

### Type
`api_key` (le webhook URL est stocké comme `api_key`).

### Préparation côté Slack

1. Sur le workspace Slack, créer une app via https://api.slack.com/apps → **Create New App**
2. **Activate Incoming Webhooks**
3. Ajouter un webhook pour le canal souhaité (ex. `#maintenance-alerts`)
4. Copier l'URL du webhook (format `https://hooks.slack.com/services/T.../B.../...`)

### Import et configuration de la connection

```bash
orchestrate connections import -f connections/slack_conn.yaml

orchestrate connections configure \
  -a slack_conn \
  --env draft \
  -t team \
  -k api_key

orchestrate connections set-credentials \
  -a slack_conn \
  --env draft \
  --api-key "$SLACK_WEBHOOK_URL"
```

### Vérification

```bash
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test depuis curl"}'
```

Doit renvoyer `ok` et faire apparaître le message dans le canal.

---

## Récapitulatif des connections

| `app_id` | Système | Type | Credentials |
|----------|---------|------|-------------|
| `maximo_conn` | IBM Maximo | `api_key` | API key dans header `apikey` |
| `servicenow_conn` | ServiceNow | `oauth_auth_password_flow` | client_id + client_secret + username + password |
| `supabase_conn` | Supabase (ERP stock) | `api_key` | `anon` key JWT |
| `slack_conn` | Slack | `api_key` | webhook URL |

Une fois les 4 connections configurées, passer à l'[installation des tools et des agents](installation.md).

## Dépannage

### `Connection not found` à l'import d'un tool

La connection n'a pas été importée. Vérifier avec `orchestrate connections list` et relancer le script de configuration approprié.

### `api_key is not set in connection`

Le tool est associé à une connection sans credentials. Réinjecter avec `orchestrate connections set-credentials`.

### Erreur 401 sur ServiceNow

- Vérifier que le token n'est pas expiré (durée par défaut 30 min)
- Vérifier que le client_id / client_secret sont bons
- Vérifier que le mot de passe ne contient pas de caractères mal échappés

### Erreur 403 sur ServiceNow

Le compte de service n'a pas les rôles requis. Ajouter `itil` et `rest_service`.

### Erreur 404 sur Maximo

- Vérifier que l'URL se termine par `/maximo` (pas `/oslc`)
- Vérifier que l'asset / WO mentionné existe (`siteid` correct si nécessaire)

### Supabase renvoie `[]` au lieu des données

La RLS est encore activée. Désactiver sur les tables concernées ou créer une policy explicite.
