#!/bin/bash

# Script pour configurer la connexion Supabase dans watsonx Orchestrate

set -e

echo "=========================================="
echo "Configuration de la connexion Supabase"
echo "=========================================="
echo ""

# Vérifier que le CLI orchestrate est disponible
if ! command -v orchestrate &> /dev/null; then
    echo "❌ Le CLI 'orchestrate' n'est pas installé ou n'est pas dans le PATH"
    echo "Veuillez installer le SDK watsonx Orchestrate d'abord"
    exit 1
fi

# Charger les variables d'environnement si le fichier existe
if [ -f .env.sdk ]; then
    echo "📋 Chargement des variables d'environnement depuis .env.sdk..."
    source .env.sdk
fi

# Variables
APP_ID="supabase_conn"
CONNECTION_FILE="connections/supabase_conn.yaml"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_KEY="${SUPABASE_KEY:-}"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ]; then
    echo "❌ Variables Supabase manquantes"
    echo "Veuillez définir SUPABASE_URL et SUPABASE_KEY dans .env.sdk"
    exit 1
fi

echo "📝 Configuration Supabase :"
echo "   URL : $SUPABASE_URL"
echo "   KEY : ${SUPABASE_KEY:0:20}..."
echo ""

echo "=========================================="
echo "Étape 1: Import de la connexion"
echo "=========================================="

# Importer la connexion
orchestrate connections import --file "$CONNECTION_FILE"
echo "✅ Connexion importée"

echo ""
echo "=========================================="
echo "Étape 2: Configuration de l'environnement DRAFT"
echo "=========================================="

# Configurer l'environnement draft
orchestrate connections configure \
    --app-id "$APP_ID" \
    --environment draft \
    --type team \
    --kind api_key \
    --server-url "$SUPABASE_URL"

echo "✅ Environnement draft configuré"

echo ""
echo "=========================================="
echo "Étape 3: Définition des credentials DRAFT"
echo "=========================================="

# Définir les credentials pour draft
orchestrate connections set-credentials \
    --app-id "$APP_ID" \
    --environment draft \
    --api-key "$SUPABASE_KEY"

echo "✅ Credentials draft définis"

echo ""
echo "=========================================="
echo "Étape 4: Configuration de l'environnement LIVE"
echo "=========================================="

# Configurer l'environnement live
orchestrate connections configure \
    --app-id "$APP_ID" \
    --environment live \
    --type team \
    --kind api_key \
    --server-url "$SUPABASE_URL"

echo "✅ Environnement live configuré"

echo ""
echo "=========================================="
echo "Étape 5: Définition des credentials LIVE"
echo "=========================================="

# Définir les credentials pour live
orchestrate connections set-credentials \
    --app-id "$APP_ID" \
    --environment live \
    --api-key "$SUPABASE_KEY"

echo "✅ Credentials live définis"

echo ""
echo "=========================================="
echo "✅ Configuration terminée avec succès !"
echo "=========================================="
echo ""
echo "Votre connexion Supabase est maintenant configurée et prête à être utilisée."
echo "App ID: $APP_ID"
echo "URL: $SUPABASE_URL"
echo ""
echo "Pour vérifier la connexion, utilisez :"
echo "  orchestrate connections list"
echo ""
echo "Pour utiliser cette connexion avec vos outils :"
echo "  orchestrate tools import --file tools/supabase_tools.py --app-id $APP_ID"
echo ""

# Made with Bob
