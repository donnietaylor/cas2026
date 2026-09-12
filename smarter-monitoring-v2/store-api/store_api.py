"""
Store API - the demo app for Smarter Monitoring.

/checkout calls /payments over HTTP. Hit /break and /payments starts failing;
hit /fix and it recovers. Every request, dependency call and exception goes to
Application Insights through the Azure Monitor OpenTelemetry distro - all
sharing one trace ID per checkout.

    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    python store_api.py

Then, from another terminal:
    ../Break-Everything.ps1          # breaks it and fires the whole outage
    ../Break-Everything.ps1 -Fix     # puts it back

The /payments handler wraps its (imaginary) database call in a real OpenTelemetry
client span carrying server.address = sql-prod-03. That is the point of the
demo, not decoration: because the span says which host it depends on, the
pipeline can group this app's failure with sql-prod-03's failure using nothing
but a shared key. No model needed. Instrumentation earns the correlation.
"""

import os
import random
import time

from azure.monitor.opentelemetry import configure_azure_monitor

# appi-cas26-193812. Not a secret - it only allows sending telemetry.
# APPLICATIONINSIGHTS_CONNECTION_STRING overrides it if set.
CONNECTION_STRING = (
    "InstrumentationKey=5856afbc-0c15-43ef-a4a6-0d17a8385ba2;"
    "IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/;"
    "LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;"
    "ApplicationId=80ba8b2e-b019-4005-b434-485389c70eb8"
)

# The app's name in Application Insights (cloud role name).
os.environ.setdefault("OTEL_SERVICE_NAME", "store-api")

configure_azure_monitor(
    connection_string=os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", CONNECTION_STRING),
    # Keep every trace. The distro's default rate-limits to 5 traces/second.
    sampling_ratio=1.0,
)

# Import these AFTER configure_azure_monitor() so they get instrumented.
import requests  # noqa: E402
from flask import Flask, jsonify  # noqa: E402
from opentelemetry import trace  # noqa: E402

tracer = trace.get_tracer(__name__)

# The database this service depends on. It does not exist - sql-watch and
# storage-watch in Send-Event.ps1 report on it. Naming it here in a span
# attribute is what lets the pipeline connect this real app to those events.
DB_HOST = "sql-prod-03"

# 127.0.0.1, not localhost: on Windows "localhost" can try IPv6 first and add a
# multi-second delay to every call.
BASE_URL = "http://127.0.0.1:5000"

app = Flask(__name__)
state = {"broken": False}


@app.get("/checkout")
def checkout():
    time.sleep(random.uniform(0.02, 0.08))
    # This outbound call is recorded as a dependency, in the same trace.
    response = requests.post(f"{BASE_URL}/payments", json={"amount": round(random.uniform(10, 250), 2)}, timeout=5)
    response.raise_for_status()  # a failed payment fails the checkout
    return jsonify(order="placed", payment=response.json())


@app.post("/payments")
def payments():
    # A CLIENT span with db.* and server.address is what Application Insights
    # exports as a dependency with Target = sql-prod-03. peer.service is set too
    # because that is the attribute the exporter prefers when naming a target.
    with tracer.start_as_current_span(
        "SELECT payments.pending",
        kind=trace.SpanKind.CLIENT,
        attributes={
            "db.system": "mssql",
            "db.name": "payments",
            "server.address": DB_HOST,
            "server.port": 1433,
            "peer.service": DB_HOST,
        },
    ):
        time.sleep(random.uniform(0.05, 0.15))
        if state["broken"]:
            time.sleep(1.5)
            # Named, because the words are what the AI stage has to work with.
            raise TimeoutError(
                f"Payments database on {DB_HOST}: timed out waiting for a connection "
                f"from the pool (1500 ms). The pool is full and connections are "
                f"being held open waiting on disk."
            )
    return jsonify(status="approved")


@app.get("/break")
def break_payments():
    state["broken"] = True
    return jsonify(payments="broken")


@app.get("/fix")
def fix_payments():
    state["broken"] = False
    return jsonify(payments="healthy")


@app.get("/")
def status():
    return jsonify(app="store-api", payments="broken" if state["broken"] else "healthy")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, threaded=True)
