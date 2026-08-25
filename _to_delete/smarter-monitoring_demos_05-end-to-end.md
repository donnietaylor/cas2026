# Demo 5 – End-to-End Pipeline

This demo runs the complete pipeline from raw events to prioritized incidents.

## Architecture

```
[Alertmanager]  ─┐
[PagerDuty]      ├─► Ingestion Layer ──► Normalizer ──► Time Window Buffer
[OTel Collector] ┘                                            │
                                                              ▼
                                                       AI Enrichment
                                                              │
                                                              ▼
                                              [Webhook / File / Console Output]
```

## Steps

### 1. Start all services

```bash
docker compose up -d
```

### 2. Send a burst of simulated events

```bash
python src/simulate.py --scenario web-outage
```

This sends a realistic sequence of events representing a web tier outage.

### 3. Watch the pipeline in action

```bash
docker compose logs -f pipeline
```

You'll see:
- Raw events arriving from multiple sources
- Events normalized to the common schema
- Batches sent to the AI enrichment step
- Prioritized incidents produced and forwarded

### 4. Review the output

```bash
cat output/incidents.ndjson | python -m json.tool
```

## Key Takeaway

A single pipeline can ingest noisy telemetry from any source, use AI to find signal in the noise, and deliver clear, actionable incidents — without any manual correlation.
