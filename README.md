# Cloud and AI Summit 2026

Demos, code and speaker material for two sessions.

Both sessions are built around the same conviction: **the interesting work is
usually not the AI part.** In session 1 the AI is a client and PowerShell does the
work. In session 2 a `GROUP BY` removes more noise than the language model does. The
model shows up where judgment is genuinely required, and nowhere else.

---

## Session 1 — MCP for Everything: Turning Any Data Source into an AI-Ready Tool

Most of what runs a business has no API. A small Python MCP host plus one
**PowerShell 7** script per data source, with schema, validation and
read-only/destructive classification derived from the `param()` block.

Sources demoed: SQL Server, CIM/WMI, the registry, `netstat` and `quser` output, a
fixed-width mainframe extract, and a folder of support tickets. One tool is written
live.

**[→ Session materials](./mcp-for-everything/)** · **[→ Run of show](./mcp-for-everything/demos/00-run-of-show.md)**

## Session 2 — Smarter Monitoring: Building an AI-Enhanced Event Pipeline

Azure Monitor, OpenTelemetry and third-party webhooks land in Event Hubs. A
PowerShell Function App normalizes them, correlates them **deterministically** on
trace ID and resource ID, grounds them in Resource Graph and Log Analytics facts,
and only then asks Azure OpenAI for judgment. Out the other end: deduplicated,
ServiceNow-shaped incidents.

12 raw payloads → 14 events → 5 groups → 5 incidents, and most of that reduction
happens before any model is involved.

**[→ Session materials](./smarter-monitoring/)** · **[→ Run of show](./smarter-monitoring/demos/00-run-of-show.md)**

---

## Repository layout

```
cas2026/
├── mcp-for-everything/
│   ├── host/              Python MCP host (FastAPI + uvicorn)
│   ├── powershell/        Get-ToolManifest.ps1, _invoke.ps1, tools/*.ps1, extras/
│   ├── clients/           Plain-Python MCP client (optional)
│   ├── data/              Sample sources + canned fallbacks
│   ├── demos/             Run of show
│   ├── docs/              Setup, security
│   └── fallback/          Scripts to paste when live typing goes wrong
└── smarter-monitoring/
    ├── function/          PowerShell Azure Function (Event Hub trigger)
    ├── powershell/        Pipeline modules + local replay harness
    ├── otel-demo/         Instrumented app + OTel Collector config
    ├── data/              Recorded outage scenario
    ├── demos/             Run of show
    └── docs/              Azure setup + teardown
```

## Running without an Azure subscription

Both sessions run offline, which is also how you rehearse on a plane and how you
survive dead conference wifi.

```powershell
# Session 1 - the SQL tool returns canned data, everything else is real
$env:CAS_DEMO_MODE = 'true'
cd mcp-for-everything; .\Start-Demo.ps1

# Session 2 - full pipeline against a recorded scenario, no cloud at all
cd smarter-monitoring\powershell
.\Invoke-LocalPipeline.ps1 -Offline -ShowStages
```

## Prerequisites

- **PowerShell 7.4+** (`winget install Microsoft.PowerShell`) — not Windows
  PowerShell 5.1
- **Python 3.11+** — session 1 host and the OTel demo app
- An Azure subscription for the live versions
  ([session 2 setup](./smarter-monitoring/docs/azure-setup.md))

## License

MIT — see [LICENSE](./LICENSE). Take any of it.
