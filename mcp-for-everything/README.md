# MCP for Everything: Turning Any Data Source into an AI-Ready Tool

Most of what runs a business has no API and is not getting one: nightly file drops,
a SQL Server with an ODBC driver, WMI and the registry, executables that print text.
MCP is the adapter. This repo is one small Python host and a folder of PowerShell 7
scripts, one per data source. Drop a `.ps1` in `powershell/tools/` and it is an
AI-callable tool: no SDK, no schema written by hand, no restart.

**[→ Run of show](./demos/00-run-of-show.md)** · **[→ Setup](./docs/setup.md) · [→ Security notes](./docs/security.md)** · **[→ Slides](./slides/session1-mcp-for-everything.pptx)**

## How it works

```
VS Code Copilot ─┐
Claude Desktop   ├─ MCP / Streamable HTTP ─► FastAPI + uvicorn ─► pwsh ─► your estate
python client   ─┘                            (one 145-line file)  │
                                                                  └─ tools/*.ps1
```

The trick is that PowerShell already contains everything MCP needs to describe a tool:

| PowerShell | becomes |
|---|---|
| `.SYNOPSIS` | tool description |
| `[Parameter(Mandatory)]` | JSON Schema `required` |
| `[string]` / `[int]` / `[datetime]` | JSON Schema `type` |
| `[ValidateSet(...)]` | `enum` |
| `[ValidateRange(1,5)]` | `minimum` / `maximum` |
| `.PARAMETER` help | property `description` |
| approved verb + `SupportsShouldProcess` | `readOnlyHint` / `destructiveHint` |

`Get-ToolManifest.ps1` reads it out; `_invoke.ps1` takes JSON on stdin, splats it into
the real `param()` block, and returns one JSON envelope. Nothing is ever concatenated
into a command line.

## Quick start

```powershell
cd host
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cd ..

.\Preflight.ps1        # check everything before you need it
.\Start-Demo.ps1       # MCP endpoint on http://localhost:8931/mcp
```

Point VS Code at it with the included `.vscode/mcp.json`, open Copilot Chat in
**Agent** mode, and ask it something.

No SQL Server handy? `.\Start-Demo.ps1 -DemoMode` returns canned inventory data.
Everything else — files, tickets, CIM, registry, netstat — is local.

## Tools in the session

| Tool | Source | Demo |
|---|---|---|
| `Get-Greeting` | nothing; the hello-world | 1 |
| `Get-SqlInventory` | SQL Server, parameterised query, read-only login | 2 |
| `Get-ServiceHealth` | CIM (`Win32_Service`) + System event log | 3 |
| `Get-InstalledSoftware` | registry Uninstall keys | 3 |
| `Get-ListeningPort` | `netstat.exe -ano`, parsed with a regex | 4 |
| `Read-LegacyReport` | fixed-width nightly extract on a file share | 5 |
| `Search-SupportTicket` | folder of markdown and .txt | 5, 7 |
| `Get-LoggedOnUser` | `quser.exe` — **typed live**; finished copy in `fallback/` | 6 |
| `Restart-DemoService` | hidden by default; the allowlist demo | 7 |

`powershell/extras/` has Azure Resource Graph and Entra tools that work but are not in
the session.

## Writing a tool

That's the whole point: there is nothing to learn.

```powershell
#requires -Version 7.0

<#
.SYNOPSIS
    What this tool does. The model reads this line.
.PARAMETER Name
    What this parameter is for.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = 'What this parameter is for')]
    [string]$Name
)

[PSCustomObject]@{ Result = "Hello $Name" }
```

Save it in `powershell/tools/`. It's live.

**Three rules:**

1. **Emit objects, never text.** `Write-Host` writes to a stream that would corrupt
   the JSON envelope; the bridge suppresses it, so your output vanishes instead.
2. **Leave a blank line between `#requires` and `<#`.** Without it PowerShell silently
   stops parsing comment-based help and your tool ships with a useless description.
   `Get-ToolManifest.ps1` will warn you, and `Preflight.ps1` fails on it.
3. **Use an approved read-only verb** (`Get`, `Read`, `Search`, `Find`, `Test`,
   `Measure`) unless the tool really does change something — in which case declare
   `[CmdletBinding(SupportsShouldProcess)]` and expect it to be hidden until you
   allowlist it.

## Layout

| Path | What |
|---|---|
| `Invoke-Tool.ps1` | Run one tool the way the host does, no AI involved |
| `host/app.py` | **The entire Python host.** MCP endpoint, pwsh bridge, allowlist, audit |
| `powershell/Get-ToolManifest.ps1` | param blocks → JSON Schema |
| `powershell/_invoke.ps1` | stdin JSON → splat → JSON envelope |
| `powershell/tools/*.ps1` | The actual tools |
| `powershell/extras/` | Azure/Entra tools, not in the session |
| `data/` | Sample sources and offline fallbacks |
| `fallback/` | Paste-ready scripts for when live typing goes sideways |
| `slides/build-session1.js` | Regenerates the deck (`node build-session1.js`) |
