"""
WatsonX Orchestrate ADK tools for Slack notifications.

Uses Slack Incoming Webhooks (no OAuth, no bot token — just a secret URL).
The URL is stored in WXO connection 'slack_conn' under SLACK_WEBHOOK_URL.

Tools provided:
  - send_simple_message    : post plain text to the configured channel
  - send_incident_summary  : post a rich Block Kit recap of an incident closure
"""

import json
from typing import Optional, List

import requests
from pydantic import BaseModel, Field

from ibm_watsonx_orchestrate.agent_builder.tools import tool
from ibm_watsonx_orchestrate.agent_builder.connections import ConnectionType
from ibm_watsonx_orchestrate.run import connections


SLACK_APP_ID = "slack_conn"


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def _webhook_url() -> str:
    conn = connections.key_value(SLACK_APP_ID)
    url = conn.get("SLACK_WEBHOOK_URL", "")
    if not url:
        raise RuntimeError("SLACK_WEBHOOK_URL is not set in slack_conn")
    return url


def _post(payload: dict) -> str:
    """Send payload to Slack webhook. Returns 'ok' on success, raises otherwise."""
    resp = requests.post(
        _webhook_url(),
        headers={"Content-Type": "application/json"},
        data=json.dumps(payload),
        timeout=15,
    )
    resp.raise_for_status()
    return resp.text  # Slack returns "ok" on success


# --------------------------------------------------------------------------- #
# Output schema
# --------------------------------------------------------------------------- #

class SlackMessageResult(BaseModel):
    success: bool
    message: str = Field(description="Confirmation message to show the user")


# --------------------------------------------------------------------------- #
# TOOLS
# --------------------------------------------------------------------------- #

@tool(
    expected_credentials=[
        {"app_id": SLACK_APP_ID, "type": ConnectionType.KEY_VALUE}
    ]
)
def send_simple_message(text: str) -> SlackMessageResult:
    """
    Send a plain text message to the Slack channel configured via the
    incoming webhook. Use this for short notifications.

    :param text: The message text (max ~3000 characters, supports Slack mrkdwn
                 like *bold*, _italic_, `code`).
    :returns: Success status and confirmation message.
    """
    _post({"text": text})
    return SlackMessageResult(
        success=True,
        message="Message envoyé sur le canal Slack."
    )


@tool(
    expected_credentials=[
        {"app_id": SLACK_APP_ID, "type": ConnectionType.KEY_VALUE}
    ]
)
def send_incident_summary(
    incident_number: str,
    asset_short_desc: str,
    short_description: str,
    diagnostic: str,
    wonum: Optional[str] = None,
    wo_status: Optional[str] = None,
    spare_reference: Optional[str] = None,
    spare_amount: Optional[str] = None,
    expected_delivery: Optional[str] = None,
    supplier: Optional[str] = None,
) -> SlackMessageResult:
    """
    Send a rich, formatted recap of an incident closure to the Slack channel.
    Use this at the end of a maintenance workflow to notify the team that an
    incident has been investigated, a work order created, and a spare part
    ordered (if applicable).

    :param incident_number: ServiceNow incident number (e.g. "INC0010001").
    :param asset_short_desc: Asset reference and short description (e.g. "Pompe 11430 (BEDFORD)").
    :param short_description: Original incident short description.
    :param diagnostic: Brief diagnostic summary (e.g. "Vanne d'admission bloquée").
    :param wonum: Maximo work order number created (e.g. "1207").
    :param wo_status: Work order status (e.g. "WAPPR").
    :param spare_reference: Spare part reference ordered (e.g. "DRV-100-AS").
    :param spare_amount: Spare part total amount with currency (e.g. "245€").
    :param expected_delivery: Expected delivery date (e.g. "15 juin 2026").
    :param supplier: Supplier name (e.g. "Crane Industries").
    :returns: Success status and confirmation message.
    """
    blocks: List[dict] = [
    {
        "type": "header",
        "text": {"type": "plain_text", "text": f"✅ Incident {incident_number} traité"}
    }
]

    # Section "asset — short_description" seulement si au moins un champ
    if asset_short_desc or short_description:
        title_parts = []
        if asset_short_desc:
            title_parts.append(f"*{asset_short_desc}*")
        if short_description:
            title_parts.append(short_description)
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": " — ".join(title_parts)}
        })

    # Section incident + diagnostic seulement si on a un diagnostic
    if diagnostic:
        blocks.append({
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*Incident:*\n{incident_number} (Résolu)"},
                {"type": "mrkdwn", "text": f"*Diagnostic:*\n{diagnostic}"},
            ]
        })

    
    # Work order section (if provided)
    if wonum:
        wo_text = wonum
        if wo_status:
            wo_text = f"{wonum} ({wo_status})"
        spare_text = "—"
        if spare_reference:
            spare_text = spare_reference
            if spare_amount:
                spare_text = f"{spare_reference} ({spare_amount})"
        blocks.append({
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*Work Order Maximo:*\n{wo_text}"},
                {"type": "mrkdwn", "text": f"*Pièce commandée:*\n{spare_text}"},
            ]
        })

    # Context footer (delivery + supplier)
    context_parts = []
    if expected_delivery:
        context_parts.append(f"Livraison prévue: *{expected_delivery}*")
    if supplier:
        context_parts.append(f"Fournisseur: {supplier}")
    if context_parts:
        blocks.append({
            "type": "context",
            "elements": [
                {"type": "mrkdwn", "text": " · ".join(context_parts)}
            ]
        })

    _post({"blocks": blocks})
    return SlackMessageResult(
        success=True,
        message=f"Récap de l'incident {incident_number} envoyé sur Slack."
    )
