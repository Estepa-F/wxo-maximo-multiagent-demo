# Multi-agent architecture

This document describes the project architecture: 1 orchestrator, 5 specialized agents, 4 connected systems (ServiceNow, IBM Maximo, Supabase ERP, Slack).

## Overview

The architecture uses an orchestration pattern where the user interacts with a **single agent** (the orchestrator), which delegates each task to a **specialized agent** responsible for exactly one business system.

```
                       ┌─────────────────────────────────┐
                       │      maximo_orchestrator        │
                       │   (User entry point)            │
                       └────────────────┬────────────────┘
                                        │
        ┌──────────────┬────────────────┼────────────────┬──────────────┐
        │              │                │                │              │
        ▼              ▼                ▼                ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐ ┌────────────┐
│ servicenow_  │ │   maximo_    │ │   maximo_    │ │  maximo_   │ │   slack_   │
│ ITSM_agent   │ │ diagnostic_  │ │  planning_   │ │  stock_    │ │ notifier_  │
│              │ │    agent     │ │    agent     │ │  agent     │ │   agent    │
│ ITSM         │ │ Maximo       │ │ Maximo       │ │ Stock &    │ │ Team       │
│ tickets      │ │ reads        │ │ writes       │ │ orders     │ │ notif.     │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └─────┬──────┘ └─────┬──────┘
       │                │                │                │              │
       ▼                ▼                ▼                ▼              ▼
┌──────────────┐ ┌──────────────────────────────┐ ┌────────────┐ ┌────────────┐
│  ServiceNow  │ │     IBM Maximo Application   │ │  Supabase  │ │   Slack    │
│   (OAuth 2.0 │ │   Suite (OSLC + API key)     │ │ PostgreSQL │ │  Webhook   │
│ password gr.)│ │                              │ │  + REST    │ │  + Blocks  │
└──────────────┘ └──────────────────────────────┘ └────────────┘ └────────────┘
```

**Principles**:
- 1 agent = 1 business responsibility
- 1 agent = 1 backend system
- No cross-coupling between agents
- The orchestrator only routes and coordinates — it has no tools of its own

## The six agents

### 1. `maximo_orchestrator`

**Role**: the user's single entry point. Understands the natural-language request and delegates to the relevant specialist agent. Keeps the conversation context (current asset, incident, WO, part mentioned) so the user never has to repeat themselves.

**Tools**: none. The orchestrator only routes.

**Collaborators**:
- `servicenow_ITSM_agent`
- `maximo_diagnostic_agent`
- `maximo_planning_agent`
- `maximo_stock_agent`
- `slack_notifier_agent`

**Routing logic**:

| Request type | Typical keywords | Agent called |
|-----------------|--------------------|--------------|
| Read an incident ticket | "ticket", "INC...", "incident", "what is it about" | `servicenow_ITSM_agent` |
| Read an asset / a WO / a PDF guide | "interventions", "asset", "guide", "worklog" | `maximo_diagnostic_agent` |
| Create a work order | "create a WO", "open an intervention", "schedule" | `maximo_planning_agent` |
| Check stock / order a part | "stock", "availability", "out of stock", "supplier order" | `maximo_stock_agent` |
| Notify the on-call team | triggered **automatically** by cascade from ServiceNow on closure | `slack_notifier_agent` |

### 2. `servicenow_ITSM_agent`

**Role**: interacts with ServiceNow for incident management (read and write).

**Tools**:
- `get_incident` — retrieves an incident's details by number
- `list_open_incidents` — lists open incidents
- `propose_incident_update` — prepares an update (DRY-RUN)
- `update_incident` — applies the update (after confirmation)

**Specifics**: when an incident is closed (Resolved / Closed state), the `update_incident` tool returns in its `message` field a **structured directive** asking the orchestrator to then delegate to `slack_notifier_agent`. See [`patterns.md`](patterns.md) for the details of the "Declarative tool chaining" pattern.

### 3. `maximo_diagnostic_agent`

**Role**: **read** operations on Maximo. Looks up assets, work orders, intervention notes and attached documents.

**Tools**:
- `search_assets_by_keyword` — searches for an asset by keyword
- `get_work_orders_for_asset` — lists the WOs of an asset
- `get_worklogs_for_workorder` — intervention notes of a WO
- `list_asset_attachments` — documents attached to an asset
- `get_attachment_text` — extracts the text content of a PDF / document

**Use cases**:
- "What are the latest interventions on asset 11430?"
- "The worklog mentions the intake valve, what does the guide say about it?"
- "Summarize the notes of WO 1208 for me."

### 4. `maximo_planning_agent`

**Role**: **write** operations on Maximo. Creates corrective or preventive work orders.

**Tools**:
- `propose_work_order` — prepares a WO (DRY-RUN), returns a summary to confirm
- `create_work_order` — actually creates the WO (after user confirmation)

**Specifics**: strictly follows the propose / confirm pattern. See [`patterns.md`](patterns.md).

