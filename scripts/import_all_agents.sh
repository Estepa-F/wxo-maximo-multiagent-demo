#!/bin/bash

# Script to import all Maximo agents into watsonx Orchestrate
# Imports the orchestrator and its collaborator agents

set -e

echo "=========================================="
echo "Importing Maximo agents"
echo "=========================================="
echo ""

# Check that the orchestrate CLI is available
if ! command -v orchestrate &> /dev/null; then
    echo "❌ The 'orchestrate' CLI is not installed or not in the PATH"
    echo "Please install the watsonx Orchestrate SDK first"
    exit 1
fi

# Load environment variables if the file exists
if [ -f .env.sdk ]; then
    echo "📋 Loading environment variables from .env.sdk..."
    source .env.sdk
fi

echo "=========================================="
echo "Step 1: Import the diagnostic agent"
echo "=========================================="
echo ""
echo "Importing maximo_diagnostic_agent..."
orchestrate agents import --file agents/maximo_diagnostic_agent.yaml
echo "✅ Diagnostic agent imported"

echo ""
echo "=========================================="
echo "Step 2: Import the planning agent"
echo "=========================================="
echo ""
echo "Importing maximo_planning_agent..."
orchestrate agents import --file agents/maximo_planning_agent.yaml
echo "✅ Planning agent imported"

echo ""
echo "=========================================="
echo "Step 3: Import the stock agent"
echo "=========================================="
echo ""
echo "Importing maximo_stock_agent..."
orchestrate agents import --file agents/maximo_stock_agent.yaml
echo "✅ Stock agent imported"

echo ""
echo "=========================================="
echo "Step 4: Import the orchestrator"
echo "=========================================="
echo ""
echo "Importing maximo_orchestrator..."
orchestrate agents import --file agents/maximo_orchestrator.yaml
echo "✅ Orchestrator imported"

echo ""
echo "=========================================="
echo "✅ All agents have been imported!"
echo "=========================================="
echo ""
echo "Available agents:"
echo "  1. maximo_orchestrator - Main entry point"
echo "  2. maximo_diagnostic_agent - Lookup and analysis"
echo "  3. maximo_planning_agent - Creation and planning"
echo "  4. maximo_stock_agent - Stock and order management"
echo ""
echo "To test the orchestrator:"
echo "  orchestrate agents chat --name maximo_orchestrator"
echo ""
echo "To list all agents:"
echo "  orchestrate agents list"
echo ""

# Made with Bob
