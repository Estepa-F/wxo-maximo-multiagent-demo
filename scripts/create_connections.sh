#!/usr/bin/env bash
set -euo pipefail

ORCH="${ORCH:-./venv/bin/orchestrate}"

echo "== Deploy connections =="

if [ ! -x "$ORCH" ]; then
  echo "ERROR: orchestrate CLI not found at $ORCH"
  exit 1
fi

if [ -d "../connections" ]; then
  ROOT=".."
else
  ROOT="."
fi

# Import all connection YAML files
if compgen -G "$ROOT/connections/*.yaml" > /dev/null; then
  for conn in "$ROOT"/connections/*.yaml; do
    echo "Importing connection: $conn"
    "$ORCH" connections import -f "$conn"
  done
else
  echo "No connections found in connections/*.yaml"
fi

# Configure Maximo connection if it exists
if [ -f "$ROOT/connections/maximo_conn.yaml" ]; then
  echo ""
  echo "Configuring Maximo connection..."
  
  # Check if .env.sdk exists for credentials
  if [ -f "$ROOT/.env.sdk" ]; then
    source "$ROOT/.env.sdk"
    
    if [ -z "${MAXIMO_URL:-}" ] || [ -z "${MAXIMO_API_KEY:-}" ]; then
      echo "⚠️  MAXIMO_URL ou MAXIMO_API_KEY manquant dans .env.sdk"
      echo "  Configurez ces variables puis relancez le script"
    else
      # Configure for both draft and live environments
      for env in draft live; do
        "$ORCH" connections configure -a maximo_conn --env $env -t team -k api_key --url "${MAXIMO_URL}"
        "$ORCH" connections set-credentials -a maximo_conn --env $env --api-key "${MAXIMO_API_KEY}"
      done
      
      echo "✅ Maximo connection configured for draft and live with credentials from .env.sdk"
    fi
  else
    "$ORCH" connections configure -a maximo_conn --env draft -t team -k api_key
    echo "⚠️  .env.sdk not found. Remember to set Maximo configuration with:"
    echo "  MAXIMO_URL=https://your-maximo-instance/maximo"
    echo "  MAXIMO_API_KEY=your-maximo-api-key"
  fi
fi

# Configure ServiceNow connection if it exists
if [ -f "$ROOT/connections/servicenow_conn.yaml" ]; then
  echo ""
  echo "Configuring ServiceNow connection..."
  
  # Check if .env.sdk exists for credentials
  if [ -f "$ROOT/.env.sdk" ]; then
    source "$ROOT/.env.sdk"
    
    # Configure for both draft and live environments
    for env in draft live; do
      "$ORCH" connections configure -a servicenow_conn --env $env -t team \
        -k oauth_auth_password_flow --url "${SN_INSTANCE_URL}"
      
      "$ORCH" connections set-credentials -a servicenow_conn --env $env \
        --username "${SN_USERNAME}" --password "${SN_PASSWORD}" \
        --client-id "${SN_CLIENT_ID}" --client-secret "${SN_CLIENT_SECRET}" \
        --token-url "${SN_INSTANCE_URL}/oauth_token.do"
    done
    
    echo "✅ ServiceNow connection configured for draft and live with credentials from .env.sdk"
  else
    echo "⚠️  .env.sdk not found. Configure ServiceNow manually with:"
    echo "  ./scripts/configure_servicenow_connection.sh"
  fi
fi

# Configure Supabase connection if it exists
if [ -f "$ROOT/connections/supabase_conn.yaml" ]; then
  echo ""
  echo "Configuring Supabase connection..."
  
  # Check if .env.sdk exists for credentials
  if [ -f "$ROOT/.env.sdk" ]; then
    source "$ROOT/.env.sdk"
    
    # Configure for both draft and live environments
    for env in draft live; do
      "$ORCH" connections configure -a supabase_conn --env $env -t team -k key_value
      
      "$ORCH" connections set-credentials -a supabase_conn --env $env \
        -e "SUPABASE_URL=${SUPABASE_URL}" -e "SUPABASE_KEY=${SUPABASE_KEY}"
    done
    
    echo "✅ Supabase connection configured for draft and live with credentials from .env.sdk"
  else
    "$ORCH" connections configure -a supabase_conn --env draft -t team -k key_value
    echo "⚠️  .env.sdk not found. Remember to set Supabase credentials with:"
    echo "  orchestrate connections set-credentials -a supabase_conn --env draft \\"
    echo "    -e \"SUPABASE_URL=...\" -e \"SUPABASE_KEY=...\""
  fi
fi

# Configure Slack connection if it exists
if [ -f "$ROOT/connections/slack_conn.yaml" ]; then
  echo ""
  echo "Configuring Slack connection..."
  
  # Check if .env.sdk exists for credentials
  if [ -f "$ROOT/.env.sdk" ]; then
    source "$ROOT/.env.sdk"
    
    # Check if SLACK_WEBHOOK_URL is defined
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
      # Configure for both draft and live environments
      for env in draft live; do
        "$ORCH" connections configure -a slack_conn --env $env -t team -k key_value
        
        "$ORCH" connections set-credentials -a slack_conn --env $env \
          -e "SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}"
      done
      
      echo "✅ Slack connection configured for draft and live with credentials from .env.sdk"
    else
      "$ORCH" connections configure -a slack_conn --env draft -t team -k key_value
      echo "⚠️  SLACK_WEBHOOK_URL not found in .env.sdk. Remember to set Slack credentials with:"
      echo "  orchestrate connections set-credentials -a slack_conn --env draft \\"
      echo "    -e \"SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...\""
    fi
  else
    "$ORCH" connections configure -a slack_conn --env draft -t team -k key_value
    echo "⚠️  .env.sdk not found. Remember to set Slack credentials with:"
    echo "  orchestrate connections set-credentials -a slack_conn --env draft \\"
    echo "    -e \"SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...\""
  fi
fi

echo ""
echo "✅ Connections deployment complete"