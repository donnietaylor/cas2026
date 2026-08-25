# Demo 3 – AI Correlation and Enrichment

This demo shows how the pipeline uses an LLM to correlate related events and enrich them with context.

## How it works

1. Events accumulate in a time window (default: 60 seconds)
2. The pipeline sends the window to an LLM with a structured prompt
3. The LLM groups related events, assigns a root cause, and produces a prioritized incident

## Example prompt (simplified)

```
You are an SRE assistant. Given the following monitoring events, identify groups of
related events, determine a likely root cause for each group, assign a severity
(critical/high/medium/low), and return a JSON array of incidents.

Events:
[
  { "title": "HighCPU", "instance": "web-01", "severity": "warning" },
  { "title": "HighCPU", "instance": "web-02", "severity": "warning" },
  { "title": "HTTP5xxRate", "instance": "lb-01", "severity": "critical" },
  { "title": "DiskLow", "instance": "db-01", "severity": "info" }
]
```

## Example output

```json
[
  {
    "severity": "critical",
    "title": "Web tier overload causing 5xx errors",
    "root_cause": "Both web-01 and web-02 are at high CPU, likely causing the elevated 5xx rate on lb-01.",
    "related_events": ["HighCPU/web-01", "HighCPU/web-02", "HTTP5xxRate/lb-01"],
    "recommended_action": "Scale out the web tier and investigate the traffic spike."
  },
  {
    "severity": "low",
    "title": "Low disk on db-01",
    "root_cause": "Disk utilization approaching threshold on db-01.",
    "related_events": ["DiskLow/db-01"],
    "recommended_action": "Review disk usage and clean up old data or expand storage."
  }
]
```

## Steps

### 1. Set your OpenAI API key

```bash
export OPENAI_API_KEY=sk-...
```

### 2. Run the enrichment module

```bash
python src/enricher.py --input data/sample_events.json
```
