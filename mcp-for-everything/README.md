# MCP for Everything: Turning Any Data Source into an AI-Ready Tool

> You already know how to get the data. MCP is just a contract — and PowerShell can
> sit on the other side of it.

A Python MCP host you write once and never touch again, with every tool written as an
ordinary PowerShell 7 script. Drop a `.ps1` in `powershell/tools/` and it becomes an
AI-callable tool. No SDK, no schema by hand, no restart.

**[→ Run of show](./demos/00-run-of-show.md)** · **[→ Security notes](./docs/security.md)** · **[→ Slides](./slides/session1-mcp-for-everything.pptx)**

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

No Azure? `.\Start-Demo.ps1 -DemoMode` returns canned data for the cloud-backed tools.
Everything else — legacy files, tickets, CIM — was always local.

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
| `host/app.py` | **The entire Python host.** MCP endpoint, pwsh bridge, allowlist, audit |
| `powershell/Get-ToolManifest.ps1` | param blocks → JSON Schema |
| `powershell/_invoke.ps1` | stdin JSON → splat → JSON envelope |
| `powershell/tools/*.ps1` | The actual tools |
| `data/` | Sample sources and offline fallbacks |
| `fallback/` | Paste-ready scripts for when live typing goes sideways |
| `slides/build-session1.js` | Regenerates the deck (`node build-session1.js`) |
