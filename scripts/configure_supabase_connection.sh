#!/bin/bash

# Script to configure the Supabase connection in watsonx Orchestrate

set -e

echo "=========================================="
echo "Supabase connection configuration"
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
APP_ID="supabase_conn"
CONNECTION_FILE="connections/supabase_conn.yaml"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_KEY="${SUPABASE_KEY:-}"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ]; then
    echo "❌ Missing Supabase variables"
    echo "Please set SUPABASE_URL and SUPABASE_KEY in .env.sdk"
    exit 1
fi

echo "📝 Supabase configuration:"
echo "   URL : $SUPABASE_URL"
echo "   KEY : ${SUPABASE_KEY:0:20}..."
echo ""

echo "=========================================="
echo "Step 1: Importing the connection"
echo "=========================================="

# Import the connection
orchestrate connections import --file "$CONNECTION_FILE"
echo "✅ Connection imported"

echo ""
echo "=========================================="
echo "Step 2: Configuring the DRAFT environment"
echo "=========================================="

# Configure the draft environment
orchestrate connections configure \
    --app-id "$APP_ID" \
    --environment draft \
    --type team \
    --kind api_key \
    --server-url "$SUPABASE_URL"

echo "✅ Draft environment configured"

echo ""
echo "=========================================="
echo "Step 3: Setting DRAFT credentials"
echo "=========================================="

# Set the credentials for draft
orchestrate connections set-credentials \
    --app-id "$APP_ID" \
    --environment draft \
    --api-key "$SUPABASE_KEY"

echo "✅ Draft credentials set"

echo ""
echo "=========================================="
echo "Step 4: Configuring the LIVE environment"
echo "=========================================="

# Configure the live environment
orchestrate connections configure \
    --app-id "$APP_ID" \
    --environment live \
    --type team \
    --kind api_key \
    --server-url "$SUPABASE_URL"

echo "✅ Live environment configured"

echo ""
echo "=========================================="
echo "Step 5: Setting LIVE credentials"
echo "=========================================="

# Set the credentials for live
orchestrate connections set-credentials \
    --app-id "$APP_ID" \
    --environment live \
    --api-key "$SUPABASE_KEY"

echo "✅ Live credentials set"

echo ""
echo "=========================================="
echo "✅ Configuration finished successfully!"
echo "=========================================="
echo ""
echo "Your Supabase connection is now configured and ready to use."
echo "App ID: $APP_ID"
echo "URL: $SUPABASE_URL"
echo ""
echo "To check the connection, use:"
echo "  orchestrate connections list"
echo ""
echo "To use this connection with your tools:"
echo "  orchestrate tools import --file tools/supabase_tools.py --app-id $APP_ID"
echo ""

# Made with Bob
