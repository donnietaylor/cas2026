# Smarter Monitoring: Building an AI-Enhanced Event Pipeline

## Session Overview

Monitoring and observability platforms generate endless alerts, but teams still have to hunt for the real problem. In this session, you'll see how to build an AI-enhanced event pipeline that turns raw telemetry from your monitoring and observability tools into actionable insight. We'll cover ingesting events from multiple sources, including environments that use OpenTelemetry, then correlating and enriching them with AI so downstream systems receive clear, prioritized incidents instead of noise, helping teams cut alert fatigue and respond faster.

## What You'll Learn

- The challenge of alert fatigue and why AI can help
- How to ingest events from multiple monitoring sources
- Working with OpenTelemetry in your pipeline
- Correlating and enriching events using AI
- Producing clear, prioritized incidents for downstream systems
- Practical patterns for reducing noise and improving response time

## Prerequisites

- Python 3.11+ or Node.js 18+
- Basic familiarity with observability concepts (metrics, logs, traces)
- Docker (for running local dependencies)

## Getting Started

```bash
cd src
pip install -r requirements.txt   # or: npm install
python pipeline.py                # or: node pipeline.js
```

## Demo Walkthrough

See the [`demos/`](./demos/) directory for step-by-step demo scripts used during the session.

1. [Demo 1 – Ingesting Events from Multiple Sources](./demos/01-ingestion.md)
2. [Demo 2 – OpenTelemetry Integration](./demos/02-otel.md)
3. [Demo 3 – AI Correlation and Enrichment](./demos/03-ai-enrichment.md)
4. [Demo 4 – Prioritized Incident Output](./demos/04-incidents.md)
5. [Demo 5 – End-to-End Pipeline](./demos/05-end-to-end.md)

## Resources

- [OpenTelemetry documentation](https://opentelemetry.io/docs/)
- [OpenTelemetry Python SDK](https://github.com/open-telemetry/opentelemetry-python)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
