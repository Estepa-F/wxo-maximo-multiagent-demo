# Architectural patterns

Two key patterns underpin the project's whole architecture. This document explains why they exist, how they are implemented, and which mistakes they prevent.

## 1. Propose / Confirm — governing writes

### The principle

No write to any system (Maximo, ServiceNow, inventory ERP) is triggered without **explicit validation** from the user. Every write action is split into two distinct tools:

- A `propose_*` tool that performs **no write at all**. It prepares a textual summary of the operation's parameters (reference, quantity, price, date, etc.) and returns it to the user.
- A `*_create` tool (or equivalent: `update_*`, `create_supplier_order`, etc.) that performs the actual write. It is called **only after** an explicit confirmation from the user ("yes", "confirm", "approve").

### Illustration

```
User: "Place the supplier order for 1 unit of DRV-100-AS"
       ↓
Agent: calls propose_supplier_order(reference="DRV-100-AS", quantity=1)
       ↓
Agent: displays the summary
       "Supplier order proposal — to be confirmed:
          • Reference       : DRV-100-AS (Crane intake valve)
          • Quantity        : 1
          • Supplier        : Crane Industries
          • Unit price      : 245.00 €
          • Total amount    : 245.00 €
          • Lead time       : 5 day(s)
          • Expected delivery: 2026-06-07
        Do you confirm the order? (yes / no)"
       ↓
User: "yes, confirm"
       ↓
Agent: calls create_supplier_order(reference="DRV-100-AS", quantity=1)
       ↓
System: order created with id=1, status="PENDING"
       ↓
Agent: "Order #1 created. Expected delivery on June 7, 2026."
```

### Why this pattern is non-negotiable in production

Without `propose / confirm`, an LLM can very well:

- Hallucinate an order's parameters
- Mix up two similar orders in the context
- Write to a business system based on an ambiguous request
- Claim an action was performed when it was not (the worst case)

With `propose / confirm`, every write is traced and validated. The user sees exactly what is about to happen. If the proposal is wrong, they say "no" and correct it. If it is right, they say "yes". And the write matches what was displayed.

### Operations covered by the pattern

| Operation | Propose tool | Execute tool |
|-----------|--------------|--------------|
| Create a Maximo work order | `propose_work_order` | `create_work_order` |
| Place a supplier order | `propose_supplier_order` | `create_supplier_order` |
| Update a ServiceNow incident (note, closure) | `propose_incident_update` | `update_incident` |

### Python tool-side implementation

Both tools share their parameters: `propose_*` computes a summary without touching the system; `*_execute` performs the actual write. Simplified example for the supplier order:

```python
@tool
def propose_supplier_order(reference: str, quantity: int = 1,
                           related_wonum: Optional[str] = None) -> SupplierOrderProposal:
    """Builds the proposal. Creates NOTHING."""
    part = _fetch_part(reference)
    summary = (
        f"Supplier order proposal — to be confirmed:\n"
        f"  • Reference : {reference} ({part['description']})\n"
        f"  • Quantity  : {quantity}\n"
        f"  • Supplier : {part['supplier']}\n"
        f"  • Total price : {part['unit_price'] * quantity:.2f} €\n"
        f"\nDo you confirm the order? (yes / no)"
    )
    return SupplierOrderProposal(summary=summary, ...)


@tool
def create_supplier_order(reference: str, quantity: int = 1,
                          related_wonum: Optional[str] = None) -> SupplierOrder:
    """ACTUALLY creates the order. Only call after confirmation."""
    part = _fetch_part(reference)
    row = _insert("supplier_orders", { ... })
    return SupplierOrder(**row)
```

### Agent instructions-side implementation

The agent instructions (the `instructions:` field in the YAML) must make the propose / execute separation **unambiguous**. The LLM must understand that:

1. When the user asks to **order**, we call `propose_supplier_order`, display the summary, and **stop there**.
2. When the user **confirms** ("yes", "confirm", "approve"), we call `create_supplier_order` **directly**. We do NOT call `propose_supplier_order` again.
3. An order is only created if `create_supplier_order` returned an object with a numeric `id`. Otherwise, it is a hallucination, and the agent must flag it.

Example of clear instructions in `agents/maximo_stock_agent.yaml`:

```yaml
instructions: |
  STEP A — Order request:
    1. Call ONLY propose_supplier_order
    2. Display the summary word for word
    3. End with "Do you confirm the order? (yes / no)"
    4. STOP. Do NOT call create_supplier_order at this stage.

  STEP B — User confirmation:
    1. Call create_supplier_order DIRECTLY with the SAME parameters
    2. Do NOT call propose_supplier_order a second time
    3. Announce the result with the id number actually returned

  ABSOLUTE RULE:
    NEVER say "order created" / "order confirmed" without having
    actually called create_supplier_order and obtained an id.
```

