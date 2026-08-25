# Azure setup

Resources are provisioned by hand in the portal for this session (no Bicep by
choice — see the note at the bottom). This document is the checklist, the
verification commands, and the teardown list.

**Estimated cost if left running for a month: roughly $80–140 USD**, dominated by
Azure OpenAI usage and Log Analytics ingestion. For a conference demo, stand it up
a few days before and tear it down the same week. See [Teardown](#teardown) —
please actually do the teardown.

---

## What you need

| # | Resource | SKU / tier | Why |
|---|----------|-----------|-----|
| 1 | Resource group `rg-cas2026-monitoring` | — | One thing to delete afterwards |
| 2 | Event Hubs namespace + hub `monitoring-events` | Basic, 1 TU, 2 partitions | Ingestion front door |
| 3 | Function App (PowerShell 7.4, Consumption) | Y1 | The pipeline |
| 4 | Storage account | Standard LRS | Required by Functions |
| 5 | Azure OpenAI + a chat deployment | Standard | Enrichment |
| 6 | Log Analytics workspace | Pay-as-you-go | Grounding queries |
| 7 | Application Insights (workspace-based) | — | OTel demo target |
| 8 | Action group `ag-cas2026-pipeline` | — | Routes alerts into Event Hubs |

---

## 1 · Resource group

Portal → Resource groups → Create. Name `rg-cas2026-monitoring`, region `East US`.

Keep everything in one region. Cross-region Event Hub traffic adds latency you will
feel on stage.

## 2 · Event Hubs

Portal → Event Hubs → Create namespace.

- Name: `evhns-cas2026` (must be globally unique — add your initials)
- Pricing tier: **Basic** is enough. Basic keeps messages 1 day and allows only the
  `$Default` consumer group, which is fine here.
- Throughput units: 1

Then inside the namespace → Event Hubs → **+ Event Hub**:

- Name: `monitoring-events`
- Partition count: **2**
- Message retention: 1 day

> Partitions matter more than they look. Each partition is processed by one Function
> instance, so 2 partitions means at most 2 concurrent workers. That is plenty for a
> demo and it keeps the log output readable on a projector. Thirty-two partitions
> would interleave output from thirty-two workers and be unwatchable.

**Shared access policy:** namespace → Shared access policies → `RootManageSharedAccessKey`
→ copy the connection string. (Managed identity is the right answer in production;
for a two-week demo the connection string is a reasonable trade and one less thing
to debug at 8am.)

## 3 · Storage + Function App

Portal → Function App → Create:

- Runtime stack: **PowerShell Core 7.4**
- Plan: Consumption (Y1)
- Region: same as everything else
- Storage: create new, Standard LRS

> **Cold start is real on Consumption.** The first invocation after idle can take
> 10–20 seconds while the PowerShell worker loads. Before you go on stage, fire one
> event through to warm it up, then keep it warm — or the cold open will feel broken
> when it isn't.

After creation → Configuration → Application settings, add:

```
EVENTHUB_CONNECTION            = <namespace connection string>
AZURE_OPENAI_ENDPOINT          = https://<your-openai>.openai.azure.com
AZURE_OPENAI_DEPLOYMENT        = <deployment name>
AZURE_OPENAI_API_VERSION       = 2024-10-21
LOG_ANALYTICS_WORKSPACE_ID     = <workspace GUID>
INCIDENT_WEBHOOK_URL           = <your webhook.site URL>
SERVICENOW_ASSIGNMENT_GROUP    = Platform Operations
```

Then Identity → System assigned → **On**. Note the object ID.

## 4 · Azure OpenAI

Portal → Azure OpenAI → Create. Then in Azure AI Foundry, deploy a chat model that
supports **Structured Outputs** (`json_schema` with `strict: true`) — check the
current model list, as availability changes by region and over time.

> If your deployment does not support Structured Outputs, `AiEnrichment.psm1` will
> fail on the `response_format` block. That is a deliberate hard failure rather than a
> silent fallback to free-text JSON — free-text JSON parsing is the thing this design
> exists to avoid.

**Give the Function App access** — do not use an API key in Azure:

Azure OpenAI resource → Access control (IAM) → Add role assignment →
**Cognitive Services OpenAI User** → Managed identity → your Function App.

## 5 · Log Analytics + Application Insights

Create the workspace first, then create Application Insights as
**workspace-based** pointing at it. Copy the workspace ID (a GUID, on the workspace
Overview blade) into `LOG_ANALYTICS_WORKSPACE_ID`.

Grant the Function App **Log Analytics Reader** on the workspace, and **Reader** at
the subscription or resource-group scope so Resource Graph and the deployments API
work.

Copy the Application Insights **connection string** for `otel-demo`.

## 6 · Action group → Event Hubs

Portal → Monitor → Alerts → Action groups → Create `ag-cas2026-pipeline`.

Actions → **Event Hubs** → select your namespace and `monitoring-events`.

**Critical:** in the action's settings, enable **the common alert schema**. If you
skip this, every alert rule delivers a differently-shaped payload and
`ConvertFrom-AzureMonitorAlert` will throw on most of them.

Then create a few alert rules that use this action group — CPU on a scale set, DTU on
a database, and an Application Insights failure-rate rule are enough to make the
portal look believable during the cold open.

---

## Verify

```powershell
.\Preflight.ps1
```

Or by hand:

```powershell
# Azure login and subscription
Get-AzContext | Format-List Name, Account, Subscription

# Azure OpenAI reachable and the deployment answers
$body = @{ messages = @(@{role='user'; content='reply with OK'}); max_tokens = 5 } | ConvertTo-Json
Invoke-RestMethod -Method Post -Body $body -ContentType 'application/json' `
  -Uri "$env:AZURE_OPENAI_ENDPOINT/openai/deployments/$env:AZURE_OPENAI_DEPLOYMENT/chat/completions?api-version=2024-10-21" `
  -Headers @{ 'api-key' = $env:AZURE_OPENAI_API_KEY }

# Event Hub accepts a test event
.\Send-TestEvent.ps1 -Scenario ..\data\scenario-web-outage.json -First 1

# Function is warm and processing
az webapp log tail --name <function-app> --resource-group rg-cas2026-monitoring
```

---

## Teardown

```powershell
Remove-AzResourceGroup -Name rg-cas2026-monitoring -Force
```

Then separately confirm, because these are the ones that survive and quietly bill:

- [ ] Azure OpenAI deployment deleted (the deployment, not just the resource)
- [ ] Log Analytics workspace gone — check for a **soft-delete retention** period
- [ ] Event Hubs namespace gone (a Basic namespace bills even while idle)
- [ ] Any diagnostic settings you pointed at the workspace from other resources —
      these outlive the workspace and start erroring

Set a calendar reminder for the day after the conference. Everyone says they'll
remember. Nobody remembers.

---

## Why no Bicep here?

Deliberate, for this session. Manual portal setup means the demo shows the actual
blades — the action group's common-alert-schema checkbox, the IAM role assignment,
the deployment list — and those clicks are half of what attendees came to see.

If you want to reuse this beyond the conference, that's the point at which Bicep
earns its place: the resources are stable, the wiring is the fiddly part, and nobody
should hand-click an action group twice.
