#!/bin/bash

# Script to re-import the Maximo tools with the API Key connection
# This script removes the old tools and re-imports them with the right connection

set -e

echo "=========================================="
echo "Re-importing Maximo tools"
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

# Variables
APP_ID="maximo_conn"
TOOLS_FILE="tools/maximo_tools.py"
REQUIREMENTS_FILE="tools/requirements.txt"

echo "=========================================="
echo "Step 1: Checking the connection"
echo "=========================================="

# Check that the connection exists
if ! orchestrate connections list | grep -q "$APP_ID"; then
    echo "❌ The connection '$APP_ID' does not exist"
    echo "Please configure the connection first with:"
    echo "  ./scripts/configure_maximo_connection.sh"
    exit 1
fi

echo "✅ Connection '$APP_ID' found"

echo ""
echo "=========================================="
echo "Step 2: Listing existing tools"
echo "=========================================="

# List existing Maximo tools
echo "Searching for existing Maximo tools..."
EXISTING_TOOLS=$(orchestrate tools list --format json 2>/dev/null | jq -r '.[] | select(.name | test("maximo"; "i")) | .name' || true)

if [ -n "$EXISTING_TOOLS" ]; then
    echo "Maximo tools found:"
    echo "$EXISTING_TOOLS"
    echo ""
    read -p "Do you want to remove these tools before re-importing them? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "=========================================="
        echo "Step 3: Removing old tools"
        echo "=========================================="

        while IFS= read -r tool_name; do
            if [ -n "$tool_name" ]; then
                echo "Removing tool: $tool_name"
                orchestrate tools remove --name "$tool_name" || echo "⚠️  Unable to remove $tool_name"
            fi
        done <<< "$EXISTING_TOOLS"

        echo "✅ Old tools removed"
    else
        echo "⏭️  Keeping existing tools (they will be updated)"
    fi
else
    echo "No existing Maximo tools found"
fi

echo ""
echo "=========================================="
echo "Step 4: Importing tools with the connection"
echo "=========================================="

# Import the tools with the connection
echo "Importing tools from $TOOLS_FILE..."
orchestrate tools import \
    --kind python \
    --file "$TOOLS_FILE" \
    --requirements-file "$REQUIREMENTS_FILE" \
    --app-id "$APP_ID"

echo "✅ Tools imported successfully"

echo ""
echo "=========================================="
echo "Step 5: Verifying imported tools"
echo "=========================================="

# List the new tools
echo "Available Maximo tools:"
orchestrate tools list | grep -i "maximo" || echo "No tools found (check the logs above)"

echo ""
echo "=========================================="
echo "✅ Re-import finished successfully!"
echo "=========================================="
echo ""
echo "The following tools should now be available:"
echo "  - get_work_orders_for_asset"
echo "  - get_worklogs_for_workorder"
echo "  - list_asset_attachments"
echo "  - get_attachment_text"
echo ""
echo "These tools now use the connection '$APP_ID' (type: api_key)"
echo ""
echo "To test a tool, you can use:"
echo "  orchestrate tools test --name get_work_orders_for_asset"
echo ""

# Made with Bob
