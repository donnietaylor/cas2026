"""
A deliberately small instrumented app, so Demo 2 has a real trace to look at.

    pip install -r requirements.txt
    $env:APPLICATIONINSIGHTS_CONNECTION_STRING = "<from the portal>"
    python app.py --scenario checkout-failure

The point of this file is one thing: produce three spans in one trace where the
failure is at the bottom of the call stack. That trace ID is what makes the
correlation in Demo 3 deterministic instead of a guess.
"""

import argparse
import os
import random
import time

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

if os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    configure_azure_monitor(logger_name="checkout")
else:
    # No App Insights? Still emit spans over OTLP so the collector path works.
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

    provider = TracerProvider()
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)

tracer = trace.get_tracer("checkout-api")


def checkout_failure() -> None:
    """The scenario from the recorded demo: pool exhaustion under the checkout path."""
    with tracer.start_as_current_span("POST /checkout") as root:
        root.set_attribute("http.method", "POST")
        root.set_attribute("http.route", "/checkout")
        root.set_attribute("enduser.id", "cust-88213")

        with tracer.start_as_current_span("payments.authorize") as payment:
            payment.set_attribute("peer.service", "payments-api")
            time.sleep(0.15)

            with tracer.start_as_current_span("orders.db.insert") as db:
                db.set_attribute("db.system", "mssql")
                db.set_attribute("db.name", "orders")
                db.set_attribute("peer.service", "sql-prod-03")
                time.sleep(0.4)
                db.set_status(Status(StatusCode.ERROR, "Timeout expired; connection pool exhausted"))
                db.record_exception(TimeoutError("Timeout expired. The timeout period elapsed "
                                                 "prior to obtaining a connection from the pool."))

            payment.set_status(Status(StatusCode.ERROR, "Connection reset by peer"))

        root.set_attribute("http.status_code", 500)
        root.set_status(Status(StatusCode.ERROR, "Upstream timeout calling payments"))

    print("Emitted 1 trace / 3 spans for scenario 'checkout-failure'.")


def healthy_traffic(count: int) -> None:
    """Background noise, so the failing trace isn't the only thing in the portal."""
    for _ in range(count):
        with tracer.start_as_current_span("POST /checkout") as span:
            span.set_attribute("http.method", "POST")
            span.set_attribute("http.status_code", 200)
            time.sleep(random.uniform(0.02, 0.09))
    print(f"Emitted {count} healthy traces.")


SCENARIOS = {"checkout-failure": checkout_failure}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", default="checkout-failure", choices=list(SCENARIOS))
    parser.add_argument("--warmup", type=int, default=5, help="healthy traces to emit first")
    args = parser.parse_args()

    if args.warmup:
        healthy_traffic(args.warmup)
    SCENARIOS[args.scenario]()

    # BatchSpanProcessor is asynchronous. Exit too fast and the spans never ship -
    # which looks exactly like "the demo is broken."
    print("Flushing...")
    time.sleep(6)
