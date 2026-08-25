# Demo 1 – Ingesting Events from Multiple Sources

This demo shows how to ingest monitoring events from different sources into a single pipeline.

## Sources covered

- Prometheus Alertmanager webhooks
- PagerDuty webhook events
- A simulated flat-file log source

## Steps

### 1. Start the ingestion server

```bash
cd src
python pipeline.py
```

### 2. Send a test alert (Alertmanager format)

```bash
curl -X POST http://localhost:8080/ingest/alertmanager \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": { "alertname": "HighCPU", "severity": "warning", "instance": "web-01" },
      "annotations": { "summary": "CPU usage above 90% for 5 minutes" },
      "startsAt": "2026-08-25T00:00:00Z"
    }]
  }'
```

### 3. Observe the normalized event

The pipeline normalizes all sources into a common `Event` schema:

```json
{
  "id": "evt-001",
  "source": "alertmanager",
  "severity": "warning",
  "title": "HighCPU",
  "description": "CPU usage above 90% for 5 minutes",
  "labels": { "instance": "web-01" },
  "timestamp": "2026-08-25T00:00:00Z",
  "raw": { ... }
}
```
