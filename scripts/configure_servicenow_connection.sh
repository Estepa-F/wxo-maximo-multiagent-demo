#!/bin/bash

# Script pour configurer la connexion ServiceNow dans watsonx Orchestrate
# Ce script vous aide à créer et configurer la connexion OAuth 2.0

set -e

echo "=========================================="
echo "Configuration de la connexion ServiceNow"
echo "=========================================="
echo ""

# Définir le chemin vers orchestrate
ORCHESTRATE="${ORCHESTRATE:-./bin/orchestrate}"

# Vérifier que le CLI orchestrate est disponible
if [ ! -x "$ORCHESTRATE" ]; then
    echo "❌ Le CLI 'orchestrate' n'est pas trouvé à $ORCHESTRATE"
    echo "Assurez-vous que l'environnement virtuel est configuré"
    exit 1
fi

# Charger les variables d'environnement si le fichier existe
if [ -f .env.sdk ]; then
    echo "📋 Chargement des variables d'environnement depuis .env.sdk..."
    source .env.sdk
fi

# Variables
APP_ID="servicenow_conn"
CONNECTION_FILE="connections/servicenow_conn.yaml"

echo "📝 Informations requises pour ServiceNow OAuth 2.0 :"
echo "   - URL de votre instance ServiceNow (ex: https://dev123456.service-now.com)"
echo "   - Username (compte de service)"
echo "   - Password (mot de passe du compte)"
echo "   - Client ID (OAuth application registry)"
echo "   - Client Secret (OAuth application registry)"
echo ""

# Demander l'URL ServiceNow
if [ -z "$SN_INSTANCE_URL" ]; then
    read -p "Entrez l'URL de votre instance ServiceNow: " SN_INSTANCE_URL
fi

if [ -z "$SN_INSTANCE_URL" ]; then
    echo "❌ L'URL est requise"
    exit 1
fi

# Demander le username
if [ -z "$SN_USERNAME" ]; then
    read -p "Entrez le username ServiceNow: " SN_USERNAME
fi

if [ -z "$SN_USERNAME" ]; then
    echo "❌ Le username est requis"
    exit 1
fi

# Demander le password
if [ -z "$SN_PASSWORD" ]; then
    read -sp "Entrez le password ServiceNow: " SN_PASSWORD
    echo ""
fi

if [ -z "$SN_PASSWORD" ]; then
    echo "❌ Le password est requis"
    exit 1
fi

# Demander le client ID
if [ -z "$SN_CLIENT_ID" ]; then
    read -p "Entrez le Client ID OAuth: " SN_CLIENT_ID
fi

if [ -z "$SN_CLIENT_ID" ]; then
    echo "❌ Le Client ID est requis"
    exit 1
fi

# Demander le client secret
if [ -z "$SN_CLIENT_SECRET" ]; then
    read -sp "Entrez le Client Secret OAuth: " SN_CLIENT_SECRET
    echo ""
fi

if [ -z "$SN_CLIENT_SECRET" ]; then
    echo "❌ Le Client Secret est requis"
    exit 1
fi

echo ""
echo "=========================================="
echo "Étape 1: Import de la connexion"
echo "=========================================="

# Importer la connexion
"$ORCHESTRATE" connections import --file "$CONNECTION_FILE"
echo "✅ Connexion importée"

echo ""
echo "=========================================="
echo "Étape 2: Configuration de l'environnement DRAFT"
echo "=========================================="

# Configurer l'environnement draft avec OAuth 2.0 Password Grant
"$ORCHESTRATE" connections configure \
    --app-id "$APP_ID" \
    --environment draft \
    --type team \
    --kind oauth_auth_password_flow \
    --server-url "${SN_INSTANCE_URL}"

echo "✅ Environnement draft configuré"

echo ""
echo "=========================================="
echo "Étape 3: Définition des credentials DRAFT"
echo "=========================================="

# Définir les credentials pour draft (OAuth 2.0 Password Grant)
"$ORCHESTRATE" connections set-credentials \
    --app-id "$APP_ID" \
    --environment draft \
    --username "$SN_USERNAME" \
    --password "$SN_PASSWORD" \
    --client-id "$SN_CLIENT_ID" \
    --client-secret "$SN_CLIENT_SECRET" \
    --token-url "${SN_INSTANCE_URL}/oauth_token.do"

echo "✅ Credentials draft définis"

echo ""
echo "=========================================="
echo "Étape 4: Configuration de l'environnement LIVE"
echo "=========================================="

# Configurer l'environnement live
"$ORCHESTRATE" connections configure \
    --app-id "$APP_ID" \
    --environment live \
    --type team \
    --kind oauth_auth_password_flow \
    --server-url "${SN_INSTANCE_URL}"

echo "✅ Environnement live configuré"

echo ""
echo "=========================================="
echo "Étape 5: Définition des credentials LIVE"
echo "=========================================="

# Définir les credentials pour live
"$ORCHESTRATE" connections set-credentials \
    --app-id "$APP_ID" \
    --environment live \
    --username "$SN_USERNAME" \
    --password "$SN_PASSWORD" \
    --client-id "$SN_CLIENT_ID" \
    --client-secret "$SN_CLIENT_SECRET" \
    --token-url "${SN_INSTANCE_URL}/oauth_token.do"

echo "✅ Credentials live définis"

echo ""
echo "=========================================="
echo "✅ Configuration terminée avec succès !"
echo "=========================================="
echo ""
echo "Votre connexion ServiceNow est maintenant configurée et prête à être utilisée."
echo "App ID: $APP_ID"
echo "Instance: $SN_INSTANCE_URL"
echo "Auth: OAuth 2.0 Password Grant"
echo ""
echo "Pour vérifier la connexion, utilisez :"
echo "  $ORCHESTRATE connections list"
echo ""
echo "Pour tester avec vos outils :"
echo "  orchestrate tools import --file tools/servicenow_tools.py --app-id $APP_ID"
echo ""

# Made with Bob