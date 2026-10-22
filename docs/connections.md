# Connection configuration

This guide explains how to configure the **four connections** the project needs in WatsonX Orchestrate:

1. **Maximo** — API key to IBM Maximo Application Suite
2. **ServiceNow** — OAuth 2.0 Password Grant
3. **Supabase** — API key to the inventory database (ERP)
4. **Slack** — Webhook URL for notifications

A WXO connection encapsulates the credentials and URL of an external system. It is shared by the Python tools, which authenticate through it.

## Common prerequisites

- WatsonX Orchestrate ADK installed: `pip install ibm-watsonx-orchestrate`
- `orchestrate` CLI configured and authenticated against the target environment
- `.env.sdk` file created at the project root (see below)

### `.env.sdk` file

Copy the template and fill it in with your own values:

```bash
cp .env.sdk.exemple .env.sdk
```

Typical contents:

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

⚠️ **NEVER commit this file**. It must be listed in `.gitignore`.

---

## 1. Maximo connection

### Type
`api_key` (the Maximo API key is passed in the `apikey` header).

### Creating the Maximo API key

On the Maximo instance, create an API key with no expiration:

```bash
curl -X POST "$MAXIMO_URL/oslc/apitoken/create" \
  -H "Content-Type: application/json" \
  -H "Cookie: <session cookie>" \
  -d '{"expiration": -1}'
```

The response contains `apikey`. Store it in `.env.sdk` as `MAXIMO_API_KEY`.

### Importing and configuring the connection

Recommended method (automated script):

```bash
./scripts/configure_maximo_connection.sh
```

Manual method:

```bash
# 1. Import the connection definition
orchestrate connections import -f connections/maximo_conn.yaml

# 2. Configure the draft environment
orchestrate connections configure \
  -a maximo_conn \
  --env draft \
  -t team \
  -k api_key \
  --server-url "$MAXIMO_URL"

# 3. Inject the credential
orchestrate connections set-credentials \
  -a maximo_conn \
  --env draft \
  --api-key "$MAXIMO_API_KEY"
```

Repeat steps 2 and 3 for the `live` environment if needed.

### Verification

```bash
orchestrate connections list | grep maximo_conn
```

Should show `maximo_conn` with type `api_key` and a configured status.

Direct test via cURL:

```bash
curl -k "$MAXIMO_URL/api/os/mxapiasset?lean=1&oslc.pageSize=1" \
  -H "apikey: $MAXIMO_API_KEY"
```

Should return one asset (or an empty list) and an HTTP 200 code.

---

## 2. ServiceNow connection

### Type
`oauth_auth_password_flow` (OAuth 2.0 Resource Owner Password Credentials Grant).

⚠️ **Security note**: this flow is less secure than Authorization Code, but it is the only one compatible with simple non-interactive use. In production, prefer Authorization Code with token storage, or a technical account with basic auth depending on the context.

### ServiceNow-side preparation

In the ServiceNow instance:

1. **System OAuth → Application Registry → New → Create an OAuth API endpoint for external clients**
2. Configure:
   - Name: `WatsonX Orchestrate Integration`
   - Client ID: generated automatically (write it down)
   - Client Secret: generated automatically (write it down)
   - Refresh Token Lifespan: `1800` (30 min)
   - Access Token Lifespan: `1800` (30 min)
3. Save.

Make sure the service account used has the following ServiceNow roles:
- `itil` — access to incidents
- `rest_service` — REST API authorization

### Importing and configuring the connection

Recommended method:

```bash
./scripts/configure_servicenow_connection.sh
```

Manual method:

```bash
# 1. Import the definition
orchestrate connections import -f connections/servicenow_conn.yaml

# 2. Configure
orchestrate connections configure \
  -a servicenow_conn \
  --env draft \
  -t team \
  -k oauth_auth_password_flow \
  --token-url "$SN_INSTANCE_URL/oauth_token.do"

# 3. Inject the credentials
orchestrate connections set-credentials \
  -a servicenow_conn \
  --env draft \
  --username "$SN_USERNAME" \
  --password "$SN_PASSWORD" \
  --client-id "$SN_CLIENT_ID" \
  --client-secret "$SN_CLIENT_SECRET"
```

⚠️ **If the password contains special characters** (`!`, `$`, `&`, etc.), use single quotes in zsh/bash to prevent shell interpretation: `--password '$2#bC...'`.

### Verification

Direct test via cURL to obtain a token:

