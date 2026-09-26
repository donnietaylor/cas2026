# Smarter Monitoring: Building an AI-Enhanced Event Pipeline

Three sources of monitoring noise land in one Event Hub. A PowerShell Function App
normalizes them, throws away the successes, and correlates what is left into
incidents **deterministically** - same fingerprint, same host, same resource. Only
then does a model get asked the one question facts cannot answer: are these
separate problems, or one problem wearing four costumes?

Most of the reduction happens before the model is involved. That is the argument.

**[→ Slides](./slides/smarter-monitoring.pptx)**

## How it works

```
store-api (Flask + OTel)  ─► App Insights ─┐
Azure Monitor alert ─► action group ───────┼─► Event Hubs ─► IngestEvents
Send-Event.ps1 ─── SAS ─────────────────────┘   monitoring-events   │
                                                                    ▼
                                            Normalize ─► drop successes ─► Correlation
                                                                    │
                                              Azure Table Storage ◄─┘
                                              RawEvents / Events / Incidents
                                                                    │
                                              AnalyzeTimer ─► Ai ───┘  (Azure OpenAI)
                                                                    │
                                              GetIncidents ◄── Azure Workbook
```

## The three sources

| # | Source | How it reaches the hub | Shape |
|---|---|---|---|
| 1 | `store-api` telemetry | instrumented with the Azure Monitor OpenTelemetry distro → App Insights → diagnostic setting `to-eventhub` | `{ records: [ { Type: AppRequests \| AppDependencies \| AppExceptions } ] }` |
| 2 | Azure Monitor alert | metric alert `app-failed-requests` → action group `ag-cas26-eventhub` | common alert schema, `data.essentials` |
| 3 | Third-party tools | `Send-Event.ps1` builds a SAS token and POSTs to the Event Hubs REST endpoint | `{ tool, title, host, severity, ... }` |

`Normalize.psm1` detects which of the three it is received and emits one shape.
The correlation keys it carries out are `TraceId` and `ParentSpanId` (OpenTelemetry,
arriving through App Insights as `operation_Id`), `ResourceId` and `Host`.

## The Function App

Flex Consumption, PowerShell 7.4, managed identity for everything it touches.

| Function | Trigger | Does |
|---|---|---|
| `IngestEvents` | Event Hub, `pipeline` consumer group, batches up to 100 | normalize → drop successes → archive raw → correlate |
| `AnalyzeTimer` | timer, every minute | runs the AI pass, but only if something changed |
| `Analyze` | `GET\|POST /api/analyze` | forces the AI pass on cue, returns what it decided |
| `GetIncidents` | `GET /api/incidents` | shapes the tables for the workbook |

Three role assignments on its identity, and nothing else: Event Hubs Data Receiver
on the hub, Storage Table Data Contributor on the account, Cognitive Services
OpenAI User on the AI resource.

## Correlation, which is the part without a model in it

**Identity is derived, not invented.** An incident's id is a hash of its primary
correlation key, so every worker that sees an event for `host:sql-prod-03` computes
the same id and writes to the same row. The hub has two partitions and hands events
to two invocations at once; with generated ids you would get three "backup overran"
incidents and a model asked to clean up after you.

Primary key order is **host > resource > service > trace**. Trace is last on
purpose: it is the most precise key and the worst grouping key, because every
request has its own.

Per event: a known fingerprint inside the window increments a count; anything else
is a new symptom. An incident that has been quiet longer than the window is revived
rather than duplicated. The window defaults to 15 minutes
(`CORRELATION_WINDOW_MINUTES`).

**The incident row stores no totals** - no event count, no severity, no headline.
Those are computed from the symptom rows on demand by `Measure-Incident`. The only
counter anywhere is `Count` on a symptom row.

Three tables: `RawEvents` (the unaggregated firehose), `Events` (one row per
symptom), `Incidents` (one row per incident, plus a `meta/analysis` marker row).

## Where the model earns its place

`Correlation.psm1` has already done everything facts allow. What it cannot do is
read *"Nightly backup of sql-prod-03 still running"* on `backup-01` and connect it
to *"Disk read latency 480 ms"* on `sql-prod-03` - those two share no key. The link
exists only in the English.

