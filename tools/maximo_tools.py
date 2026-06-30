"""
WatsonX Orchestrate ADK tools for IBM Maximo Application Suite (MAS / SaaS).

Demo scope (v2 — multi-agent):
  Read tools (diagnostic agent):
    - search_assets_by_keyword       : find assets without knowing the assetnum
    - get_work_orders_for_asset      : retrieve work orders for an asset
    - get_worklogs_for_workorder     : read intervention notes
    - list_asset_attachments         : list documents attached to an asset
    - get_attachment_text            : extract text from a PDF/text attachment

  Write tools (planning agent, two-step confirmation pattern):
    - propose_work_order             : DRY-RUN, builds and returns a summary, NO API call
    - create_work_order              : actual POST to Maximo, only after explicit user confirmation
"""

import base64
import io
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


MAXIMO_APP_ID = "maximo_conn"


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def _get_connection():
    return connections.api_key_auth(MAXIMO_APP_ID)


def _base_url() -> str:
    conn = _get_connection()
    url = conn.url.rstrip("/")
    if not url:
        raise RuntimeError("url is not set in connection")
    return url


def _headers(content_type: Optional[str] = None) -> dict:
    conn = _get_connection()
    apikey = conn.api_key
    if not apikey:
        raise RuntimeError("api_key is not set in connection")
    headers = {
        "apikey": apikey,
        "Accept": "application/json",
        "x-public-uri": f"{_base_url()}/api",
    }
    if content_type:
        headers["Content-Type"] = content_type
    return headers


def _get(path: str, params: Optional[dict] = None) -> requests.Response:
    url = f"{_base_url()}/api/{path.lstrip('/')}"
    resp = requests.get(url, headers=_headers(), params=params or {}, timeout=60, verify=False)
    resp.raise_for_status()
    return resp


def _post(path: str, body: dict, params: Optional[dict] = None) -> requests.Response:
    url = f"{_base_url()}/api/{path.lstrip('/')}"
    resp = requests.post(
        url,
        headers=_headers("application/json"),
        params=params or {},
        data=json.dumps(body),
        timeout=60,
        verify=False,
    )
    resp.raise_for_status()
    return resp


def _resolve_asset_restid(assetnum: str, siteid: Optional[str] = None) -> str:
    where = f'assetnum="{assetnum}"'
    if siteid:
        where += f' and siteid="{siteid}"'
    resp = _get(
        "os/mxapiasset",
        {"oslc.where": where, "oslc.select": "assetnum,siteid", "lean": 1},
    )
    members = resp.json().get("member", [])
    if not members:
        raise ValueError(f"No asset found for assetnum={assetnum} site={siteid}")
    href = members[0].get("href", "")
    return href.rstrip("/").split("/")[-1]


def _strip_html(text: Optional[str]) -> Optional[str]:
    if not text:
        return text
    return re.sub(r"<[^>]+>", "", text).strip()


# --------------------------------------------------------------------------- #
# Output schemas
# --------------------------------------------------------------------------- #

class Asset(BaseModel):
    assetnum: str = Field(description="Asset number")
    description: Optional[str] = Field(None, description="Asset description")
    siteid: Optional[str] = Field(None, description="Site id")
    location: Optional[str] = Field(None, description="Location code")
    status: Optional[str] = Field(None, description="Asset status")


class WorkOrder(BaseModel):
    wonum: str = Field(description="Work order number")
    description: Optional[str] = Field(None, description="Short description")
    status: Optional[str] = Field(None, description="Work order status")
    worktype: Optional[str] = Field(None, description="Type of work")
    wopriority: Optional[int] = Field(None, description="Priority (lower = more urgent)")
    statusdate: Optional[str] = Field(None, description="Last status change date (ISO)")
    schedstart: Optional[str] = Field(None, description="Scheduled start date (ISO)")
    targstartdate: Optional[str] = Field(None, description="Target start date (ISO)")


class WorkLogEntry(BaseModel):
    logtype: Optional[str] = Field(None, description="Worklog type")
    description: Optional[str] = Field(None, description="Worklog summary")
    details: Optional[str] = Field(None, description="Long description / details")
    createby: Optional[str] = Field(None, description="Author")
    createdate: Optional[str] = Field(None, description="Creation date (ISO)")


class Attachment(BaseModel):
    id: str = Field(description="Attachment (doclink) id")
    file_name: Optional[str] = Field(None, description="File name")
    description: Optional[str] = Field(None, description="Document description")
    href: Optional[str] = Field(None, description="Link to the file content")