```bash
curl -X POST "$SN_INSTANCE_URL/oauth_token.do" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$SN_CLIENT_ID" \
  -d "client_secret=$SN_CLIENT_SECRET" \
  -d "username=$SN_USERNAME" \
  -d "password=$SN_PASSWORD"
```

Should return a JSON payload with `access_token`.

Then check that you can list an incident:

```bash
TOKEN=...  # access_token from the previous response
curl "$SN_INSTANCE_URL/api/now/table/incident?sysparm_limit=1" \
  -H "Authorization: Bearer $TOKEN"
```

### ServiceNow state mapping

The `update_incident` tool accepts either numeric codes or labels (French/English):

| Code | French label | English label |
|------|--------------|---------------|
| 1 | Nouveau | New |
| 2 | En cours | In Progress |
| 3 | En attente | On Hold |
| 6 | Résolu | Resolved |
| 7 | Fermé | Closed |
| 8 | Annulé | Cancelled |

### Valid close codes on closure

When closing an incident (states 6 or 7), the `close_code` field is mandatory. Accepted values:

- `Solution provided` ← the one most commonly used in the demo
- `Resolved by change`
- `Resolved by caller`
- `Resolved by request`
- `Resolved by problem`
- `Workaround provided`
- `Known error`
- `User error`
- `No resolution provided`
- `Duplicate`

The `close_notes` field (not `work_notes`) is also mandatory on closure.

---

## 3. Supabase connection (inventory ERP)

Supabase provides the PostgreSQL database that hosts the spare parts catalog (`spare_parts`) and supplier orders (`supplier_orders`). It is the concrete implementation of the inventory ERP in the demo.

### Type
`api_key` (the Supabase `anon` key is passed as the API key).

### Supabase-side preparation

1. Create a Supabase project (any region, the free plan is enough)
2. From **Project Settings → API**, retrieve:
   - `Project URL` (e.g. `https://oxzfsrzgvgpuwhqhkihs.supabase.co`)
   - `anon` key (public JWT, format `eyJ...`)
3. Create the required tables (see `data/supabase_schema.sql`):

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

4. For the demo, **disable Row Level Security** on both tables (otherwise the `anon` key would not be sufficient for writes):

```sql
ALTER TABLE spare_parts DISABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_orders DISABLE ROW LEVEL SECURITY;
```

⚠️ **In production**, keep RLS enabled and use the `service_role` key (to be protected) or business-specific SQL policies.

### Importing and configuring the connection

Recommended method:

```bash
./scripts/configure_supabase_connection.sh
```

Manual method:

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

### Verification

```bash
curl "$SUPABASE_URL/rest/v1/spare_parts?select=*" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY"
```

Should return a JSON array with the spare parts.

---

## 4. Slack connection

### Type
`api_key` (the webhook URL is stored as the `api_key`).

### Slack-side preparation

1. In the Slack workspace, create an app via https://api.slack.com/apps → **Create New App**
2. **Activate Incoming Webhooks**
3. Add a webhook for the desired channel (e.g. `#maintenance-alerts`)
4. Copy the webhook URL (format `https://hooks.slack.com/services/T.../B.../...`)

### Importing and configuring the connection

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

### Verification

```bash
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test from curl"}'
```

Should return `ok` and make the message appear in the channel.

---

## Connections summary

| `app_id` | System | Type | Credentials |
|----------|--------|------|-------------|
| `maximo_conn` | IBM Maximo | `api_key` | API key in `apikey` header |
| `servicenow_conn` | ServiceNow | `oauth_auth_password_flow` | client_id + client_secret + username + password |
| `supabase_conn` | Supabase (inventory ERP) | `api_key` | `anon` JWT key |
| `slack_conn` | Slack | `api_key` | webhook URL |

Once the 4 connections are configured, move on to [installing the tools and agents](installation.md).

## Troubleshooting

### `Connection not found` when importing a tool

The connection has not been imported. Check with `orchestrate connections list` and rerun the appropriate configuration script.

### `api_key is not set in connection`

The tool is bound to a connection that has no credentials. Re-inject them with `orchestrate connections set-credentials`.

### 401 error on ServiceNow

- Check that the token has not expired (default lifetime 30 min)
- Check that the client_id / client_secret are correct
- Check that the password does not contain badly escaped characters

### 403 error on ServiceNow

The service account does not have the required roles. Add `itil` and `rest_service`.

### 404 error on Maximo

- Check that the URL ends with `/maximo` (not `/oslc`)
- Check that the referenced asset / WO exists (correct `siteid` if needed)

### Supabase returns `[]` instead of data

RLS is still enabled. Disable it on the relevant tables or create an explicit policy.
