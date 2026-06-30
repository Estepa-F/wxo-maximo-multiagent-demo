"""
WatsonX Orchestrate ADK tools for the spare parts inventory system (Supabase).

This is a SEPARATE system from Maximo. It manages the spare parts catalog and
supplier orders. The point of this module is to demonstrate cross-system
orchestration: the agent reads from Maximo AND from this inventory before
making decisions.

Read tools:
  - get_spare_part            : fetch one part by reference
  - list_low_stock_parts      : list parts at or below their min_stock threshold
  - list_orders_for_part      : list supplier orders for one part

Write tools (two-step confirmation pattern):
  - propose_supplier_order    : DRY-RUN, builds and returns a summary
  - create_supplier_order     : actual INSERT, only after explicit confirmation
"""

import json
from datetime import date, timedelta
from typing import List, Optional

import requests
from pydantic import BaseModel, Field

from ibm_watsonx_orchestrate.agent_builder.tools import tool
from ibm_watsonx_orchestrate.agent_builder.connections import ConnectionType
from ibm_watsonx_orchestrate.run import connections


SUPABASE_APP_ID = "supabase_conn"


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def _get_connection():
    return connections.key_value(SUPABASE_APP_ID)


def _base_url() -> str:
    conn = _get_connection()
    url = conn.get("SUPABASE_URL", "").rstrip("/")
    if not url:
        raise RuntimeError("Supabase URL is not set in connection (expected key: SUPABASE_URL)")
    return url