class WorkOrderProposal(BaseModel):
    """A proposed work order to be confirmed by the user before actual creation."""
    summary: str = Field(description="Human-readable summary to show to the user")
    assetnum: str
    siteid: str
    description: str
    worktype: str = Field(description="PM, CM, EM, etc.")
    wopriority: int = Field(description="1=critical ... 5+=low")
    targstartdate: Optional[str] = None
    requires_confirmation: bool = Field(True, description="Always true")


class WorkOrderCreated(BaseModel):
    wonum: str = Field(description="Newly created work order number")
    status: Optional[str] = Field(None, description="Initial status (usually WAPPR)")
    href: Optional[str] = Field(None, description="REST URL of the created work order")
    message: str = Field(description="Confirmation message")


# --------------------------------------------------------------------------- #
# READ TOOLS — diagnostic agent
# --------------------------------------------------------------------------- #

@tool(
    expected_credentials=[
        {"app_id": MAXIMO_APP_ID, "type": ConnectionType.API_KEY_AUTH}
    ]
)
def search_assets_by_keyword(keyword: str, limit: int = 10) -> List[Asset]:
    """
    Search for assets in Maximo by keyword. Matches the keyword against the
    asset description (substring, case-insensitive). Use whenever the user
    refers to an asset without knowing its exact assetnum (e.g. "the pump in
    the boiler room", "find pumps", "condensate equipment").

    Note: the Maximo demo dataset (BEDFORD) is in English. For French queries
    like "pompe", search "pump" instead.

    If the user already knows the exact assetnum, use get_work_orders_for_asset
    or list_asset_attachments directly with that number.

    :param keyword: Text to search for in asset descriptions (English on BEDFORD).
    :param limit: Maximum number of results (default 10).
    :returns: A list of matching assets.
    """
    safe = keyword.strip().replace('"', '')
    where = f'description="%{safe}%"'
    resp = _get(
        "os/mxapiasset",
        {
            "oslc.where": where,
            "oslc.select": "assetnum,description,siteid,location,status",
            "oslc.pageSize": limit,
            "lean": 1,
        },
    )
    members = resp.json().get("member", [])
    return [
        Asset(
            assetnum=str(m.get("assetnum")),
            description=m.get("description"),
            siteid=m.get("siteid"),
            location=m.get("location"),
            status=m.get("status"),
        )
        for m in members
    ]

@tool(
    expected_credentials=[
        {"app_id": MAXIMO_APP_ID, "type": ConnectionType.API_KEY_AUTH}
    ]
)
def get_work_orders_for_asset(
    assetnum: str,
    siteid: Optional[str] = None,
    limit: int = 10,
) -> List[WorkOrder]:
    """Retrieve recent work orders for a given asset, ordered by status date desc."""
    where = f'assetnum="{assetnum}"'
    if siteid:
        where += f' and siteid="{siteid}"'
    resp = _get(
        "os/mxapiwodetail",
        {
            "oslc.where": where,
            "oslc.select": "wonum,description,status,worktype,wopriority,statusdate,schedstart,targstartdate,assetnum",
            "oslc.orderBy": "-statusdate",
            "oslc.pageSize": limit,
            "lean": 1,
        },
    )
    members = resp.json().get("member", [])
    return [
        WorkOrder(
            wonum=str(m.get("wonum")),
            description=m.get("description"),
            status=m.get("status"),
            worktype=m.get("worktype"),
            wopriority=m.get("wopriority"),
            statusdate=m.get("statusdate"),
            schedstart=m.get("schedstart"),
            targstartdate=m.get("targstartdate"),
        )
        for m in members
    ]


@tool(
    expected_credentials=[
        {"app_id": MAXIMO_APP_ID, "type": ConnectionType.API_KEY_AUTH}
    ]
)
def get_worklogs_for_workorder(wonum: str, siteid: Optional[str] = None) -> List[WorkLogEntry]:
    """
    Read worklog entries for a work order. Use whenever the user asks for
    details, a summary, or what happened on a work order.
    """
    where = f'wonum="{wonum}"'
    if siteid:
        where += f' and siteid="{siteid}"'
    resp = _get(
        "os/mxapiwodetail",
        {
            "oslc.where": where,
            "oslc.select": "wonum,worklog{logtype,description,description_longdescription,createby,createdate}",
            "lean": 1,
        },
    )
    members = resp.json().get("member", [])
    if not members:
        return []
    worklogs = members[0].get("worklog", []) or []
    return [
        WorkLogEntry(
            logtype=w.get("logtype"),
            description=_strip_html(w.get("description")),
            details=_strip_html(w.get("description_longdescription")),
            createby=w.get("createby"),
            createdate=w.get("createdate"),
        )
        for w in worklogs
    ]


