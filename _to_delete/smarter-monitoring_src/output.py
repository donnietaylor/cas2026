"""
Output channels for enriched incidents.
"""

from __future__ import annotations

import json
import os
import urllib.request

from models import Incident

_SEVERITY_COLORS = {
    "critical": "\033[91m",   # bright red
    "high": "\033[33m",       # yellow
    "medium": "\033[36m",     # cyan
    "low": "\033[37m",        # white
}
_RESET = "\033[0m"


def write_incident(incident: Incident) -> None:
    """Write an incident to all configured output channels."""
    _write_console(incident)
    _write_file(incident)
    _write_webhook(incident)


def _write_console(incident: Incident) -> None:
    color = _SEVERITY_COLORS.get(incident.severity, "")
    print(
        f"\n{color}[{incident.severity.upper()}] {incident.title}{_RESET}\n"
        f"  Root cause: {incident.root_cause}\n"
        f"  Action: {incident.recommended_action}\n"
        f"  Events: {', '.join(incident.related_events)}"
    )


def _write_file(incident: Incident) -> None:
    output_path = os.environ.get("OUTPUT_FILE", "output/incidents.ndjson")
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "a") as f:
        f.write(json.dumps(incident.to_dict()) + "\n")


def _write_webhook(incident: Incident) -> None:
    url = os.environ.get("WEBHOOK_URL", "")
    if not url:
        return
    data = json.dumps(incident.to_dict()).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=5):
            pass
    except Exception as exc:
        print(f"[output] Webhook delivery failed: {exc}")
