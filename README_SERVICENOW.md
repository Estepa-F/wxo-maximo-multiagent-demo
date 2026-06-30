# Configuration ServiceNow pour watsonx Orchestrate

Ce guide explique comment configurer la connexion ServiceNow avec OAuth 2.0 dans watsonx Orchestrate.

## Prérequis

1. **Instance ServiceNow** : Vous devez avoir accès à une instance ServiceNow (ex: `https://dev123456.service-now.com`)
2. **Compte de service** : Un compte utilisateur avec les permissions nécessaires pour accéder aux incidents
3. **OAuth Application Registry** : Une application OAuth configurée dans ServiceNow

## Configuration OAuth dans ServiceNow

### 1. Créer une OAuth Application Registry

Dans votre instance ServiceNow :

1. Allez dans **System OAuth > Application Registry**
2. Cliquez sur **New** > **Create an OAuth API endpoint for external clients**
3. Configurez :
   - **Name** : `WatsonX Orchestrate Integration`
   - **Client ID** : Sera généré automatiquement (notez-le)
   - **Client Secret** : Sera généré automatiquement (notez-le)
   - **Redirect URL** : Laissez vide pour Resource Owner Password Credentials Grant
   - **Refresh Token Lifespan** : 1800 (30 minutes)
   - **Access Token Lifespan** : 1800 (30 minutes)

4. Sauvegardez et notez le **Client ID** et **Client Secret**

### 2. Configurer les permissions

Assurez-vous que votre compte de service a les rôles nécessaires :
- `itil` : Pour accéder aux incidents
- `rest_service` : Pour utiliser les APIs REST

## Configuration dans watsonx Orchestrate

### Option 1 : Via le script automatique (recommandé)

1. **Copiez le fichier d'exemple** :
   ```bash
   cp .env.sdk.exemple .env.sdk
   ```

2. **Éditez `.env.sdk`** avec vos informations ServiceNow :
   ```bash
   # ServiceNow OAuth 2.0 configuration
   SN_INSTANCE_URL=https://dev123456.service-now.com
   SN_USERNAME=votre-username
   SN_PASSWORD=votre-password
   SN_CLIENT_ID=votre-client-id
   SN_CLIENT_SECRET=votre-client-secret
   ```

3. **Exécutez le script de configuration** :
   ```bash
   ./scripts/configure_servicenow_connection.sh
   ```

Le script va :
- Importer la connexion depuis `connections/servicenow_conn.yaml`
- Configurer les environnements draft et live avec OAuth 2.0 Password Grant
- Définir les credentials pour les deux environnements

### Option 2 : Configuration manuelle via CLI

```bash
# 1. Importer la connexion
orchestrate connections import --file connections/servicenow_conn.yaml

# 2. Configurer l'environnement draft
orchestrate connections configure \
    --app-id servicenow_conn \
    --environment draft \
    --type team \
    --kind oauth_auth_password_flow \
    --token-url "https://dev123456.service-now.com/oauth_token.do"

# 3. Définir les credentials draft
orchestrate connections set-credentials \
    --app-id servicenow_conn \
    --environment draft \
    --username "votre-username" \
    --password "votre-password" \
    --client-id "votre-client-id" \
    --client-secret "votre-client-secret"

# 4. Répéter pour l'environnement live
orchestrate connections configure \
    --app-id servicenow_conn \
    --environment live \
    --type team \
    --kind oauth_auth_password_flow \
    --token-url "https://dev123456.service-now.com/oauth_token.do"

orchestrate connections set-credentials \
    --app-id servicenow_conn \
    --environment live \
    --username "votre-username" \
    --password "votre-password" \
    --client-id "votre-client-id" \
    --client-secret "votre-client-secret"
```

## Vérification

Pour vérifier que la connexion est bien configurée :

```bash
# Lister toutes les connexions
orchestrate connections list

# Vous devriez voir servicenow_conn dans la liste
```

## Import des outils ServiceNow

Une fois la connexion configurée, importez les outils :

```bash
orchestrate tools import \
    --file tools/servicenow_tools.py \
    --app-id servicenow_conn \
    --requirements-filepath tools/requirements.txt
```

## Import de l'agent ServiceNow

Importez l'agent ITSM :

```bash
orchestrate agents import --file agents/servicenow_ITSM_agent.yaml
```

## Outils disponibles

Les outils ServiceNow suivent un pattern de confirmation en 2 temps :

### Outils de lecture
- **`get_incident`** : Récupère un incident par son numéro (ex: INC0010001)
- **`list_open_incidents`** : Liste les incidents ouverts

### Outils d'écriture (avec confirmation)
- **`propose_incident_update`** : Propose une mise à jour (DRY-RUN)
- **`update_incident`** : Applique la mise à jour (après confirmation)

## Workflow typique

```python
# 1. L'utilisateur mentionne un incident
"J'ai reçu le ticket INC0010001"

# 2. L'agent récupère les détails
get_incident(number="INC0010001")

# 3. L'agent propose une mise à jour
propose_incident_update(
    number="INC0010001",
    work_notes="Diagnostic effectué via Maximo",
    new_state="résolu",
    close_notes="Problème résolu après remplacement de la pièce"
)

# 4. Après confirmation de l'utilisateur
update_incident(
    number="INC0010001",
    work_notes="Diagnostic effectué via Maximo",
    new_state="résolu",
    close_notes="Problème résolu après remplacement de la pièce"
)
```

## Mapping des états ServiceNow

| Code | Label français | Label anglais |
|------|---------------|---------------|
| 1    | Nouveau       | New           |
| 2    | En cours      | In Progress   |
| 3    | En attente    | On Hold       |
| 6    | Résolu        | Resolved      |
| 7    | Fermé         | Closed        |
| 8    | Annulé        | Cancelled     |

Les outils acceptent les codes numériques ou les labels (français ou anglais).

## Dépannage

### Erreur d'authentification OAuth

Si vous obtenez une erreur 401 :
1. Vérifiez que le Client ID et Client Secret sont corrects
2. Vérifiez que le username/password sont corrects
3. Vérifiez que l'URL de l'instance est correcte (sans `/` à la fin)
4. Vérifiez que l'application OAuth est bien configurée dans ServiceNow

### Token expiré

Les tokens OAuth expirent après 30 minutes par défaut. Le code gère automatiquement le renouvellement du token.

### Permissions insuffisantes

Si vous obtenez une erreur 403 :
1. Vérifiez que le compte de service a le rôle `itil`
2. Vérifiez que le compte de service a le rôle `rest_service`

## Sécurité

⚠️ **Important** :
- Ne commitez JAMAIS le fichier `.env.sdk` dans Git
- Utilisez des comptes de service dédiés avec permissions minimales
- Changez régulièrement les Client Secrets
- En production, utilisez `verify=True` pour les certificats SSL

## Support

Pour plus d'informations sur l'ADK watsonx Orchestrate :
- Documentation : https://developer.watson-orchestrate.ibm.com
- Exemples : https://github.com/IBM/watsonx-orchestrate-adk

---

Made with ❤️ by Bob