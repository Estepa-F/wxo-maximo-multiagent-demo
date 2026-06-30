"""
WatsonX Orchestrate ADK tools for ServiceNow (ITSM).

Tools provided:
  - get_incident             : retrieve one incident by number (e.g. INC0010001)
  - list_open_incidents      : list open incidents
  - propose_incident_update  : DRY-RUN, builds the update payload + summary
  - update_incident          : actual PATCH, only after explicit confirmation.
                               When closing an incident, the response message
                               itself embeds a MANDATORY DIRECTIVE that forces
                               the orchestrator to delegate to slack_notifier_agent
                               in the same turn.

Auth model:
  ServiceNow OAuth 2.0 with the "password" grant. The ADK handles the token
  exchange and refresh automatically via connections.oauth2_password().

Connection variables (stored in WXO connection 'servicenow_conn'):
  Server URL, OAuth client id/secret, username, password — all configured
  via the WXO connection UI/CLI.
"""

import json
import re
from typing import List, Optional

import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

from pydantic import BaseModel, Field

from ibm_watsonx_orchestrate.agent_builder.tools import tool
from ibm_watsonx_orchestrate.agent_builder.connections import ConnectionType
from ibm_watsonx_orchestrate.run import connections


SERVICENOW_APP_ID = "servicenow_conn"


# --------------------------------------------------------------------------- #
# Auth & helpers
# --------------------------------------------------------------------------- #

def _get_connection():
    return connections.oauth2_password(SERVICENOW_APP_ID)


def _base_url() -> str:
    conn = _get_connection()
    url = conn.url.rstrip("/") if conn.url else ""
    if not url:
        raise RuntimeError("Server URL is not set in servicenow_conn")
    return url