@tool(
    expected_credentials=[
        {"app_id": MAXIMO_APP_ID, "type": ConnectionType.API_KEY_AUTH}
    ]
)
def list_asset_attachments(assetnum: str, siteid: Optional[str] = None) -> List[Attachment]:
    """List documents attached to an asset (manuals, photos, procedures)."""
    rest_id = _resolve_asset_restid(assetnum, siteid)
    resp = _get(f"os/mxapiasset/{rest_id}/doclinks", {"lean": 1})
    members = resp.json().get("member", [])
    out: List[Attachment] = []
    for m in members:
        described = m.get("describedBy", {}) or {}
        out.append(
            Attachment(
                id=str(described.get("identifier") or m.get("identifier") or ""),
                file_name=described.get("fileName"),
                description=described.get("description"),
                href=m.get("href"),
            )
        )
    return out


@tool(
    expected_credentials=[
        {"app_id": MAXIMO_APP_ID, "type": ConnectionType.API_KEY_AUTH}
    ]
)
def get_attachment_text(
    assetnum: str,
    attachment_id: str,
    siteid: Optional[str] = None,
    max_chars: int = 20000,
) -> str:
    """Fetch the textual content of an asset attachment for Q&A. Supports text and PDF."""
    rest_id = _resolve_asset_restid(assetnum, siteid)
    url = f"{_base_url()}/api/os/mxapiasset/{rest_id}/doclinks/{attachment_id}"
    resp = requests.get(url, headers=_headers(), timeout=120, verify=False)
    resp.raise_for_status()

    content_type = resp.headers.get("Content-Type", "").lower()
    text = ""
    if "pdf" in content_type or resp.content[:4] == b"%PDF":
        try:
            from pypdf import PdfReader
            reader = PdfReader(io.BytesIO(resp.content))
            text = "\n".join((page.extract_text() or "") for page in reader.pages)
        except Exception as exc:
            return f"[Could not extract PDF text: {exc}]"
    elif content_type.startswith("text") or content_type == "":
        text = resp.text
    else:
        return f"[Unsupported attachment content type: {content_type or 'unknown'}]"
    return text[:max_chars]


# --------------------------------------------------------------------------- #
# WRITE TOOLS — planning agent (two-step confirmation pattern)
# --------------------------------------------------------------------------- #

@tool(
    expected_credentials=[
        {"app_id": MAXIMO_APP_ID, "type": ConnectionType.API_KEY_AUTH}
    ]
)
def propose_work_order(
    assetnum: str,
    description: str,
    worktype: str = "CM",
    wopriority: int = 3,
    siteid: Optional[str] = None,
    targstartdate: Optional[str] = None,
) -> WorkOrderProposal:
    """
    Build a work order PROPOSAL that the user must explicitly confirm before
    actual creation. This tool does NOT write to Maximo — it only validates
    the asset exists and returns a human-readable summary.

    ALWAYS call this tool BEFORE create_work_order. Show the summary to the user,
    ask them to confirm explicitly ("oui", "yes", "confirme", "go", "valide")
    before calling create_work_order with the same parameters.

    :param assetnum: Asset number (e.g. "11430").
    :param description: Short description of the work (max ~100 chars).
    :param worktype: PM (preventive), CM (corrective, default), EM (emergency).
    :param wopriority: 1=critical, 2=high, 3=medium (default), 4-5+=low.
    :param siteid: Site id (auto-resolved from the asset if omitted).
    :param targstartdate: Target start date in ISO 8601 (e.g. "2025-12-15T08:00:00").
    :returns: A proposal with a human-readable summary; await user confirmation.
    """
    where = f'assetnum="{assetnum}"'
    if siteid:
        where += f' and siteid="{siteid}"'
    resp = _get(
        "os/mxapiasset",
        {"oslc.where": where, "oslc.select": "assetnum,siteid,description", "lean": 1},
    )
    members = resp.json().get("member", [])
    if not members:
        raise ValueError(f"Asset {assetnum} not found in Maximo. Cannot propose a work order.")
    resolved_site = siteid or members[0].get("siteid")
    asset_desc = members[0].get("description") or ""

    priority_label = {1: "critique", 2: "haute", 3: "moyenne", 4: "faible"}.get(wopriority, "très faible")
    worktype_label = {"PM": "Maintenance préventive", "CM": "Maintenance corrective",
                       "EM": "Urgence"}.get(worktype.upper(), worktype)

    lines = [
        "Proposition de création de work order — à confirmer :",
        f"  • Asset       : {assetnum} ({asset_desc})",
        f"  • Site        : {resolved_site}",
        f"  • Description : {description}",
        f"  • Type        : {worktype.upper()} ({worktype_label})",
        f"  • Priorité    : {wopriority} ({priority_label})",
    ]
    if targstartdate:
        lines.append(f"  • Date cible  : {targstartdate}")
    lines.append("")
    lines.append("Confirmez-vous la création ? (oui / non)")
    summary = "\n".join(lines)

    return WorkOrderProposal(
        summary=summary,
        assetnum=assetnum,
        siteid=resolved_site,
        description=description,
        worktype=worktype.upper(),
        wopriority=wopriority,
        targstartdate=targstartdate,
        requires_confirmation=True,
    )