So `Ai.psm1` hands every open incident to the model in one pass and asks which are
one problem, which one is the cause, what to do first - and, just as importantly,
which are **unrelated**. A correlator that connects everything is as useless as one
that connects nothing.

Two guardrails: a cluster of one is recorded as an assessment but never counts as a
root cause, and nothing in this module creates or merges incidents. Correlation owns
identity. A model that can rewrite identity is a model that can lose your data.

## The dashboard

`workbook/incidents-workbook.json` is an Azure Workbook with four custom-endpoint
visuals, each calling `GetIncidents` with a different `view`:

| view | Visual |
|---|---|
| `raw` | every event as it arrived, newest first, deliberately unreadable - the "spot the cause" screen |
| `summary` | the funnel: events ingested → unique symptoms → correlated incidents → root causes |
| `sources` | events per reporting tool |
| `tree` | cause → incident → symptom, as a grouped grid |
| `incidents` / `symptoms` | tiles and the drill-down grid |

The endpoint decides the presentation, not the workbook. Workbooks colour and lay
out what they are given and are bad at composing text, so anything the story needs
said is a string join in PowerShell instead of a fight with a formatter.

CORS for `https://portal.azure.com` is set on the Function App itself - don't also
add the header in code, because two of them is an error in the browser.

## Running it

```powershell
Connect-AzAccount
./Deploy-Azure.ps1              # idempotent - every step checks first, then publishes
```

Then, in separate terminals:

```powershell
# the app that generates real telemetry
./store-api/.venv/Scripts/python.exe ./store-api/store_api.py
./store-api/Start-Traffic.ps1   # calls /checkout on a loop

# the outage
./Break-Everything.ps1          # breaks the app, drives traffic, fires the signals
./Show-Incidents.ps1            # what the pipeline correlated
./Break-Everything.ps1 -Fix     # put it back
./Reset-Pipeline.ps1            # empty the tables between rehearsals
```

| Script | For |
|---|---|
| `Deploy-Azure.ps1` | all Azure plumbing, then calls `Publish-Function.ps1` |
| `Publish-Function.ps1` | zips `function/` and pushes it via OneDeploy, authenticating with your sign-in token |
| `Send-Event.ps1` | the third-party source. `-List`, `-Signal <name>`, `-Story -Only sql\|cert\|noise` |
| `Break-Everything.ps1` | the whole outage in one command. `-Fix`, `-Fast`, `-NoApp`, `-NoEvents` |
| `Show-Incidents.ps1` | reads the tables directly over a short-lived read-only SAS |
| `Reset-Pipeline.ps1` | clears `Events`, `Incidents`, `RawEvents` in entity-group transactions |

## Prerequisites

- **PowerShell 7.4+** and the Az modules `Deploy-Azure.ps1` declares in `#requires`
- **Python 3.11+** for `store-api`, with `store-api/requirements.txt` installed
  (the OTel distro must be configured before Flask is imported - `store_api.py`
  does this, don't reorder it)
- An **Azure subscription**. There is no offline mode: the correlation state lives
  in Table Storage and the analysis calls Azure OpenAI. If the venue's network is a
  worry, rehearse on tethering and have screenshots.

## Things that will bite

- **The Event Hubs trigger starts from the beginning of the stream.** Retention is
  24 hours, so the first run after a publish may chew through the backlog.
  `Reset-Pipeline.ps1` first if you want the counts to start at zero.
- **`Write-Host`, not `Write-Information`.** The Functions PowerShell worker leaves
  `$InformationPreference` at `SilentlyContinue`, so `Write-Information` output is
  discarded.
- **LF line endings.** `function/` is zipped and run on a Linux Functions host;
  `.gitattributes` pins this so what runs in Azure is byte-for-byte what is in the repo.
- **Az cmdlets ignore a script's `$ErrorActionPreference`.** `Deploy-Azure.ps1` uses
  a cloned `$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'` instead.
- **`ConvertFrom-Json` turns ISO timestamps into `[datetime]`.** PowerShell 7.4 has
  no `-DateKind`, so `Normalize.psm1` puts them back as ISO UTC strings.
- **PowerShell 7.4 on Flex Consumption reaches end of support 2026-11-10.** After
  the conference, this needs revisiting.
