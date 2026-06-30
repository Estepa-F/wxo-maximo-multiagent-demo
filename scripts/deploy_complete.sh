#!/usr/bin/env bash
# Script de déploiement complet pour watsonx Orchestrate
# Déploie toutes les connexions, outils et agents (Maximo + ServiceNow)
# Usage: ./scripts/deploy_complete.sh

set -e  # Arrêt en cas d'erreur

ORCH="${ORCH:-./bin/orchestrate}"

echo "=========================================="
echo "Déploiement complet watsonx Orchestrate"
echo "=========================================="
echo ""

# Vérifier que le CLI orchestrate existe
if [ ! -x "$ORCH" ]; then
  echo "ERROR: orchestrate CLI not found at $ORCH"
  echo "Run: make install"
  exit 1
fi

# Vérifier qu'un environnement est actif
echo "📋 Vérification de l'environnement actif..."
"$ORCH" env list | grep "(active)" || {
    echo "⚠️  Aucun environnement WXO actif"
    echo "Exécutez: orchestrate env activate <nom-environnement>"
    exit 1
}
echo "✅ Environnement WXO actif"
echo ""

# Étape 1: Déployer les connexions
echo "=========================================="
echo "📦 Étape 1/3: Déploiement des connexions"
echo "=========================================="
bash scripts/create_connections.sh
echo ""

# Étape 2: Déployer les outils
echo "=========================================="
echo "🔧 Étape 2/3: Déploiement des outils"
echo "=========================================="

# Outils Maximo
if [ -f "tools/maximo_tools.py" ]; then
  echo "Déploiement des outils Maximo..."
  "$ORCH" tools import -k python -f tools/maximo_tools.py \
    --app-id maximo_conn --requirements-file tools/requirements.txt
  echo "✅ Outils Maximo déployés"
else
  echo "⚠️  tools/maximo_tools.py non trouvé"
fi

# Outils ServiceNow
if [ -f "tools/servicenow_tools.py" ]; then
  echo "Déploiement des outils ServiceNow..."
  "$ORCH" tools import -k python -f tools/servicenow_tools.py \
    --app-id servicenow_conn --requirements-file tools/requirements.txt
  echo "✅ Outils ServiceNow déployés"
else
  echo "⚠️  tools/servicenow_tools.py non trouvé"
fi

# Outils Supabase
if [ -f "tools/supabase_tools.py" ]; then
  echo "Déploiement des outils Supabase..."
  "$ORCH" tools import -k python -f tools/supabase_tools.py \
    --app-id supabase_conn --requirements-file tools/requirements.txt
  echo "✅ Outils Supabase déployés"
else
  echo "⚠️  tools/supabase_tools.py non trouvé"
fi

# Outils Slack
if [ -f "tools/slack_tools.py" ]; then
  echo "Déploiement des outils Slack..."
  "$ORCH" tools import -k python -f tools/slack_tools.py \
    --app-id slack_conn --requirements-file tools/requirements.txt
  echo "✅ Outils Slack déployés"
else
  echo "⚠️  tools/slack_tools.py non trouvé"
fi

echo ""

# Étape 3: Déployer les agents
echo "=========================================="
echo "🤖 Étape 3/3: Déploiement des agents"
echo "=========================================="

# Agent Maximo
if [ -f "agents/maximo_agent.yaml" ]; then
  echo "Déploiement de l'agent Maximo..."
  "$ORCH" agents import -f agents/maximo_agent.yaml
  echo "✅ Agent Maximo déployé"
else
  echo "⚠️  agents/maximo_agent.yaml non trouvé"
fi

# Agent ServiceNow
if [ -f "agents/servicenow_ITSM_agent.yaml" ]; then
  echo "Déploiement de l'agent ServiceNow ITSM..."
  "$ORCH" agents import -f agents/servicenow_ITSM_agent.yaml
  echo "✅ Agent servicenow_ITSM_agent déployé"
else
  echo "⚠️  agents/servicenow_ITSM_agent.yaml non trouvé"
fi

# Agent Maximo Diagnostic
if [ -f "agents/maximo_diagnostic_agent.yaml" ]; then
  echo "Déploiement de l'agent Maximo Diagnostic..."
  "$ORCH" agents import -f agents/maximo_diagnostic_agent.yaml
  echo "✅ Agent maximo_diagnostic_agent déployé"
