# Demo 6 — ServiceNow output, dedup, and failure modes

**Code:** [`powershell/modules/IncidentSink.psm1`](../powershell/modules/IncidentSink.psm1)

> ServiceNow is the target here, but nothing is wired to a live instance. We emit the
> exact payload its Table API expects and POST it to a webhook you can watch. The
> interesting part is the shape and the suppression, not the credentials.

## Two fields carry the weight

**`correlation_id`** gets our fingerprint — a SHA-256 over the sorted
`Title|ResourceId` pairs in the group. ServiceNow dedups on this natively: post the
same `correlation_id` twice and it updates the existing ticket instead of opening a
second one. Belt and braces with our own suppression window.

**`work_notes`** is prefixed:

```
[AI-GENERATED ANALYSIS - confidence: high]
```

Never launder a model's guess into something that reads like an established fact. The
engineer must be able to tell at a glance which parts a machine wrote — especially
when the confidence is `low`.

## Severity mapping

ServiceNow urgency/impact are `1=High, 2=Medium, 3=Low` — inverted from what most
people expect, and the mapping lives in `$script:SeverityMap` rather than being
scattered through the code.

## Run it twice

```powershell
cd powershell
.\Invoke-LocalPipeline.ps1 -Offline    # 5 incidents published
.\Invoke-LocalPipeline.ps1 -Offline    # 0 incidents published
```

Second run publishes **zero** — every fingerprint is inside the 60-minute suppression
window.

> Without this you open a new ticket every window for the same ongoing problem, and
> you have automated alert fatigue rather than fixing it. Which is a very different
> conference talk.

To reset between rehearsals:

```powershell
Remove-Item $env:INCIDENT_STATE_DIR -Recurse -Force
```

`Preflight.ps1` checks this. It is the single most likely thing to make your cold
open publish nothing in front of four hundred people.

## Production gap, stated honestly

Suppression state is on local disk here. In the deployed Function that belongs in
**Table Storage or Cosmos DB** — Consumption plan instances come and go, and
per-instance local state means duplicate tickets the moment you scale past one
worker. Say this out loud; it is the first thing a good engineer in the room will ask.

## Ordering

Incidents publish **severity-first**, not group order. The whole promise of the
pipeline is that on-call reads the top of the list and stops — so the top of the list
had better be the thing that matters.
