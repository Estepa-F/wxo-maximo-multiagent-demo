# Installation and deployment guide

This guide explains how to deploy the project's complete architecture in WatsonX Orchestrate, from an empty environment to a working conversation with the orchestrator.

## Prerequisites

- IBM WatsonX Orchestrate (enterprise instance or developer account)
- Python 3.12+
- Access to the 4 external systems: ServiceNow, IBM Maximo, Supabase, Slack
- Repo cloned locally

## Deployment overview

Deployment happens in 4 steps, in this **mandatory** order:

```
1. Connections    →  Authentication to the 4 external systems
2. Tools          →  Python code published to WXO, bound to a connection
3. Agents         →  YAML definitions of the 6 agents, imported into WXO
4. Test           →  Validation by conversing with the orchestrator
```

Each step depends on the previous one: a tool can only be imported once its connection is ready, and an agent can only be imported once its tools are available.

## Step 0 — Environment preparation

```bash
# 1. Clone the repo
git clone https://github.com/Estepa-F/wxo-maximo-multiagent-demo.git
cd wxo-maximo-multiagent-demo

# 2. Create a Python virtual environment
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# .\venv\Scripts\activate.ps1  # Windows

# 3. Install the Orchestrate SDK
pip install ibm-watsonx-orchestrate

# 4. Configure the Orchestrate environment
orchestrate env add -n production -u <your-wxo-url> --activate
orchestrate env activate production

# 5. Prepare the variables file
cp .env.sdk.exemple .env.sdk
# Edit .env.sdk with your own credentials (see connections.md)
```

## Step 1 — Connections

Full details for each connection are in [`connections.md`](connections.md). For a quick deployment, run the 4 scripts:

```bash
./scripts/configure_maximo_connection.sh
./scripts/configure_servicenow_connection.sh
./scripts/configure_supabase_connection.sh
./scripts/configure_slack_connection.sh
```

Each script reads the required values from `.env.sdk` and configures the connection for the `draft` environment.

**Verification**:

```bash
orchestrate connections list
```

Should show the 4 connections with their respective types:

```
maximo_conn       api_key                        draft   Connection to the Maximo API
servicenow_conn   oauth_auth_password_flow       draft   ServiceNow OAuth connection
supabase_conn     api_key                        draft   Connection to the Supabase inventory
slack_conn        api_key                        draft   Slack webhook connection
```

## Step 2 — Python tools

Four Python modules expose the business operations to the external systems. Each module is bound to its respective connection via the `--app-id` parameter.

### Importing the 4 modules

```bash
# Maximo tools (7 tools: search_assets, get_work_orders, get_worklogs,
# list_attachments, get_attachment_text, propose_work_order, create_work_order)
orchestrate tools import \
  -k python \
  -f tools/maximo_tools.py \
  -r tools/requirements.txt \
  --app-id maximo_conn

# ServiceNow tools (4 tools: get_incident, list_open_incidents,
# propose_incident_update, update_incident)
orchestrate tools import \
  -k python \
  -f tools/servicenow_tools.py \
  -r tools/requirements.txt \
  --app-id servicenow_conn

# Supabase / inventory ERP tools (5 tools: get_spare_part, list_low_stock_parts,
# list_orders_for_part, propose_supplier_order, create_supplier_order)
orchestrate tools import \
  -k python \
  -f tools/supabase_tools.py \
  -r tools/requirements.txt \
  --app-id supabase_conn

# Slack tools (1 tool: send_incident_summary)
orchestrate tools import \
  -k python \
  -f tools/slack_tools.py \
  -r tools/requirements.txt \
  --app-id slack_conn
```

### Verification

```bash
orchestrate tools list
```

Should show a total of **17 tools** across the 4 modules.

### Re-importing after a change

If you modify a `tools/*.py` file, just rerun the import command. Orchestrate overwrites the previous version without asking for confirmation.

```bash
./scripts/reimport_maximo_tools.sh   # shortcut for Maximo
```

## Step 3 — Agents

The 6 agents are imported **in a specific order**: the collaborators first, then the orchestrator that references them.

```bash
# 1. Import the 5 specialist agents
orchestrate agents import -f agents/servicenow_ITSM_agent.yaml
orchestrate agents import -f agents/maximo_diagnostic_agent.yaml
orchestrate agents import -f agents/maximo_planning_agent.yaml
orchestrate agents import -f agents/maximo_stock_agent.yaml
orchestrate agents import -f agents/slack_notifier_agent.yaml

# 2. Import the orchestrator (which references the 5 above)
orchestrate agents import -f agents/maximo_orchestrator.yaml
```

Or via the script:

```bash
./scripts/import_all_agents.sh
```

### Verification

```bash
orchestrate agents list | grep -E "(maximo|servicenow|slack)"
```