else
  echo "⚠️  agents/maximo_diagnostic_agent.yaml non trouvé"
fi

# Agent Maximo Planning
if [ -f "agents/maximo_planning_agent.yaml" ]; then
  echo "Déploiement de l'agent Maximo Planning..."
  "$ORCH" agents import -f agents/maximo_planning_agent.yaml
  echo "✅ Agent maximo_planning_agent déployé"
else
  echo "⚠️  agents/maximo_planning_agent.yaml non trouvé"
fi

# Agent Maximo Stock
if [ -f "agents/maximo_stock_agent.yaml" ]; then
  echo "Déploiement de l'agent Maximo Stock..."
  "$ORCH" agents import -f agents/maximo_stock_agent.yaml
  echo "✅ Agent maximo_stock_agent déployé"
else
  echo "⚠️  agents/maximo_stock_agent.yaml non trouvé"
fi

# Agent Slack Notifier
if [ -f "agents/slack_notifier_agent.yaml" ]; then
  echo "Déploiement de l'agent Slack Notifier..."
  "$ORCH" agents import -f agents/slack_notifier_agent.yaml
  echo "✅ Agent slack_notifier_agent déployé"
else
  echo "⚠️  agents/slack_notifier_agent.yaml non trouvé"
fi

# Agent Orchestrateur (déployer en dernier car il dépend des autres)
if [ -f "agents/maximo_orchestrator.yaml" ]; then
  echo "Déploiement de l'agent Orchestrateur..."
  "$ORCH" agents import -f agents/maximo_orchestrator.yaml
  echo "✅ Agent maximo_orchestrator déployé"
else
  echo "⚠️  agents/maximo_orchestrator.yaml non trouvé"
fi

echo ""
echo "=========================================="
echo "✅ Déploiement complet terminé!"
echo "=========================================="
echo ""
echo "📝 Résumé des composants déployés:"
echo ""
echo "Connexions:"
echo "  - maximo_conn (Maximo API)"
echo "  - servicenow_conn (ServiceNow OAuth)"
echo "  - supabase_conn (Supabase REST API)"
echo "  - slack_conn (Slack Webhook)"
echo ""
echo "Outils:"
echo "  - Maximo: get_workorder, get_asset, search_workorders, get_workorder_logs"
echo "  - ServiceNow: get_incident, list_open_incidents, propose_incident_update, update_incident"
echo "  - Supabase: get_spare_part, list_low_stock_parts, propose_supplier_order, create_supplier_order"
echo "  - Slack: send_simple_message, send_incident_summary"
echo ""
echo "Agents:"
echo "  - maximo_agent (Gestion Maximo)"
echo "  - servicenow_ITSM_agent (Gestion ServiceNow)"
echo "  - maximo_diagnostic_agent (Diagnostic Maximo)"
echo "  - maximo_planning_agent (Planification Maximo)"
echo "  - maximo_stock_agent (Gestion stock Supabase)"
echo "  - slack_notifier_agent (Notifications Slack)"
echo "  - maximo_orchestrator (Orchestrateur principal)"
echo ""
echo "💡 Prochaines étapes:"
echo "1. Testez les agents avec: orchestrate chat start -a <agent-name>"
echo "2. Ou via l'interface web de watsonx Orchestrate"
echo ""
echo "📋 Exemples de questions pour l'orchestrateur:"
echo ""
echo "  - J'ai reçu le ticket INC0010001, peux-tu le traiter ?"
echo "  - Analyse l'incident INC0010002 et crée un work order si nécessaire"
echo "  - Vérifie le stock de pièces pour la pompe 11430"
echo ""
echo "Pour tester individuellement:"
echo "  - maximo_agent: Quelles sont les dernières interventions sur l'asset 11430 ?"
echo "  - servicenow_ITSM_agent: Quels sont les incidents ouverts ?"
echo "  - maximo_stock_agent: Y a-t-il des pièces en rupture de stock ?"
echo "  - slack_notifier_agent: Envoie un message de test sur Slack"
echo ""

# Made with Bob
