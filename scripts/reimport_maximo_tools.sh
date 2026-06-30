#!/bin/bash

# Script pour réimporter les outils Maximo avec la connexion API Key
# Ce script supprime les anciens outils et les réimporte avec la bonne connexion

set -e

echo "=========================================="
echo "Réimportation des outils Maximo"
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
TOOLS_FILE="tools/maximo_tools.py"
REQUIREMENTS_FILE="tools/requirements.txt"

echo "=========================================="
echo "Étape 1: Vérification de la connexion"
echo "=========================================="

# Vérifier que la connexion existe
if ! orchestrate connections list | grep -q "$APP_ID"; then
    echo "❌ La connexion '$APP_ID' n'existe pas"
    echo "Veuillez d'abord configurer la connexion avec :"
    echo "  ./scripts/configure_maximo_connection.sh"
    exit 1
fi

echo "✅ Connexion '$APP_ID' trouvée"

echo ""
echo "=========================================="
echo "Étape 2: Liste des outils existants"
echo "=========================================="

# Lister les outils Maximo existants
echo "Recherche des outils Maximo existants..."
EXISTING_TOOLS=$(orchestrate tools list --format json 2>/dev/null | jq -r '.[] | select(.name | test("maximo"; "i")) | .name' || true)

if [ -n "$EXISTING_TOOLS" ]; then
    echo "Outils Maximo trouvés :"
    echo "$EXISTING_TOOLS"
    echo ""
    read -p "Voulez-vous supprimer ces outils avant de les réimporter ? (o/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        echo ""
        echo "=========================================="
        echo "Étape 3: Suppression des anciens outils"
        echo "=========================================="
        
        while IFS= read -r tool_name; do
            if [ -n "$tool_name" ]; then
                echo "Suppression de l'outil : $tool_name"
                orchestrate tools remove --name "$tool_name" || echo "⚠️  Impossible de supprimer $tool_name"
            fi
        done <<< "$EXISTING_TOOLS"
        
        echo "✅ Anciens outils supprimés"
    else
        echo "⏭️  Conservation des outils existants (ils seront mis à jour)"
    fi
else
    echo "Aucun outil Maximo existant trouvé"
fi

echo ""
echo "=========================================="
echo "Étape 4: Import des outils avec la connexion"
echo "=========================================="

# Importer les outils avec la connexion
echo "Import des outils depuis $TOOLS_FILE..."
orchestrate tools import \
    --kind python \
    --file "$TOOLS_FILE" \
    --requirements-file "$REQUIREMENTS_FILE" \
    --app-id "$APP_ID"

echo "✅ Outils importés avec succès"

echo ""
echo "=========================================="
echo "Étape 5: Vérification des outils importés"
echo "=========================================="

# Lister les nouveaux outils
echo "Outils Maximo disponibles :"
orchestrate tools list | grep -i "maximo" || echo "Aucun outil trouvé (vérifiez les logs ci-dessus)"

echo ""
echo "=========================================="
echo "✅ Réimportation terminée avec succès !"
echo "=========================================="
echo ""
echo "Les outils suivants devraient maintenant être disponibles :"
echo "  - get_work_orders_for_asset"
echo "  - get_worklogs_for_workorder"
echo "  - list_asset_attachments"
echo "  - get_attachment_text"
echo ""
echo "Ces outils utilisent maintenant la connexion '$APP_ID' (type: api_key)"
echo ""
echo "Pour tester un outil, vous pouvez utiliser :"
echo "  orchestrate tools test --name get_work_orders_for_asset"
echo ""

# Made with Bob