@tool(
    expected_credentials=[
        {"app_id": MAXIMO_APP_ID, "type": ConnectionType.API_KEY_AUTH}
    ]
)
def create_work_order(
    assetnum: str,
    description: str,
    worktype: str = "CM",
    wopriority: int = 3,
    siteid: Optional[str] = None,
    targstartdate: Optional[str] = None,
) -> WorkOrderCreated:
    """
    Actually CREATE a new work order in Maximo. This writes to the production system.

    DO NOT CALL DIRECTLY. The required workflow is:
      1. Call propose_work_order first.
      2. Show the summary and obtain EXPLICIT user confirmation.
      3. Only then call create_work_order with the same parameters.
    """
    if not siteid:
        resp = _get(
            "os/mxapiasset",
            {"oslc.where": f'assetnum="{assetnum}"', "oslc.select": "siteid", "lean": 1},
        )
        members = resp.json().get("member", [])
        if not members:
            raise ValueError(f"Asset {assetnum} not found, cannot create work order")
        siteid = members[0].get("siteid")

    body = {
        "assetnum": assetnum,
        "siteid": siteid,
        "description": description,
        "worktype": worktype.upper(),
        "wopriority": wopriority,
    }
    if targstartdate:
        body["targstartdate"] = targstartdate

    # Request that Maximo returns the created record in the response body
    resp = _post(
        "os/mxapiwodetail",
        body,
        params={"lean": 1, "properties": "*"},
    )

    # Maximo may return either:
    #  - a JSON body with the created record (when properties=* works), or
    #  - an empty body with a Location header pointing to the created resource.
    wonum = None
    status = None
    href = None

    if resp.content:
        try:
            data = resp.json()
            wonum = data.get("wonum")
            status = data.get("status")
            href = data.get("href")
        except ValueError:
            pass  # not JSON, fall through to Location header

    # Fallback: parse Location header and GET the new record
    if not wonum:
        location = resp.headers.get("Location") or resp.headers.get("location")
        if location:
            href = location
            # Re-fetch the created record to get the wonum
            try:
                detail = requests.get(
                    location,
                    headers=_headers(),
                    params={"lean": 1, "oslc.select": "wonum,status"},
                    timeout=30,
                    verify=False,
                )
                detail.raise_for_status()
                d = detail.json()
                wonum = d.get("wonum")
                status = d.get("status")
            except Exception:
                pass

    if not wonum:
        # Last-resort: query the most recent WO on this asset
        try:
            resp2 = _get(
                "os/mxapiwodetail",
                {
                    "oslc.where": f'assetnum="{assetnum}" and description="{description}"',
                    "oslc.select": "wonum,status",
                    "oslc.orderBy": "-statusdate",
                    "oslc.pageSize": 1,
                    "lean": 1,
                },
            )
            members = resp2.json().get("member", [])
            if members:
                wonum = members[0].get("wonum")
                status = members[0].get("status")
        except Exception:
            pass

    return WorkOrderCreated(
        wonum=str(wonum) if wonum else "(numéro non retourné par Maximo)",
        status=status,
        href=href,
        message=(
            f"Work order créée avec succès sur l'asset {assetnum} (site {siteid})."
            + (f" Numéro : {wonum}." if wonum else "")
            + (f" Statut initial : {status}." if status else "")
        ),
    )