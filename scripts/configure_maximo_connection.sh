#!/bin/bash

# Script pour configurer la connexion Maximo dans watsonx Orchestrate
# Ce script vous aide à créer et configurer la connexion avec votre clé API

set -e

echo "=========================================="
echo "Configuration de la connexion Maximo"
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
APP_ID="maximo_conn"
CONNECTION_FILE="connections/maximo_conn.yaml"

echo "📝 Informations requises :"
echo "   - URL de votre API Maximo"
echo "   - Clé API Maximo"
echo ""

# Demander l'URL Maximo
read -p "Entrez l'URL de votre API Maximo (ex: https://maximo.example.com/api): " MAXIMO_URL

if [ -z "$MAXIMO_URL" ]; then
    echo "❌ L'URL est requise"
    exit 1
fi

# Demander la clé API
read -sp "Entrez votre clé API Maximo: " MAXIMO_API_KEY
echo ""

if [ -z "$MAXIMO_API_KEY" ]; then
    echo "❌ La clé API est requise"
    exit 1
fi

echo ""
echo "=========================================="
echo "Étape 1: Mise à jour du fichier de connexion"
echo "=========================================="

# Mettre à jour le fichier YAML avec l'URL
sed -i.bak "s|server_url: YOUR_MAXIMO_URL_HERE|server_url: $MAXIMO_URL|g" "$CONNECTION_FILE"
echo "✅ Fichier de connexion mis à jour avec l'URL"

echo ""
echo "=========================================="
echo "Étape 2: Import de la connexion"
echo "=========================================="

# Importer la connexion
orchestrate connections import --file "$CONNECTION_FILE"
echo "✅ Connexion importée"

echo ""
echo "=========================================="
echo "Étape 3: Configuration de l'environnement DRAFT"
echo "=========================================="

# Configurer l'environnement draft
orchestrate connections configure \
    --app-id "$APP_ID" \
    --environment draft \
    --type team \
    --kind api_key \
    --server-url "$MAXIMO_URL"

echo "✅ Environnement draft configuré"

echo ""
echo "=========================================="
echo "Étape 4: Définition des credentials DRAFT"
echo "=========================================="

# Définir les credentials pour draft
orchestrate connections set-credentials \
    --app-id "$APP_ID" \
    --environment draft \
    --api-key "$MAXIMO_API_KEY"

echo "✅ Credentials draft définis"

echo ""
echo "=========================================="
echo "Étape 5: Configuration de l'environnement LIVE"
echo "=========================================="

# Configurer l'environnement live
orchestrate connections configure \
    --app-id "$APP_ID" \
    --environment live \
    --type team \
    --kind api_key \
    --server-url "$MAXIMO_URL"

echo "✅ Environnement live configuré"

echo ""
echo "=========================================="
echo "Étape 6: Définition des credentials LIVE"
echo "=========================================="

# Définir les credentials pour live
orchestrate connections set-credentials \
    --app-id "$APP_ID" \
    --environment live \
    --api-key "$MAXIMO_API_KEY"

echo "✅ Credentials live définis"

echo ""
echo "=========================================="
echo "✅ Configuration terminée avec succès !"
echo "=========================================="
echo ""
echo "Votre connexion Maximo est maintenant configurée et prête à être utilisée."
echo "App ID: $APP_ID"
echo "URL: $MAXIMO_URL"
echo ""
echo "Pour vérifier la connexion, utilisez :"
echo "  orchestrate connections list"
echo ""
echo "Pour tester avec vos outils :"
echo "  orchestrate tools import --file tools/maximo_tools.py --app-id $APP_ID"
echo ""

# Made with Bob
