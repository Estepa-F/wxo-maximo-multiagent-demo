#!/usr/bin/env bash
# Full deployment script for watsonx Orchestrate
# Deploys all connections, tools and agents (Maximo + ServiceNow)
# Usage: ./scripts/deploy_complete.sh

set -e  # Stop on error

ORCH="${ORCH:-./bin/orchestrate}"

echo "=========================================="
echo "Full watsonx Orchestrate deployment"
echo "=========================================="
echo ""

# Check that the orchestrate CLI exists
if [ ! -x "$ORCH" ]; then
  echo "ERROR: orchestrate CLI not found at $ORCH"
  echo "Run: make install"
  exit 1
fi

# Check that an environment is active
echo "📋 Checking the active environment..."
"$ORCH" env list | grep "(active)" || {
    echo "⚠️  No active WXO environment"
    echo "Run: orchestrate env activate <environment-name>"
    exit 1
}
echo "✅ WXO environment active"
echo ""

# Step 1: Deploy connections
echo "=========================================="
echo "📦 Step 1/3: Deploying connections"
echo "=========================================="
bash scripts/create_connections.sh
echo ""

# Step 2: Deploy tools
echo "=========================================="
echo "🔧 Step 2/3: Deploying tools"
echo "=========================================="

# Maximo tools
if [ -f "tools/maximo_tools.py" ]; then
  echo "Deploying Maximo tools..."
  "$ORCH" tools import -k python -f tools/maximo_tools.py \
    --app-id maximo_conn --requirements-file tools/requirements.txt
  echo "✅ Maximo tools deployed"
else
  echo "⚠️  tools/maximo_tools.py not found"
fi

# ServiceNow tools
if [ -f "tools/servicenow_tools.py" ]; then
  echo "Deploying ServiceNow tools..."
  "$ORCH" tools import -k python -f tools/servicenow_tools.py \
    --app-id servicenow_conn --requirements-file tools/requirements.txt
  echo "✅ ServiceNow tools deployed"
else
  echo "⚠️  tools/servicenow_tools.py not found"
fi

# Supabase tools
if [ -f "tools/supabase_tools.py" ]; then
  echo "Deploying Supabase tools..."
  "$ORCH" tools import -k python -f tools/supabase_tools.py \
    --app-id supabase_conn --requirements-file tools/requirements.txt
  echo "✅ Supabase tools deployed"
else
  echo "⚠️  tools/supabase_tools.py not found"
fi

# Slack tools
if [ -f "tools/slack_tools.py" ]; then
  echo "Deploying Slack tools..."
  "$ORCH" tools import -k python -f tools/slack_tools.py \
    --app-id slack_conn --requirements-file tools/requirements.txt
  echo "✅ Slack tools deployed"
else
  echo "⚠️  tools/slack_tools.py not found"
fi

echo ""

# Step 3: Deploy agents
echo "=========================================="
echo "🤖 Step 3/3: Deploying agents"
echo "=========================================="

# Maximo agent
if [ -f "agents/maximo_agent.yaml" ]; then
  echo "Deploying the Maximo agent..."
  "$ORCH" agents import -f agents/maximo_agent.yaml
  echo "✅ Maximo agent deployed"
else
  echo "⚠️  agents/maximo_agent.yaml not found"
fi

# ServiceNow agent
if [ -f "agents/servicenow_ITSM_agent.yaml" ]; then
  echo "Deploying the ServiceNow ITSM agent..."
  "$ORCH" agents import -f agents/servicenow_ITSM_agent.yaml
  echo "✅ Agent servicenow_ITSM_agent deployed"
else
  echo "⚠️  agents/servicenow_ITSM_agent.yaml not found"
fi

# Maximo Diagnostic agent
if [ -f "agents/maximo_diagnostic_agent.yaml" ]; then
  echo "Deploying the Maximo Diagnostic agent..."
  "$ORCH" agents import -f agents/maximo_diagnostic_agent.yaml
  echo "✅ Agent maximo_diagnostic_agent deployed"
else
  echo "⚠️  agents/maximo_diagnostic_agent.yaml not found"
fi

# Maximo Planning agent
if [ -f "agents/maximo_planning_agent.yaml" ]; then
  echo "Deploying the Maximo Planning agent..."
  "$ORCH" agents import -f agents/maximo_planning_agent.yaml
  echo "✅ Agent maximo_planning_agent deployed"
else
  echo "⚠️  agents/maximo_planning_agent.yaml not found"
fi

# Maximo Stock agent
if [ -f "agents/maximo_stock_agent.yaml" ]; then
  echo "Deploying the Maximo Stock agent..."
  "$ORCH" agents import -f agents/maximo_stock_agent.yaml
  echo "✅ Agent maximo_stock_agent deployed"
else
  echo "⚠️  agents/maximo_stock_agent.yaml not found"
fi

# Slack Notifier agent
if [ -f "agents/slack_notifier_agent.yaml" ]; then
  echo "Deploying the Slack Notifier agent..."
  "$ORCH" agents import -f agents/slack_notifier_agent.yaml
  echo "✅ Agent slack_notifier_agent deployed"
else
  echo "⚠️  agents/slack_notifier_agent.yaml not found"
fi

# Orchestrator agent (deploy last since it depends on the others)
if [ -f "agents/maximo_orchestrator.yaml" ]; then
  echo "Deploying the Orchestrator agent..."
  "$ORCH" agents import -f agents/maximo_orchestrator.yaml
  echo "✅ Agent maximo_orchestrator deployed"
else
  echo "⚠️  agents/maximo_orchestrator.yaml not found"
fi

echo ""
echo "=========================================="
echo "✅ Full deployment finished!"
echo "=========================================="
echo ""
echo "📝 Summary of deployed components:"
echo ""
echo "Connections:"
echo "  - maximo_conn (Maximo API)"
echo "  - servicenow_conn (ServiceNow OAuth)"
echo "  - supabase_conn (Supabase REST API)"
echo "  - slack_conn (Slack Webhook)"
echo ""
echo "Tools:"
echo "  - Maximo: get_workorder, get_asset, search_workorders, get_workorder_logs"
echo "  - ServiceNow: get_incident, list_open_incidents, propose_incident_update, update_incident"
echo "  - Supabase: get_spare_part, list_low_stock_parts, propose_supplier_order, create_supplier_order"
echo "  - Slack: send_simple_message, send_incident_summary"
echo ""
echo "Agents:"
echo "  - maximo_agent (Maximo management)"
echo "  - servicenow_ITSM_agent (ServiceNow management)"
echo "  - maximo_diagnostic_agent (Maximo diagnostics)"
echo "  - maximo_planning_agent (Maximo planning)"
echo "  - maximo_stock_agent (Supabase stock management)"
echo "  - slack_notifier_agent (Slack notifications)"
echo "  - maximo_orchestrator (Main orchestrator)"
echo ""
echo "💡 Next steps:"
echo "1. Test the agents with: orchestrate chat start -a <agent-name>"
echo "2. Or through the watsonx Orchestrate web interface"
echo ""
echo "📋 Example questions for the orchestrator:"
echo ""
echo "  - I received ticket INC0010001, can you handle it?"
echo "  - Analyze incident INC0010002 and create a work order if needed"
echo "  - Check the parts stock for pump 11430"
echo ""
echo "To test individually:"
echo "  - maximo_agent: What are the latest interventions on asset 11430?"
echo "  - servicenow_ITSM_agent: What are the open incidents?"
echo "  - maximo_stock_agent: Are there any parts out of stock?"
echo "  - slack_notifier_agent: Send a test message on Slack"
echo ""

# Made with Bob
