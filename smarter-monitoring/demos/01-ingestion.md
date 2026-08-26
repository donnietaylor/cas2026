# Demo 1 — Ingest: one shape from many sources

**Code:** [`powershell/modules/EventNormalizer.psm1`](../powershell/modules/EventNormalizer.psm1)

## The problem

Three monitoring sources, three completely unrelated payload shapes:

| Source | Shape |
|---|---|
| Azure Monitor | `data.essentials.{alertRule, severity, alertTargetIDs}` — severity is `Sev0`–`Sev4`, lowest is worst |
| OpenTelemetry | `resourceSpans[].scopeSpans[].spans[]` — timestamps in unix **nanoseconds** |
| Third-party webhook | whatever that vendor felt like |

Everything downstream — correlation, grounding, enrichment, dedup — needs one shape.
That is all `New-PipelineEvent` is: ten fields, no cleverness.

## Run it

```powershell
cd powershell
.\Invoke-LocalPipeline.ps1 -Offline -ShowStages
```

Stop at stage 1: **12 raw payloads → 14 events.** The count grows because one OTLP
payload carries three failing spans.

## Two things worth knowing

**Turn on the Common Alert Schema in your action groups.** It is a checkbox on the
action group, and without it every alert type delivers a differently-shaped payload —
metric alerts, log alerts and activity log alerts all differ. You end up writing a
normalizer per alert rule, forever. `ConvertFrom-AzureMonitorAlert` throws a clear
error if it does not see `data.essentials`, precisely so you find this out at
development time rather than at 3am.

**That module deliberately does not `Set-StrictMode`.** Every other module in this
pipeline does. Strict mode turns "property does not exist" into a terminating error,
and this module's whole job is reading JSON from systems that add and drop fields
whenever they like. A missing optional field has to produce a degraded event — not an
exception that drops the entire batch.

## The field that matters most

`TraceId`. It looks like just another field here. Demo 3 is where it earns its place.