### The trap to avoid

Without this precision in the instructions, an LLM can fall into a classic trap: receiving a "yes" and **calling `propose_*` again instead of `*_create`**. The user believes their order was placed while nothing was written. It is a subtle bug because the conversation looks correct.

The defense is to always **visually check the write tool's return value**: a numeric `id`, a success message, and ideally an immediate re-read via a `list_*` or `get_*` tool for user confirmation.

---

## 2. Declarative Tool Chaining — the automatic cascade

### The principle

When a tool performs a write that must trigger a **side effect** in another system (for example: notifying Slack after an incident is closed), the tool returns in its response a **structured directive** that the orchestrator reads and executes automatically.

Concretely: when closing a ServiceNow incident, the `update_incident` tool detects that the target state is "Resolved" or "Closed" and returns in its `message` field a visually striking block:

```
✅ Incident INC0010003 closed successfully.
Number    : INC0010003
State     : Resolved (6)
Close code: Solution provided

⚠️ ORCHESTRATOR ATTENTION — MANDATORY REMAINING ACTION

You MUST now delegate to slack_notifier_agent to notify the on-call
team of this incident's closure.

Parameters to pass:
  - incident_number : INC0010003
  - asset           : 11430
  - work_order      : 1208
  - parts_ordered   : DRV-100-AS
  - supplier        : Crane Industries
  - resolution      : Solution provided
```

The orchestrator, in its own instructions, has the following rule:

> **INVIOLABLE RULE**: if an agent's response contains a block starting with `⚠️ ORCHESTRATOR ATTENTION — MANDATORY REMAINING ACTION`, you MUST execute this directive immediately, in the same turn, without asking the user for confirmation.

### Why this pattern works better than a rule in the prompt

The naive alternative would be to put in the orchestrator's system prompt:

> "Whenever a ServiceNow incident is closed, notify Slack."

This rule gets ignored by the LLM in roughly 1 conversation out of 4 — because it is abstract, because other rules compete with it, because the conversational context gets in the way.

The directive embedded in the tool response, on the other hand, **arrives at the exact moment** the decision has to be made. The LLM sees it in the content of the last tool call, framed in a striking format. It is **infinitely harder to ignore**.

### The transmission trap

For this to work, the directive block must pass through the intermediate agent **without being rewritten**. Concretely: when `servicenow_ITSM_agent` receives the response from the `update_incident` tool, it must copy the block **in full** into its response to the orchestrator. If it summarizes it ("I closed the ticket and Slack needs to be notified"), the directive is intercepted and lost.

The instructions of `servicenow_ITSM_agent` therefore explicitly contain:

```yaml
instructions: |
  If the "message" field returned by a ServiceNow tool contains a
  "⚠️ ORCHESTRATOR ATTENTION — MANDATORY REMAINING ACTION" block, you MUST
  copy it IN FULL into your response, without summarizing it, without
  paraphrasing it. This block is meant for the orchestrator, not for you.
```

### Python tool-side implementation

In `tools/servicenow_tools.py`:

```python
@tool
def update_incident(number: str, target_state: str, close_code: str = None,
                    close_notes: str = None, ...) -> IncidentUpdateResult:
    # ... ServiceNow update logic ...

    base_message = f"Incident {number} updated: state → {target_state}"

    # If closing, embed the Slack cascade directive
    if target_state in ("6", "7"):  # Resolved or Closed
        directive = f"""
✅ Incident {number} closed successfully.

⚠️ ORCHESTRATOR ATTENTION — MANDATORY REMAINING ACTION

You MUST now delegate to slack_notifier_agent to notify the on-call
team of this incident's closure.

Parameters to pass:
  - incident_number : {number}
  - resolution      : {close_code}
"""
        return IncidentUpdateResult(
            number=number,
            state=target_state,
            message=base_message + "\n\n" + directive,
        )

    return IncidentUpdateResult(number=number, state=target_state, message=base_message)
```

### Why this pattern goes beyond simple notification

Once in place, this pattern makes it possible to chain **any side effect** without modifying the orchestrator:

- Notify Slack when an incident is closed
- Create an audit log entry on every critical write
- Send a summary email to the manager when a priority 1 WO is created
- Trigger an external workflow (Zapier, n8n) after an update

The tool in question only needs to know the business rule and embed the matching directive. The orchestrator stays generic. This is what makes the architecture **scalable** and **maintainable** over time.

---

## Summary

| Pattern | When to use it | Main benefit |
|---------|------------------|---------------------|
| Propose / Confirm | On every write to a business system | Governance + zero unvalidated writes |
| Declarative tool chaining | To automate a side effect after an action | Reliable cascade + generic orchestrator |

Together, these two patterns turn a demo that "works locally" into a **production-deployable** architecture.
