# Demo 2 – OpenTelemetry Integration

This demo shows how to ingest OpenTelemetry spans and convert them into pipeline events.

## Steps

### 1. Configure the OTel Collector

`otel-collector-config.yaml`:
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

exporters:
  otlphttp:
    endpoint: http://localhost:8080/ingest/otel

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [otlphttp]
```

### 2. Start the collector

```bash
docker run -p 4317:4317 -p 4318:4318 \
  -v $(pwd)/otel-collector-config.yaml:/etc/otelcol/config.yaml \
  otel/opentelemetry-collector:latest
```

### 3. Send a test trace

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor

provider = TracerProvider()
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer("demo")
with tracer.start_as_current_span("checkout") as span:
    span.set_attribute("error", True)
    span.set_attribute("http.status_code", 500)
```

### 4. Observe the pipeline event

Errors in OTel spans are automatically converted to pipeline events with `severity: error`.
