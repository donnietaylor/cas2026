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

App Insights telemetry, an Azure Monitor alert and a third-party script land in one
Event Hub. A PowerShell Function App normalizes them, drops the successes, and
correlates the rest into incidents **deterministically** - by fingerprint, host and
resource, with incident ids derived from the correlation key so parallel workers
converge on the same row. Only then does Azure OpenAI get asked the one question
facts cannot answer: which of these separate incidents are one problem, and which
are genuinely unrelated.

Correlation state lives in Azure Table Storage; the result is an Azure Workbook that
names a cause nobody sent it. Most of the reduction happens before the model is
involved.

**[→ Session materials](./smarter-monitoring/)**

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
    ├── function/          PowerShell Function App - 4 functions + Pipeline modules
    ├── store-api/         Flask app instrumented with the Azure Monitor OTel distro
    ├── workbook/          Azure Workbook definition (the dashboard)
    ├── slides/            Slides + generator
    └── *.ps1              Deploy, publish, send events, break things, reset
```

## Running without an Azure subscription

Session 1 does, which is how you rehearse on a plane and how you survive dead
conference wifi:

```powershell
# the SQL tool returns canned data, everything else is real
$env:CAS_DEMO_MODE = 'true'
cd mcp-for-everything; .\Start-Demo.ps1
```

Session 2 does not. Its correlation state lives in Azure Table Storage and its
analysis calls Azure OpenAI, so it needs the subscription. Rehearse it on tethering
and keep screenshots.

## Prerequisites

- **PowerShell 7.4+** (`winget install Microsoft.PowerShell`) — not Windows
  PowerShell 5.1
- **Python 3.11+** — session 1 host and the OTel demo app
- An Azure subscription for session 2
  ([setup and run order](./smarter-monitoring/README.md#running-it))

## License

MIT — see [LICENSE](./LICENSE). Take any of it.
