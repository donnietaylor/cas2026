# Smarter Monitoring: Building an AI-Enhanced Event Pipeline

> Correlate deterministically. Spend the AI only on the part that needs judgment.

An event pipeline that takes Azure Monitor alerts, OpenTelemetry spans and
third-party webhooks, and produces deduplicated, ServiceNow-shaped incidents.

**[→ Run of show](./demos/00-run-of-show.md)** · **[→ Azure setup](./docs/azure-setup.md)** · **[→ Slides](./slides/session2-smarter-monitoring.pptx)**

Demo walkthroughs: [1 Ingest](./demos/01-ingestion.md) · [2 OpenTelemetry](./demos/02-otel.md) · [3 Correlation](./demos/03-correlation.md) · [4 Grounding](./demos/04-grounding.md) · [5 Enrichment](./demos/05-enrichment.md) · [6 Output](./demos/06-output.md)

## Architecture

```
Azure Monitor alerts ──┐
OTel Collector / spans ─┼─► Event Hubs ─► PowerShell Function (Event Hub trigger)
Third-party webhooks ──┘                        │
                                    ┌───────────┴───────────┐
                                    │ 1. normalize          │  one Event shape
                                    │ 2. correlate          │  trace ID / resource ID
                                    │ 3. ground             │  Resource Graph + KQL
                                    │ 4. enrich             │  Azure OpenAI
                                    │ 5. dedup + publish    │  fingerprint
                                    └───────────┬───────────┘
                                                ▼
                                   ServiceNow-shaped incident
```

**Step 2 is the one that matters.** On the recorded scenario it takes 14 events down
to 5 groups with no model involved, because four of those events share an OTel trace
ID and six share an Azure resource ID. Asking an LLM "are these related?" when the
answer is already in the data is paying a model to do a `GROUP BY`.

The model is asked one question, once per group: *given these correlated events and
these grounding facts, what is the likely root cause and how urgent is it?* That is
judgment, and it's worth a model.

## Quick start (no Azure needed)

```powershell
cd powershell
.\Invoke-LocalPipeline.ps1 -Offline -ShowStages
```

```
[1] Ingested and normalized 14 events from 12 raw payloads.
[2] Deterministic correlation: 14 events -> 5 groups (no AI involved).
[3] AI enrichment (recorded): 5 groups -> 5 incidents.
[4] Publishing to sinks...
```

Run it a second time and it publishes zero — fingerprint suppression working.

Drop `-Offline` to call Azure OpenAI for real (set `AZURE_OPENAI_ENDPOINT` and
`AZURE_OPENAI_DEPLOYMENT` first).

## Layout

| Path | What |
|---|---|
| `function/IngestBatch/` | Event Hub triggered entry point |
| `powershell/modules/EventNormalizer.psm1` | Normalizers + **`Get-CorrelationKey`** |
| `powershell/modules/Grounding.psm1` | Resource Graph, deployments, Log Analytics |
| `powershell/modules/AiEnrichment.psm1` | Azure OpenAI with Structured Outputs |
| `powershell/modules/IncidentSink.psm1` | ServiceNow payload, dedup, sinks |
| `powershell/Invoke-LocalPipeline.ps1` | Local replay harness |
| `powershell/Send-TestEvent.ps1` | Replay a scenario into the real Event Hub |
| `otel-demo/` | Instrumented app + Collector config |
| `data/scenario-web-outage.json` | The recorded outage, with recorded AI responses |
| `Preflight.ps1` | Thirty-minutes-before checklist; verifies the offline path works |
| `slides/build-session2.js` | Regenerates the deck (`node build-session2.js`) |

## Design decisions worth defending

- **The Event Hub batch is the correlation window.** No Durable Functions, no state
  store. If you need a guaranteed wall-clock window, that's a Stream Analytics job in
  front of the Function — not a timer inside it.
- **Structured Outputs, not "please return JSON."** `strict: true` against a JSON
  Schema. No fence-stripping, no parse in a try/catch that drops incidents at 3am.
- **Degrade to dumb, never to quiet.** If Azure OpenAI is down, `New-UnenrichedIncident`
  still raises a low-confidence ticket. A pipeline that drops events when the model is
  unavailable fails silently during exactly the outages that take out the model.
- **AI output is labelled as AI output.** `work_notes` is prefixed
  `[AI-GENERATED ANALYSIS - confidence: x]`. Never launder a guess into a fact.
- **`EventNormalizer.psm1` deliberately does not use `Set-StrictMode`.** It parses
  JSON from systems that add and drop fields at will; a missing optional field must
  degrade an event, not throw and drop the batch.
