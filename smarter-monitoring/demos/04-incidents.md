# Demo 4 – Prioritized Incident Output

This demo shows how enriched incidents are forwarded to downstream systems.

## Output channels

- **Webhook** – POST to any URL (PagerDuty, Slack, ServiceNow, etc.)
- **File** – Write NDJSON to disk for audit/replay
- **Console** – Human-readable output for demos

## Incident schema

```json
{
  "id": "inc-20260825-001",
  "severity": "critical",
  "title": "Web tier overload causing 5xx errors",
  "root_cause": "Both web-01 and web-02 are at high CPU...",
  "recommended_action": "Scale out the web tier...",
  "related_events": ["HighCPU/web-01", "HighCPU/web-02", "HTTP5xxRate/lb-01"],
  "created_at": "2026-08-25T00:01:00Z",
  "source_window": "2026-08-25T00:00:00Z/2026-08-25T00:01:00Z"
}
```

## Steps

### 1. Configure output channels

Set environment variables or edit `config.yaml`:
```yaml
outputs:
  webhook:
    enabled: true
    url: https://hooks.example.com/incidents
  file:
    enabled: true
    path: output/incidents.ndjson
  console:
    enabled: true
```

### 2. Trigger a test incident

```bash
python src/pipeline.py --replay data/sample_events.json
```

### 3. Observe the output

The console will show a summary like:
```
[CRITICAL] Web tier overload causing 5xx errors
  Root cause: Both web-01 and web-02 are at high CPU...
  Action: Scale out the web tier...
  Events: HighCPU/web-01, HighCPU/web-02, HTTP5xxRate/lb-01
```
