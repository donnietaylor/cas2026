# Demo 3 — Deterministic correlation

**Code:** `Get-CorrelationKey` in [`EventNormalizer.psm1`](../powershell/modules/EventNormalizer.psm1)

**This is the spine of the talk. Do not cut it.**

## Twelve lines, no AI

```
trace ID    -> provably the same request path
resource ID -> provably the same Azure resource
host label  -> probably the same machine
title       -> last resort
```

That is the entire function. First match wins, most-certain first.

## Run it

```powershell
cd powershell
.\Invoke-LocalPipeline.ps1 -Offline -ShowStages
```

Stage 2: **14 events → 5 groups.**

```
trace:4bf92f3577b34da6...                    -> 3 events
resource:.../applicationGateways/appgw-prod  -> 2 events
resource:.../virtualMachineScaleSets/vmss-web-> 4 events
resource:.../servers/sql-prod-03/databases/. -> 3 events
host:backup-01                               -> 2 events
```

## The point

Most of the noise reduction in this pipeline happens **here**, with no model, no
tokens, no latency, and no chance of hallucination.

If you sent all fourteen alerts to an LLM and asked *"which of these are related?"*,
you would pay for it, wait for it, and get a worse answer — because three of them
literally share a trace ID and four literally share a resource ID. That is not a
judgment call. That is a `GROUP BY`.

The model gets asked exactly one question, once per group, in Demo 5: *given these
already-correlated events, what is the likely root cause and how urgent is it?*
That is judgment, and it is worth a model.

## The obvious objection, and the honest answer

**"What about events that are genuinely related but share no key?"**

This pipeline will miss them, and it will file them as separate incidents. That is a
real limitation and you should say so before someone in the room says it for you.

Two mitigations worth mentioning: topology from Resource Graph can link a resource to
its dependencies (Demo 4 puts this in the grounding context, so the model *can* say
"this looks like the same incident as the one on vmss-web"), and a second enrichment
pass over the *incidents* rather than the events can merge them. Both add cost and
latency. Whether that trade is worth it depends on your alert volume, and "start
deterministic, add the expensive pass only if you need it" is the defensible default.
