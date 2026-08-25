"""
Smarter Monitoring: AI-Enhanced Event Pipeline
Cloud and AI Summit 2026

Entry point – runs the HTTP ingestion server and event processing loop.
"""

from __future__ import annotations

import json
import os
import sys
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Thread
from typing import Any

from enricher import enrich_events
from models import Event, Incident
from output import write_incident


# ---------------------------------------------------------------------------
# Event buffer (in-memory for demo purposes)
# ---------------------------------------------------------------------------

_event_buffer: list[Event] = []


# ---------------------------------------------------------------------------
# Normalizers
# ---------------------------------------------------------------------------


def normalize_alertmanager(payload: dict[str, Any]) -> list[Event]:
    """Convert an Alertmanager webhook payload to normalized Events."""
    events = []
    for alert in payload.get("alerts", []):
        labels = alert.get("labels", {})
        annotations = alert.get("annotations", {})
        events.append(
            Event(
                id=f"evt-{uuid.uuid4().hex[:8]}",
                source="alertmanager",
                severity=labels.get("severity", "info"),
                title=labels.get("alertname", "Unknown"),
                description=annotations.get("summary", ""),
                labels={k: v for k, v in labels.items() if k not in ("alertname", "severity")},
                timestamp=alert.get("startsAt", datetime.now(timezone.utc).isoformat()),
                raw=alert,
            )
        )
    return events


def normalize_otel(payload: dict[str, Any]) -> list[Event]:
    """Convert an OTLP JSON export to normalized Events (errors only)."""
    events = []
    for resource_span in payload.get("resourceSpans", []):
        for scope_span in resource_span.get("scopeSpans", []):
            for span in scope_span.get("spans", []):
                # Only surface spans that indicate errors
                status = span.get("status", {})
                if status.get("code") not in ("STATUS_CODE_ERROR", 2):
                    continue
                events.append(
                    Event(
                        id=f"evt-{uuid.uuid4().hex[:8]}",
                        source="otel",
                        severity="error",
                        title=f"Error in span: {span.get('name', 'unknown')}",
                        description=status.get("message", ""),
                        labels={},
                        timestamp=datetime.now(timezone.utc).isoformat(),
                        raw=span,
                    )
                )
    return events


# ---------------------------------------------------------------------------
# HTTP ingestion server
# ---------------------------------------------------------------------------


class IngestHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            self._respond(400, {"error": "Invalid JSON"})
            return

        if self.path == "/ingest/alertmanager":
            new_events = normalize_alertmanager(payload)
        elif self.path == "/ingest/otel":
            new_events = normalize_otel(payload)
        else:
            self._respond(404, {"error": "Unknown path"})
            return

        _event_buffer.extend(new_events)
        print(f"[ingest] +{len(new_events)} events (buffer={len(_event_buffer)})")
        self._respond(200, {"accepted": len(new_events)})

    def _respond(self, status: int, body: dict) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())

    def log_message(self, fmt, *args):  # suppress default access log
        pass


# ---------------------------------------------------------------------------
# Processing loop
# ---------------------------------------------------------------------------


def processing_loop(window_seconds: int = 60) -> None:
    import time

    print(f"[pipeline] Processing loop started (window={window_seconds}s)")
    while True:
        time.sleep(window_seconds)
        if not _event_buffer:
            continue
        batch = _event_buffer.copy()
        _event_buffer.clear()
        print(f"[pipeline] Processing {len(batch)} events…")
        incidents: list[Incident] = enrich_events(batch)
        for incident in incidents:
            write_incident(incident)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    window = int(os.environ.get("WINDOW_SECONDS", 60))

    server = HTTPServer(("0.0.0.0", port), IngestHandler)
    print(f"[pipeline] Listening on :{port}")

    thread = Thread(target=processing_loop, args=(window,), daemon=True)
    thread.start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[pipeline] Shutting down")
        sys.exit(0)