def _headers(prefer: Optional[str] = None) -> dict:
    conn = _get_connection()
    apikey = conn.get("SUPABASE_KEY") or conn.get("apikey")
    if not apikey:
        raise RuntimeError("Supabase API key is not set in connection (expected key: SUPABASE_KEY)")
    h = {
        "apikey": apikey,
        "Authorization": f"Bearer {apikey}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if prefer:
        h["Prefer"] = prefer
    return h


def _rest_url(table: str) -> str:
    return f"{_base_url()}/rest/v1/{table}"


def _get(table: str, params: dict) -> dict:
    """Helper for GET requests with error handling."""
    resp = requests.get(_rest_url(table), headers=_headers(), params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


def _post(table: str, body: dict) -> dict:
    """Helper for POST requests with error handling."""
    resp = requests.post(
        _rest_url(table),
        headers=_headers(prefer="return=representation"),
        data=json.dumps(body),
        timeout=30,
    )
    resp.raise_for_status()
    result = resp.json()
    return result[0] if isinstance(result, list) else result


# --------------------------------------------------------------------------- #
# Output schemas
# --------------------------------------------------------------------------- #

class SparePart(BaseModel):
    reference: str
    description: Optional[str] = None
    stock_qty: int
    min_stock: int
    location: Optional[str] = None
    supplier: Optional[str] = None
    unit_price: Optional[float] = None
    lead_time_days: Optional[int] = None
    is_in_stock: bool = Field(description="True if stock_qty > 0")
    is_below_min: bool = Field(description="True if stock_qty < min_stock (reorder threshold reached)")


class SupplierOrder(BaseModel):
    id: int
    reference: str
    quantity: int
    supplier: str
    unit_price: Optional[float] = None
    total_amount: Optional[float] = None
    status: str
    related_wonum: Optional[str] = None
    created_at: Optional[str] = None
    expected_delivery: Optional[str] = None


class SupplierOrderProposal(BaseModel):
    summary: str = Field(description="Human-readable summary to show to the user")
    reference: str
    quantity: int
    supplier: str
    unit_price: Optional[float] = None
    total_amount: Optional[float] = None
    lead_time_days: Optional[int] = None
    expected_delivery: Optional[str] = None
    related_wonum: Optional[str] = None
    requires_confirmation: bool = Field(True, description="Always true — confirm before calling create_supplier_order")


# --------------------------------------------------------------------------- #
# READ TOOLS
# --------------------------------------------------------------------------- #

@tool(
    expected_credentials=[
        {"app_id": SUPABASE_APP_ID, "type": ConnectionType.KEY_VALUE}
    ]
)
def get_spare_part(reference: str) -> SparePart:
    """
    Look up a single spare part by its reference (e.g. "DRV-100-AS") in the
    inventory system. Returns the current stock level, location, supplier,
    unit price and lead time. Also flags whether the part is in stock and
    whether the stock is below the minimum reorder threshold.

    Use this BEFORE creating a corrective work order that consumes a part —
    you want to know if the part is available before promising a date.

    :param reference: Part reference (e.g. "DRV-100-AS", "JC-T21-EPDM-32").
    :returns: Stock and supplier information for the part.
    """
    params = {
        "select": "*",
        "reference": f"eq.{reference}",
    }
    rows = _get("spare_parts", params)
    if not rows:
        raise ValueError(f"Spare part {reference} not found in inventory")
    row = rows[0]
    return SparePart(
        reference=row["reference"],
        description=row.get("description"),
        stock_qty=row["stock_qty"],
        min_stock=row["min_stock"],
        location=row.get("location"),
        supplier=row.get("supplier"),
        unit_price=row.get("unit_price"),
        lead_time_days=row.get("lead_time_days"),
        is_in_stock=row["stock_qty"] > 0,
        is_below_min=row["stock_qty"] < row["min_stock"],
    )


@tool(
    expected_credentials=[
        {"app_id": SUPABASE_APP_ID, "type": ConnectionType.KEY_VALUE}
    ]
)
def list_low_stock_parts() -> List[SparePart]:
    """
    List all spare parts whose current stock is at or below the minimum
    reorder threshold. Use this to give a global view of supply risks
    (e.g. "which parts need to be reordered?").
    """
    params = {
        "select": "*",
        "order": "reference.asc",
    }
    rows = _get("spare_parts", params)
    return [
        SparePart(
            reference=r["reference"],
            description=r.get("description"),
            stock_qty=r["stock_qty"],
            min_stock=r["min_stock"],
            location=r.get("location"),
            supplier=r.get("supplier"),
            unit_price=r.get("unit_price"),
            lead_time_days=r.get("lead_time_days"),
            is_in_stock=r["stock_qty"] > 0,
            is_below_min=r["stock_qty"] < r["min_stock"],
        )
        for r in rows
        if r["stock_qty"] <= r["min_stock"]
    ]


@tool(
    expected_credentials=[
        {"app_id": SUPABASE_APP_ID, "type": ConnectionType.KEY_VALUE}
    ]
)
def list_orders_for_part(reference: str) -> List[SupplierOrder]:
    """
    List the supplier orders previously placed for a given spare part.
    Use this to check whether a reorder is already in progress before
    proposing a new one.

    :param reference: Part reference (e.g. "DRV-100-AS").
    """
    params = {
        "select": "*",
        "reference": f"eq.{reference}",
        "order": "created_at.desc",
    }
    rows = _get("supplier_orders", params)
    return [SupplierOrder(**r) for r in rows]


# --------------------------------------------------------------------------- #
# WRITE TOOLS — two-step confirmation
# --------------------------------------------------------------------------- #

@tool(
    expected_credentials=[
        {"app_id": SUPABASE_APP_ID, "type": ConnectionType.KEY_VALUE}
    ]
)
def propose_supplier_order(
    reference: str,
    quantity: int = 1,
    related_wonum: Optional[str] = None,
) -> SupplierOrderProposal:
    """
    Build a supplier order PROPOSAL for a given spare part. Does NOT write
    anything. Returns a human-readable summary with the supplier, unit price,
    total amount, and expected delivery date computed from the lead time.

    ALWAYS call this tool BEFORE create_supplier_order. Show the summary and
    obtain EXPLICIT user confirmation before placing the actual order.

    :param reference: Part reference (e.g. "DRV-100-AS").
    :param quantity: How many units to order (default 1).
    :param related_wonum: Optional Maximo work order this order supports.
    :returns: A proposal with summary; await user confirmation.
    """
    # Validate part exists and gather pricing/lead time
    params = {"select": "*", "reference": f"eq.{reference}"}
    rows = _get("spare_parts", params)
    if not rows:
        raise ValueError(f"Cannot order: part {reference} does not exist in catalog")
    part = rows[0]

    unit_price = part.get("unit_price")
    total = round(unit_price * quantity, 2) if unit_price else None
    lead = part.get("lead_time_days") or 0
    delivery = (date.today() + timedelta(days=lead)).isoformat() if lead else None
    supplier = part.get("supplier") or "Fournisseur inconnu"

    lines = [
        "Proposition de commande fournisseur — à confirmer :",
        f"  • Référence       : {reference} ({part.get('description', '')})",
        f"  • Quantité        : {quantity}",
        f"  • Fournisseur     : {supplier}",
    ]
    if unit_price is not None:
        lines.append(f"  • Prix unitaire   : {unit_price:.2f} €")
        lines.append(f"  • Montant total   : {total:.2f} €")
    if lead:
        lines.append(f"  • Délai           : {lead} jour(s)")
        lines.append(f"  • Livraison prévue: {delivery}")
    if related_wonum:
        lines.append(f"  • WO associée     : {related_wonum}")
    lines.append("")
    lines.append("Confirmez-vous la commande ? (oui / non)")

    return SupplierOrderProposal(
        summary="\n".join(lines),
        reference=reference,
        quantity=quantity,
        supplier=supplier,
        unit_price=unit_price,
        total_amount=total,
        lead_time_days=lead,
        expected_delivery=delivery,
        related_wonum=related_wonum,
        requires_confirmation=True,
    )


@tool(
    expected_credentials=[
        {"app_id": SUPABASE_APP_ID, "type": ConnectionType.KEY_VALUE}
    ]
)
def create_supplier_order(
    reference: str,
    quantity: int = 1,
    related_wonum: Optional[str] = None,
) -> SupplierOrder:
    """
    Actually CREATE a supplier order in the inventory system. This writes a
    new row to the supplier_orders table.

    DO NOT CALL DIRECTLY. The required workflow is:
      1. Call propose_supplier_order first.
      2. Show the summary and obtain EXPLICIT user confirmation.
      3. Only then call create_supplier_order with the same parameters.

    :param reference: Part reference (e.g. "DRV-100-AS").
    :param quantity: How many units to order.
    :param related_wonum: Optional Maximo work order this order supports.
    :returns: The created supplier order row.
    """
    # Fetch the part for pricing and supplier info
    params = {"select": "*", "reference": f"eq.{reference}"}
    rows = _get("spare_parts", params)
    if not rows:
        raise ValueError(f"Cannot order: part {reference} does not exist in catalog")
    part = rows[0]

    unit_price = part.get("unit_price")
    total = round(unit_price * quantity, 2) if unit_price else None
    lead = part.get("lead_time_days") or 0
    delivery = (date.today() + timedelta(days=lead)).isoformat() if lead else None
    supplier = part.get("supplier") or "Unknown"

    body = {
        "reference": reference,
        "quantity": quantity,
        "supplier": supplier,
        "unit_price": unit_price,
        "total_amount": total,
        "status": "PENDING",
        "expected_delivery": delivery,
        "related_wonum": related_wonum,
    }
    return SupplierOrder(**_post("supplier_orders", body))

# Made with Bob