**Use cases**:
- "Create a corrective work order on asset 11430 to replace the intake valve, high priority, target date in 7 days."

### 5. `maximo_stock_agent`

**Role**: manages a system **separate from Maximo** — the spare parts catalog and supplier orders (stored in Supabase). This is the system that embodies the inventory ERP.

**Tools**:
- `get_spare_part` — looks up a part by reference
- `list_low_stock_parts` — parts out of stock (stock ≤ min_stock)
- `list_orders_for_part` — order history for a part
- `propose_supplier_order` — proposes a supplier order (DRY-RUN)
- `create_supplier_order` — actually creates the order (after confirmation)

**Use cases**:
- "What is the stock availability of part DRV-100-AS?"
- "Place the supplier order for 1 unit of DRV-100-AS."

### 6. `slack_notifier_agent`

**Role**: sends structured notifications (Slack Block Kit) to the maintenance team channel. Triggered when a ServiceNow incident is closed, via the declarative tool chaining pattern.

**Tools**:
- `send_incident_summary` — sends a Block Kit message summarizing the closed incident, the Maximo WO, the supplier order and the actions taken

**Use cases**: no direct human intervention. The agent is called by the orchestrator on a directive from `servicenow_ITSM_agent`.

## Architectural patterns

Two key patterns underpin the whole architecture. They are documented in detail in [`patterns.md`](patterns.md).

### Propose / Confirm

No write to any system is triggered without explicit validation from the user. Every write (WO creation, ticket update, closure, supplier order) is preceded by a call to a `propose_*` tool that returns a summary. The user confirms with "yes" / "confirm", and only then is the `*_create` or `update_*` tool called.

### Declarative Tool Chaining

When a tool performs a write that must trigger a side effect (for example: a Slack notification on incident closure), the tool returns in its response a **structured directive** that the orchestrator reads and executes. This is more reliable than a rule in the system prompt, which the LLM can ignore.

## Reference workflows

### Workflow A — Simple lookup

```
User → Orchestrator → Specialist agent → Response
```

Example: "What are the latest interventions on asset 11430?"

→ the orchestrator delegates to `maximo_diagnostic_agent`
→ `get_work_orders_for_asset(assetnum="11430")`
→ formatted list of WOs returned to the user

### Workflow B — Creation with validation

```
User → Orchestrator → Specialist agent → propose_* → User confirmation → create_* → System confirmation
```

Example: "Place the supplier order for 1 unit of DRV-100-AS."

→ the orchestrator delegates to `maximo_stock_agent`
→ `propose_supplier_order`: summary with price, lead time, supplier, delivery date
→ user: "yes, confirm"
→ `create_supplier_order`: order created with id, status PENDING

### Workflow C — Cross-system with automatic cascade

This is the demo's flagship workflow. All writes and the Slack cascade are chained by the orchestrator from a single user conversation:

```
1. User reads incident INC0010003 (servicenow_ITSM_agent)
2. User looks up the history of asset 11430 (maximo_diagnostic_agent)
3. User looks up the asset's PDF guide (maximo_diagnostic_agent)
4. User checks the stock of DRV-100-AS (maximo_stock_agent)
5. User places the order (propose + confirm + create — maximo_stock_agent)
6. User creates the corrective WO on the asset (propose + confirm + create — maximo_planning_agent)
7. User adds a progress note to the ticket (propose + confirm — servicenow_ITSM_agent)
8. User closes the ticket (propose + confirm + update — servicenow_ITSM_agent)
   ↓ The update_incident tool detects a closure and returns a directive
   ↓ ORCHESTRATOR ATTENTION — MANDATORY REMAINING ACTION
9. The orchestrator reads the directive and delegates to slack_notifier_agent
10. slack_notifier_agent sends the Block Kit summary message
```

The full 12-question scenario (with the exact prompts to use to replay the demo) is in [`scenario-demo.md`](scenario-demo.md).

## LLM configuration

All agents use the same model in the demo: `groq/openai/gpt-oss-120b`.

To change the LLM, edit the `llm:` field in each `agents/*.yaml` file. The architecture is LLM-agnostic — Granite, Llama, Mistral and Claude work too.

**Chain of Thought configuration**:
- `enable_cot: true` on the orchestrator (routing reasoning)
- `enable_cot: true` on `maximo_stock_agent` and `servicenow_ITSM_agent` (complex propose / confirm pattern)
- `enable_cot: false` on the read-only agents (more direct answers)

## Possible extensions

The architecture is designed to scale horizontally. Adding a new system (Teams, SAP PM, Workday, etc.) consists of:

1. Creating a WXO connection to the new system (ApiKey, OAuth, etc.)
2. Writing the Python tools that expose the business operations
3. Creating a new specialist agent that owns these tools and its own instructions
4. Adding this agent to the orchestrator's `collaborators:` list
5. Adding the corresponding routing rule to the orchestrator's instructions

No existing agent needs to be modified.
