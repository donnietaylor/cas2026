"""
AI enrichment step: correlates a batch of Events into prioritized Incidents.

Requires:
    OPENAI_API_KEY environment variable
    pip install openai
"""

from __future__ import annotations

import json
import os
import uuid
from datetime import datetime, timezone
from typing import Any

from models import Event, Incident

try:
    from openai import OpenAI
    _openai_available = True
except ImportError:
    _openai_available = False


SYSTEM_PROMPT = """\
You are an experienced SRE assistant. You will be given a JSON array of monitoring events.
Your job is to:
1. Group related events that likely share a root cause.
2. For each group, produce an incident with:
   - severity: one of "critical", "high", "medium", "low"
   - title: a concise description of the incident
   - root_cause: a 1-2 sentence explanation
   - recommended_action: a 1-2 sentence recommendation
   - related_events: list of event titles (with labels where helpful)
Return ONLY a valid JSON array of incident objects. No prose, no markdown fences."""


def _fallback_incidents(events: list[Event]) -> list[Incident]:
    """Return one incident per event when AI enrichment is unavailable."""
    now = datetime.now(timezone.utc).isoformat()
    return [
        Incident(
            id=f"inc-{uuid.uuid4().hex[:8]}",
            severity=e.severity,
            title=e.title,
            root_cause=e.description or "No AI enrichment available.",
            recommended_action="Investigate the alert manually.",
            related_events=[e.title],
            created_at=now,
        )
        for e in events
    ]


def enrich_events(events: list[Event]) -> list[Incident]:
    """Use an LLM to correlate and enrich a batch of events into incidents."""
    if not events:
        return []

    if not _openai_available or not os.environ.get("OPENAI_API_KEY"):
        print("[enricher] OpenAI not available – using fallback (1 incident per event)")
        return _fallback_incidents(events)

    client = OpenAI()
    events_json = json.dumps([e.to_dict() for e in events], indent=2)

    try:
        response = client.chat.completions.create(
            model=os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": events_json},
            ],
            temperature=0.2,
        )
        raw = response.choices[0].message.content or "[]"
        incident_dicts: list[dict[str, Any]] = json.loads(raw)
    except Exception as exc:
        print(f"[enricher] AI enrichment failed ({exc}) – using fallback")
        return _fallback_incidents(events)

    now = datetime.now(timezone.utc).isoformat()
    incidents = []
    for item in incident_dicts:
        incidents.append(
            Incident(
                id=f"inc-{uuid.uuid4().hex[:8]}",
                severity=item.get("severity", "medium"),
                title=item.get("title", "Untitled incident"),
                root_cause=item.get("root_cause", ""),
                recommended_action=item.get("recommended_action", ""),
                related_events=item.get("related_events", []),
                created_at=now,
            )
        )
    return incidents
