# Configuration de la Connexion Maximo

Ce guide explique comment créer et configurer une connexion API Key pour votre API Maximo dans watsonx Orchestrate.

## Prérequis

- CLI watsonx Orchestrate installé et configuré
- URL de votre API Maximo
- Clé API Maximo valide

## Méthode 1 : Script Automatique (Recommandé)

Le moyen le plus simple est d'utiliser le script automatique fourni :

```bash
./scripts/configure_maximo_connection.sh
```

Le script vous demandera :
1. L'URL de votre API Maximo
2. Votre clé API Maximo

Il configurera automatiquement la connexion pour les environnements `draft` et `live`.

## Méthode 2 : Configuration Manuelle

Si vous préférez configurer manuellement, suivez ces étapes :

### Étape 1 : Mettre à jour le fichier de connexion

Éditez `connections/maximo_conn.yaml` et remplacez `YOUR_MAXIMO_URL_HERE` par votre URL Maximo :

```yaml
spec_version: v1
kind: connection
app_id: maximo_conn
environments:
  draft:
    kind: api_key
    type: team
    server_url: https://votre-maximo.example.com/api
  live:
    kind: api_key
    type: team
    server_url: https://votre-maximo.example.com/api
```

### Étape 2 : Importer la connexion

```bash
orchestrate connections import --file connections/maximo_conn.yaml
```

### Étape 3 : Configurer l'environnement draft

```bash
orchestrate connections configure \
    --app-id maximo_conn \
    --environment draft \
    --type team \
    --kind api_key \
    --server-url https://votre-maximo.example.com/api
```

### Étape 4 : Définir les credentials pour draft

```bash
orchestrate connections set-credentials \
    --app-id maximo_conn \
    --environment draft \
    --api-key VOTRE_CLE_API
```

### Étape 5 : Configurer l'environnement live

```bash
orchestrate connections configure \
    --app-id maximo_conn \
    --environment live \
    --type team \
    --kind api_key \
    --server-url https://votre-maximo.example.com/api
```

### Étape 6 : Définir les credentials pour live

```bash
orchestrate connections set-credentials \
    --app-id maximo_conn \
    --environment live \
    --api-key VOTRE_CLE_API
```

## Vérification

Pour vérifier que votre connexion est bien configurée :

```bash
orchestrate connections list
```

Vous devriez voir `maximo_conn` dans la liste avec le statut configuré pour les deux environnements.

## Utilisation avec vos outils

Une fois la connexion configurée, vous pouvez l'associer à vos outils Python :

```bash
orchestrate tools import \
    --file tools/maximo_tools.py \
    --app-id maximo_conn
```

## Types de connexion disponibles

watsonx Orchestrate supporte plusieurs types de connexions :

- **api_key** : Pour les APIs utilisant une clé API (votre cas)
- **basic** : Pour l'authentification Basic (username/password)
- **bearer** : Pour les tokens Bearer
- **oauth_auth_code_flow** : Pour OAuth 2.0 Authorization Code
- **oauth_auth_client_credentials_flow** : Pour OAuth 2.0 Client Credentials
- **key_value** : Pour des paires clé-valeur arbitraires

## Structure de la connexion API Key

Une connexion API Key contient :
- **api_key** (sécurisé) : Votre clé API
- **server_url** (non sécurisé) : L'URL de base de votre API

La clé API sera automatiquement injectée dans les headers des requêtes HTTP comme :
```
apikey: VOTRE_CLE_API
```

## Environnements

- **draft** : Pour le développement et les tests
- **live** : Pour la production

Vous pouvez avoir des URLs et des clés API différentes pour chaque environnement.

## Type de connexion : team vs member

- **team** : Les credentials sont partagés par toute l'équipe (recommandé pour les APIs de service)
- **member** : Chaque utilisateur doit fournir ses propres credentials

## Dépannage

### La connexion n'apparaît pas dans la liste

Vérifiez que vous avez bien importé le fichier :
```bash
orchestrate connections import --file connections/maximo_conn.yaml
```

### Erreur lors de la configuration

Assurez-vous que :
- Le CLI orchestrate est bien installé
- Vous êtes authentifié auprès de watsonx Orchestrate
- L'URL de votre API est correcte et accessible

### Tester la connexion

Vous pouvez tester la connexion en important un outil qui l'utilise :
```bash
orchestrate tools import --file tools/maximo_tools.py --app-id maximo_conn
```

## Commandes utiles

```bash
# Lister toutes les connexions
orchestrate connections list

# Voir les détails d'une connexion
orchestrate connections list --verbose

# Supprimer une connexion
orchestrate connections remove --app-id maximo_conn

# Exporter une connexion
orchestrate connections export --app-id maximo_conn --output-path backup.yaml
```

## Sécurité

⚠️ **Important** :
- Ne commitez JAMAIS vos clés API dans Git
- Les credentials sont stockés de manière sécurisée par watsonx Orchestrate
- Utilisez des clés API différentes pour draft et live si possible
- Renouvelez régulièrement vos clés API

## Ressources

- [Documentation officielle des connexions](https://developer.watson-orchestrate.ibm.com/connections/overview)
- [Guide des connexions API Key](https://developer.watson-orchestrate.ibm.com/connections/associate_connection_to_tool/openapi_connections)