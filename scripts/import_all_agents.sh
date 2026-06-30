#!/bin/bash

# Script pour importer tous les agents Maximo dans watsonx Orchestrate
# Importe l'orchestrateur et ses agents collaborateurs

set -e

echo "=========================================="
echo "Import des agents Maximo"
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

echo "=========================================="
echo "Étape 1: Import de l'agent de diagnostic"
echo "=========================================="
echo ""
echo "Import de maximo_diagnostic_agent..."
orchestrate agents import --file agents/maximo_diagnostic_agent.yaml
echo "✅ Agent de diagnostic importé"

echo ""
echo "=========================================="
echo "Étape 2: Import de l'agent de planification"
echo "=========================================="
echo ""
echo "Import de maximo_planning_agent..."
orchestrate agents import --file agents/maximo_planning_agent.yaml
echo "✅ Agent de planification importé"

echo ""
echo "=========================================="
echo "Étape 3: Import de l'agent de stock"
echo "=========================================="
echo ""
echo "Import de maximo_stock_agent..."
orchestrate agents import --file agents/maximo_stock_agent.yaml
echo "✅ Agent de stock importé"

echo ""
echo "=========================================="
echo "Étape 4: Import de l'orchestrateur"
echo "=========================================="
echo ""
echo "Import de maximo_orchestrator..."
orchestrate agents import --file agents/maximo_orchestrator.yaml
echo "✅ Orchestrateur importé"

echo ""
echo "=========================================="
echo "✅ Tous les agents ont été importés !"
echo "=========================================="
echo ""
echo "Agents disponibles :"
echo "  1. maximo_orchestrator - Point d'entrée principal"
echo "  2. maximo_diagnostic_agent - Consultation et analyse"
echo "  3. maximo_planning_agent - Création et planification"
echo "  4. maximo_stock_agent - Gestion du stock et commandes"
echo ""
echo "Pour tester l'orchestrateur :"
echo "  orchestrate agents chat --name maximo_orchestrator"
echo ""
echo "Pour lister tous les agents :"
echo "  orchestrate agents list"
echo ""

# Made with Bob
