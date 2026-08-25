"""
Event simulator – sends realistic alert bursts to the pipeline for demos.

Usage:
    python simulate.py --scenario web-outage
"""

from __future__ import annotations

import argparse
import json
import time
import urllib.request
from datetime import datetime, timezone

BASE_URL = "http://localhost:8080"

SCENARIOS: dict[str, list[dict]] = {
    "web-outage": [
        {
            "alerts": [
                {
                    "status": "firing",
                    "labels": {"alertname": "HighCPU", "severity": "warning", "instance": "web-01"},
                    "annotations": {"summary": "CPU usage above 90% for 5 minutes"},
                    "startsAt": datetime.now(timezone.utc).isoformat(),
                }
            ]
        },
        {
            "alerts": [
                {
                    "status": "firing",
                    "labels": {"alertname": "HighCPU", "severity": "warning", "instance": "web-02"},
                    "annotations": {"summary": "CPU usage above 90% for 5 minutes"},
                    "startsAt": datetime.now(timezone.utc).isoformat(),
                }
            ]
        },
        {
            "alerts": [
                {
                    "status": "firing",
                    "labels": {"alertname": "HTTP5xxRate", "severity": "critical", "instance": "lb-01"},
                    "annotations": {"summary": "5xx error rate above 10% on lb-01"},
                    "startsAt": datetime.now(timezone.utc).isoformat(),
                }
            ]
        },
        {
            "alerts": [
                {
                    "status": "firing",
                    "labels": {"alertname": "DiskLow", "severity": "info", "instance": "db-01"},
                    "annotations": {"summary": "Disk utilization above 80% on db-01"},
                    "startsAt": datetime.now(timezone.utc).isoformat(),
                }
            ]
        },
    ]
}


def post(path: str, payload: dict) -> None:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        print(f"  → {resp.status} {path}")


def run_scenario(name: str) -> None:
    events = SCENARIOS.get(name)
    if events is None:
        print(f"Unknown scenario: {name}. Available: {list(SCENARIOS.keys())}")
        return
    print(f"Running scenario: {name} ({len(events)} alert batches)")
    for batch in events:
        post("/ingest/alertmanager", batch)
        time.sleep(0.5)
    print("Done. Wait for the processing window to fire.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", default="web-outage")
    args = parser.parse_args()
    run_scenario(args.scenario)
