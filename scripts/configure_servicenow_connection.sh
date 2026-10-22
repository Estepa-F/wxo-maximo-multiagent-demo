#!/bin/bash

# Script to configure the ServiceNow connection in watsonx Orchestrate
# This script helps you create and configure the OAuth 2.0 connection

set -e

echo "=========================================="
echo "ServiceNow connection configuration"
echo "=========================================="
echo ""

# Set the path to orchestrate
ORCHESTRATE="${ORCHESTRATE:-./bin/orchestrate}"

# Check that the orchestrate CLI is available
if [ ! -x "$ORCHESTRATE" ]; then
    echo "❌ The 'orchestrate' CLI was not found at $ORCHESTRATE"
    echo "Make sure the virtual environment is set up"
    exit 1
fi

# Load environment variables if the file exists
if [ -f .env.sdk ]; then
    echo "📋 Loading environment variables from .env.sdk..."
    source .env.sdk
fi

# Variables
APP_ID="servicenow_conn"
CONNECTION_FILE="connections/servicenow_conn.yaml"

echo "📝 Required information for ServiceNow OAuth 2.0:"
echo "   - Your ServiceNow instance URL (e.g. https://dev123456.service-now.com)"
echo "   - Username (service account)"
echo "   - Password (account password)"
echo "   - Client ID (OAuth application registry)"
echo "   - Client Secret (OAuth application registry)"
echo ""

# Ask for the ServiceNow URL
if [ -z "$SN_INSTANCE_URL" ]; then
    read -p "Enter your ServiceNow instance URL: " SN_INSTANCE_URL
fi

if [ -z "$SN_INSTANCE_URL" ]; then
    echo "❌ The URL is required"
    exit 1
fi

# Ask for the username
if [ -z "$SN_USERNAME" ]; then
    read -p "Enter the ServiceNow username: " SN_USERNAME
fi

if [ -z "$SN_USERNAME" ]; then
    echo "❌ The username is required"
    exit 1
fi

# Ask for the password
if [ -z "$SN_PASSWORD" ]; then
    read -sp "Enter the ServiceNow password: " SN_PASSWORD
    echo ""
fi

if [ -z "$SN_PASSWORD" ]; then
    echo "❌ The password is required"
    exit 1
fi

# Ask for the client ID
if [ -z "$SN_CLIENT_ID" ]; then
    read -p "Enter the OAuth Client ID: " SN_CLIENT_ID
fi

if [ -z "$SN_CLIENT_ID" ]; then
    echo "❌ The Client ID is required"
    exit 1
fi

# Ask for the client secret
if [ -z "$SN_CLIENT_SECRET" ]; then
    read -sp "Enter the OAuth Client Secret: " SN_CLIENT_SECRET
    echo ""
fi

if [ -z "$SN_CLIENT_SECRET" ]; then
    echo "❌ The Client Secret is required"
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 1: Importing the connection"
echo "=========================================="

# Import the connection
"$ORCHESTRATE" connections import --file "$CONNECTION_FILE"
echo "✅ Connection imported"

echo ""
echo "=========================================="
echo "Step 2: Configuring the DRAFT environment"
echo "=========================================="

# Configure the draft environment with OAuth 2.0 Password Grant
"$ORCHESTRATE" connections configure \
    --app-id "$APP_ID" \
    --environment draft \
    --type team \
    --kind oauth_auth_password_flow \
    --server-url "${SN_INSTANCE_URL}"

echo "✅ Draft environment configured"

echo ""
echo "=========================================="
echo "Step 3: Setting DRAFT credentials"
echo "=========================================="

# Set the credentials for draft (OAuth 2.0 Password Grant)
"$ORCHESTRATE" connections set-credentials \
    --app-id "$APP_ID" \
    --environment draft \
    --username "$SN_USERNAME" \
    --password "$SN_PASSWORD" \
    --client-id "$SN_CLIENT_ID" \
    --client-secret "$SN_CLIENT_SECRET" \
    --token-url "${SN_INSTANCE_URL}/oauth_token.do"

echo "✅ Draft credentials set"

echo ""
echo "=========================================="
echo "Step 4: Configuring the LIVE environment"
echo "=========================================="

# Configure the live environment
"$ORCHESTRATE" connections configure \
    --app-id "$APP_ID" \
    --environment live \
    --type team \
    --kind oauth_auth_password_flow \
    --server-url "${SN_INSTANCE_URL}"

echo "✅ Live environment configured"

echo ""
echo "=========================================="
echo "Step 5: Setting LIVE credentials"
echo "=========================================="

# Set the credentials for live
"$ORCHESTRATE" connections set-credentials \
    --app-id "$APP_ID" \
    --environment live \
    --username "$SN_USERNAME" \
    --password "$SN_PASSWORD" \
    --client-id "$SN_CLIENT_ID" \
    --client-secret "$SN_CLIENT_SECRET" \
    --token-url "${SN_INSTANCE_URL}/oauth_token.do"

echo "✅ Live credentials set"

echo ""
echo "=========================================="
echo "✅ Configuration finished successfully!"
echo "=========================================="
echo ""
echo "Your ServiceNow connection is now configured and ready to use."
echo "App ID: $APP_ID"
echo "Instance: $SN_INSTANCE_URL"
echo "Auth: OAuth 2.0 Password Grant"
echo ""
echo "To check the connection, use:"
echo "  $ORCHESTRATE connections list"
echo ""
echo "To test with your tools:"
echo "  orchestrate tools import --file tools/servicenow_tools.py --app-id $APP_ID"
echo ""

# Made with Bob