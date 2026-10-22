#!/bin/bash

# Script to configure the Maximo connection in watsonx Orchestrate
# This script helps you create and configure the connection with your API key

set -e

echo "=========================================="
echo "Maximo connection configuration"
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
CONNECTION_FILE="connections/maximo_conn.yaml"

echo "📝 Required information:"
echo "   - Your Maximo API URL"
echo "   - Maximo API key"
echo ""

# Ask for the Maximo URL
read -p "Enter your Maximo API URL (e.g. https://maximo.example.com/api): " MAXIMO_URL

if [ -z "$MAXIMO_URL" ]; then
    echo "❌ The URL is required"
    exit 1
fi

# Ask for the API key
read -sp "Enter your Maximo API key: " MAXIMO_API_KEY
echo ""

if [ -z "$MAXIMO_API_KEY" ]; then
    echo "❌ The API key is required"
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 1: Updating the connection file"
echo "=========================================="

# Update the YAML file with the URL
sed -i.bak "s|server_url: YOUR_MAXIMO_URL_HERE|server_url: $MAXIMO_URL|g" "$CONNECTION_FILE"
echo "✅ Connection file updated with the URL"

echo ""
echo "=========================================="
echo "Step 2: Importing the connection"
echo "=========================================="

# Import the connection
orchestrate connections import --file "$CONNECTION_FILE"
echo "✅ Connection imported"

echo ""
echo "=========================================="
echo "Step 3: Configuring the DRAFT environment"
echo "=========================================="

# Configure the draft environment
orchestrate connections configure \
    --app-id "$APP_ID" \
    --environment draft \
    --type team \
    --kind api_key \
    --server-url "$MAXIMO_URL"

echo "✅ Draft environment configured"

echo ""
echo "=========================================="
echo "Step 4: Setting DRAFT credentials"
echo "=========================================="

# Set the credentials for draft
orchestrate connections set-credentials \
    --app-id "$APP_ID" \
    --environment draft \
    --api-key "$MAXIMO_API_KEY"

echo "✅ Draft credentials set"

echo ""
echo "=========================================="
echo "Step 5: Configuring the LIVE environment"
echo "=========================================="

# Configure the live environment
orchestrate connections configure \
    --app-id "$APP_ID" \
    --environment live \
    --type team \
    --kind api_key \
    --server-url "$MAXIMO_URL"

echo "✅ Live environment configured"

echo ""
echo "=========================================="
echo "Step 6: Setting LIVE credentials"
echo "=========================================="

# Set the credentials for live
orchestrate connections set-credentials \
    --app-id "$APP_ID" \
    --environment live \
    --api-key "$MAXIMO_API_KEY"

echo "✅ Live credentials set"

echo ""
echo "=========================================="
echo "✅ Configuration finished successfully!"
echo "=========================================="
echo ""
echo "Your Maximo connection is now configured and ready to use."
echo "App ID: $APP_ID"
echo "URL: $MAXIMO_URL"
echo ""
echo "To check the connection, use:"
echo "  orchestrate connections list"
echo ""
echo "To test with your tools:"
echo "  orchestrate tools import --file tools/maximo_tools.py --app-id $APP_ID"
echo ""

# Made with Bob