Should show the 6 agents:

```
maximo_orchestrator         native    groq/openai/gpt-oss-120b
servicenow_ITSM_agent       native    groq/openai/gpt-oss-120b
maximo_diagnostic_agent     native    groq/openai/gpt-oss-120b
maximo_planning_agent       native    groq/openai/gpt-oss-120b
maximo_stock_agent          native    groq/openai/gpt-oss-120b
slack_notifier_agent        native    groq/openai/gpt-oss-120b
```

## All-in-one automated deployment

For a complete deployment in a single command (connections + tools + agents):

```bash
./scripts/deploy_complete.sh
```

This script performs steps 1, 2 and 3 in order, reading the credentials from `.env.sdk`.

## Step 4 — Test

### Quick test via CLI

```bash
orchestrate agents chat --name maximo_orchestrator
```

First message to try:

> What is the stock availability of part DRV-100-AS?

Expected:
1. Routing: `chat_with_collaborator_maximo_stock_agent`
2. Tool: `get_spare_part(reference="DRV-100-AS")`
3. Reply: "Part DRV-100-AS is out of stock (0 units). Supplier Crane Industries, price €245, lead time 5 days."

### Full end-to-end test (12 questions)

To replay the demo end to end (incident → diagnosis → order → WO → closure → Slack cascade), follow [`scenario-demo.md`](scenario-demo.md).

## Updating

After changing the code or the YAML definitions, simply rerun the corresponding import command:

```bash
# If you modified a Python tool
orchestrate tools import -k python -f tools/<module>.py \
  -r tools/requirements.txt --app-id <conn>

# If you modified an agent YAML
orchestrate agents import -f agents/<agent>.yaml

# If you modified several things
./scripts/deploy_complete.sh
```

Imports are idempotent: they overwrite the previous version.

## Promoting to production

The whole guide above uses the `draft` environment. To publish to `live`:

```bash
# For each connection, redo the configuration and credential injection
orchestrate connections configure -a <conn> --env live ...
orchestrate connections set-credentials -a <conn> --env live ...

# Then publish the agents
orchestrate agents publish --name maximo_orchestrator
```

## Troubleshooting

### `Connection not found` when importing a tool

The connection referenced by `--app-id` has not been created. Go back to step 1.

### `Agent collaborator not found` when importing the orchestrator

One of the 5 specialist agents has not been imported yet. Rerun in order — specialists first, orchestrator second.

### `Tool not found` when importing an agent

The tool referenced in the agent YAML's `tools:` list does not exist in WXO. Check the name (see `orchestrate tools list`) and rerun the import of the relevant Python module.

### Python error on import (`Module not found`, etc.)

The `tools/requirements.txt` file does not list a dependency used by the code. Check its contents and add what is missing:

```
requests
pydantic
pypdf
```

### ServiceNow token expired during a test

ServiceNow OAuth tokens expire after 30 minutes by default. The tool code renews them automatically. If a cURL check fails, regenerate a token manually (see [`connections.md`](connections.md)).

### The orchestrator claims an action that was not performed

This is the classic pitfall of the propose / confirm pattern. Check in Show Reasoning that the `*_create` or `update_*` tool was actually called (and not just the `propose_*` tool). If the agent systematically skips the execution tool, strengthen the instructions of the agent concerned (see [`patterns.md`](patterns.md) → absolute rules).

### The Slack cascade does not trigger on closure

Check in Show Reasoning that:
1. The return value of `update_incident` does contain the `⚠️ ORCHESTRATOR ATTENTION — MANDATORY REMAINING ACTION` block
2. `servicenow_ITSM_agent` copied this block verbatim (without summarizing it)
3. The orchestrator did delegate to `slack_notifier_agent`

If a step is missing, review the instructions of the agents concerned.

## Available scripts

For reference, the scripts in the `scripts/` folder:

| Script | Purpose |
|--------|---------|
| `configure_maximo_connection.sh` | Creation + configuration of the Maximo connection |
| `configure_servicenow_connection.sh` | Same for ServiceNow |
| `configure_supabase_connection.sh` | Same for Supabase |
| `configure_slack_connection.sh` | Same for Slack |
| `create_connections.sh` | Runs the 4 previous scripts in one go |
| `reimport_maximo_tools.sh` | Re-imports tools/maximo_tools.py |
| `import_supabase_tools.sh` | Imports tools/supabase_tools.py |
| `import_all_agents.sh` | Imports the 6 agents in the right order |
| `deploy_complete.sh` | Full pipeline: connections + tools + agents |

## Next steps

Once the installation is validated:
- Replay the [full 12-question scenario](scenario-demo.md)
- Adapt the agents to your own context (instructions, prompts, routing)
- Add other systems following the pattern described in [`architecture.md`](architecture.md)