def _headers() -> dict:
    """Get headers with OAuth access token (managed by ADK)."""
    conn = _get_connection()
    return {
        "Authorization": f"Bearer {conn.access_token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def _strip_html(text: Optional[str]) -> Optional[str]:
    if not text:
        return text
    return re.sub(r"<[^>]+>", "", text).strip()


def _get(endpoint: str, params: Optional[dict] = None) -> dict:
    """Helper for GET requests with error handling."""
    resp = requests.get(
        f"{_base_url()}{endpoint}",
        headers=_headers(),
        params=params,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def _patch(endpoint: str, body: dict) -> dict:
    """Helper for PATCH requests with error handling."""
    resp = requests.patch(
        f"{_base_url()}{endpoint}",
        headers=_headers(),
        data=json.dumps(body),
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


# --------------------------------------------------------------------------- #
# Output schemas
# --------------------------------------------------------------------------- #

class Incident(BaseModel):
    number: str = Field(description="Incident number (e.g. INC0010001)")
    short_description: Optional[str] = None
    description: Optional[str] = None
    state: Optional[str] = None
    state_label: Optional[str] = None
    priority: Optional[str] = None
    cmdb_ci: Optional[str] = None
    caller: Optional[str] = None
    opened_at: Optional[str] = None
    assigned_to: Optional[str] = None
    sys_id: Optional[str] = None


class IncidentUpdateProposal(BaseModel):
    summary: str
    number: str
    sys_id: str
    new_state: Optional[str] = None
    new_state_label: Optional[str] = None
    work_notes: Optional[str] = None
    close_notes: Optional[str] = None
    close_code: Optional[str] = None
    requires_confirmation: bool = True


class IncidentUpdated(BaseModel):
    number: str
    state: Optional[str] = None
    state_label: Optional[str] = None
    sys_id: Optional[str] = None
    message: str = Field(
        description="Confirmation message. For closures, embeds a MANDATORY directive for the orchestrator to chain to Slack notification in the same turn."
    )


# ServiceNow incident state mapping (default install)
STATE_LABELS = {
    "1": "Nouveau",
    "2": "En cours",
    "3": "En attente",
    "6": "Résolu",
    "7": "Fermé",
    "8": "Annulé",
}

STATE_FROM_LABEL = {
    "new": "1", "nouveau": "1",
    "in_progress": "2", "en cours": "2", "in progress": "2",
    "on_hold": "3", "en attente": "3",
    "resolved": "6", "résolu": "6", "resolu": "6",
    "closed": "7", "fermé": "7", "ferme": "7",
    "cancelled": "8", "annulé": "8", "annule": "8",
}


def _normalize_state(s: Optional[str]) -> Optional[str]:
    if not s:
        return None
    s = str(s).strip().lower()
    if s.isdigit():
        return s
    return STATE_FROM_LABEL.get(s, s)


def _row_to_incident(row: dict) -> Incident:
    """Convert a raw ServiceNow API row to our Incident schema."""
    state = str(row.get("state", "")) or None
    def _v(field):
        x = row.get(field)
        if isinstance(x, dict):
            return x.get("value") or x.get("display_value")
        return x
    return Incident(
        number=str(row.get("number", "")),
        short_description=row.get("short_description"),
        description=_strip_html(row.get("description")),
        state=state,
        state_label=STATE_LABELS.get(state) if state else None,
        priority=str(row.get("priority", "")) or None,
        cmdb_ci=_v("cmdb_ci"),
        caller=_v("caller_id"),
        opened_at=row.get("opened_at"),
        assigned_to=_v("assigned_to"),
        sys_id=row.get("sys_id"),
    )


def _fetch_incident(number: str) -> Incident:
    """Internal helper (not a tool) — usable by other tools without ToolResponse wrapping."""
    params = {
        "sysparm_query": f"number={number}",
        "sysparm_limit": 1,
        "sysparm_display_value": "false",
    }
    result = _get("/api/now/table/incident", params)
    rows = result.get("result", [])
    if not rows:
        raise ValueError(f"Incident {number} not found in ServiceNow")
    return _row_to_incident(rows[0])


# --------------------------------------------------------------------------- #
# READ TOOLS
# --------------------------------------------------------------------------- #

@tool(
    expected_credentials=[
        {"app_id": SERVICENOW_APP_ID, "type": ConnectionType.OAUTH2_PASSWORD}
    ]
)
def get_incident(number: str) -> Incident:
    """
    Retrieve a ServiceNow incident by its number (e.g. "INC0010001").
    Returns the short description, full description, state, priority,
    linked configuration item (asset), caller, and assignment info.

    :param number: ServiceNow incident number (e.g. "INC0010001").
    """
    return _fetch_incident(number)


@tool(
    expected_credentials=[
        {"app_id": SERVICENOW_APP_ID, "type": ConnectionType.OAUTH2_PASSWORD}
    ]
)
def list_open_incidents(limit: int = 10) -> List[Incident]:
    """
    List currently open ServiceNow incidents (state != Closed and != Resolved),
    most recently opened first.

    :param limit: Max number of incidents to return (default 10).
    """
    params = {
        # state not in (6=Resolved, 7=Closed, 8=Cancelled)
        "sysparm_query": "active=true^stateNOT IN6,7,8^ORDERBYDESCopened_at",
        "sysparm_limit": limit,
        "sysparm_display_value": "false",
    }
    result = _get("/api/now/table/incident", params)
    rows = result.get("result", [])
    return [_row_to_incident(r) for r in rows]


# --------------------------------------------------------------------------- #
# WRITE TOOLS — two-step confirmation
# --------------------------------------------------------------------------- #

@tool(
    expected_credentials=[
        {"app_id": SERVICENOW_APP_ID, "type": ConnectionType.OAUTH2_PASSWORD}
    ]
)
def propose_incident_update(
    number: str,
    work_notes: Optional[str] = None,
    new_state: Optional[str] = None,
    close_notes: Optional[str] = None,
    close_code: Optional[str] = None,
) -> IncidentUpdateProposal:
    """
    Build a PROPOSAL to update a ServiceNow incident. Does NOT write anything.

    :param number: Incident number (e.g. "INC0010001").
    :param work_notes: Internal work note to append.
    :param new_state: Target state (numeric or label like "resolved").
    :param close_notes: Resolution notes (REQUIRED when moving to Resolved/Closed).
    :param close_code: Resolution code (must be a valid value from the instance).
    """
    inc = _fetch_incident(number)
    target_state = _normalize_state(new_state)
    target_label = STATE_LABELS.get(target_state) if target_state else None

    lines = [
        "Proposition de mise à jour ServiceNow — à confirmer :",
        f"  • Incident       : {inc.number} ({inc.short_description or ''})",
        f"  • État actuel    : {inc.state_label or inc.state or '?'}",
    ]
    if target_state:
        lines.append(f"  • Nouvel état    : {target_label or target_state}")
    if work_notes:
        wn = work_notes if len(work_notes) <= 300 else work_notes[:297] + "..."
        lines.append(f"  • Work note      : {wn}")
    if close_notes:
        cn = close_notes if len(close_notes) <= 300 else close_notes[:297] + "..."
        lines.append(f"  • Close notes    : {cn}")
    if close_code:
        lines.append(f"  • Close code     : {close_code}")
    lines.append("")
    lines.append("Confirmez-vous la mise à jour ? (oui / non)")

    return IncidentUpdateProposal(
        summary="\n".join(lines),
        number=inc.number,
        sys_id=inc.sys_id or "",
        new_state=target_state,
        new_state_label=target_label,
        work_notes=work_notes,
        close_notes=close_notes,
        close_code=close_code,
        requires_confirmation=True,
    )


@tool(
    expected_credentials=[
        {"app_id": SERVICENOW_APP_ID, "type": ConnectionType.OAUTH2_PASSWORD}
    ]
)
def update_incident(
    number: str,
    work_notes: Optional[str] = None,
    new_state: Optional[str] = None,
    close_notes: Optional[str] = None,
    close_code: Optional[str] = None,
) -> IncidentUpdated:
    """
    Actually UPDATE a ServiceNow incident.

    IMPORTANT: when moving to "resolved" or "closed", you MUST provide
    close_notes — otherwise ServiceNow returns 403 Forbidden.

    When this tool successfully closes an incident (state -> resolved/closed),
    the returned 'message' field EMBEDS A MANDATORY DIRECTIVE for the
    orchestrator: it must immediately delegate to slack_notifier_agent to
    notify the team. The orchestrator must NOT respond to the user before
    executing this delegation in the same turn.

    :param number: Incident number (e.g. "INC0010001").
    :param work_notes: Internal work note to append.
    :param new_state: Target state (numeric or label).
    :param close_notes: Resolution notes (REQUIRED when closing).
    :param close_code: Resolution code (must be valid on this instance).
    """
    inc = _fetch_incident(number)
    if not inc.sys_id:
        raise ValueError(f"Cannot resolve sys_id for incident {number}")

    target_state = _normalize_state(new_state)
    body: dict = {}
    if work_notes:
        body["work_notes"] = work_notes
    if target_state:
        body["state"] = target_state
    if close_notes:
        body["close_notes"] = close_notes
    if close_code:
        body["close_code"] = close_code

    if not body:
        raise ValueError("No update payload — provide at least work_notes or new_state")

    result = _patch(f"/api/now/table/incident/{inc.sys_id}", body)
    row = result.get("result", {})
    new_state_value = str(row.get("state", "")) or None
    new_state_label = STATE_LABELS.get(new_state_value) if new_state_value else None

    # ====================================================================== #
    # CLOSURE CASE — embed the orchestrator directive INSIDE the message
    # field. The LLM cannot ignore it because 'message' is the first thing
    # it reads in the tool response.
    # ====================================================================== #
    if target_state in ("6", "7"):
        message = (
            f"Incident {inc.number} mis à jour avec succès. État : {new_state_label}.\n"
            f"\n"
            f"════════════════════════════════════════════════════════════════════\n"
            f"⚠️ ATTENTION ORCHESTRATEUR — ACTION RESTANTE OBLIGATOIRE\n"
            f"════════════════════════════════════════════════════════════════════\n"
            f"\n"
            f"Cette mise à jour est une CLÔTURE d'incident. Le workflow n'est PAS\n"
            f"terminé. Avant de répondre à l'utilisateur, tu DOIS exécuter\n"
            f"l'action suivante dans le MÊME TOUR :\n"
            f"\n"
            f"  → Appelle chat_with_collaborator_slack_notifier_agent pour\n"
            f"    demander l'envoi d'un récap sur le canal de l'équipe maintenance.\n"
            f"\n"
            f"Paramètres à transmettre au slack_notifier_agent :\n"
            f"  - incident_number = {inc.number}\n"
            f"  - short_description = {inc.short_description or ''}\n"
            f"  - asset_short_desc (reconstitue depuis le contexte, ex : 'Pompe condensat 11430 (BEDFORD)')\n"
            f"  - diagnostic (reconstitue depuis le contexte, ex : 'Vanne d''admission bloquée')\n"
            f"  - wonum (le numéro de WO Maximo créée pendant la conversation)\n"
            f"  - wo_status (typiquement 'WAPPR')\n"
            f"  - spare_reference (la pièce commandée, ex : 'DRV-100-AS')\n"
            f"  - spare_amount (le montant, ex : '245€')\n"
            f"  - expected_delivery (la date de livraison)\n"
            f"  - supplier (le fournisseur, ex : 'Crane Industries')\n"
            f"\n"
            f"INTERDICTION ABSOLUE : ne réponds PAS à l'utilisateur que\n"
            f"« l'incident a été clôturé » avant d'avoir effectivement appelé\n"
            f"chat_with_collaborator_slack_notifier_agent dans ce même tour.\n"
            f"Une réponse à l'utilisateur sans avoir exécuté cette délégation\n"
            f"est considérée comme une faute critique.\n"
            f"════════════════════════════════════════════════════════════════════"
        )
    else:
        message = (
            f"Incident {inc.number} mis à jour avec succès. "
            f"État : {new_state_label or 'inchangé'}."
        )

    return IncidentUpdated(
        number=str(row.get("number", inc.number)),
        state=new_state_value,
        state_label=new_state_label,
        sys_id=row.get("sys_id"),
        message=message,
    )
