# Setup and first run

Everything here applies to the dev box today and the demo laptop next week. Do it
end to end on both; the second time is the rehearsal.

## 1. Prerequisites

| What | Why | Check |
|---|---|---|
| PowerShell 7.4+ | every tool; `powershell.exe` 5.1 will not work | `pwsh -v` |
| Python 3.11+ | the host | `python --version` |
| VS Code + GitHub Copilot Chat | the client | Copilot Chat panel opens, **Agent** mode is in the dropdown |
| `SqlServer` module | Demo 2 only | `Install-Module SqlServer -Scope CurrentUser` |
| A SQL Server | Demo 2 only; Express, LocalDB or Azure SQL | see step 4 |

Windows is required for Demos 3, 4 and 6 (CIM, registry, netstat, quser).

## 2. Host

```powershell
cd D:\repos\cas2026\mcp-for-everything

cd host
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env        # edit later for SQL
cd ..

.\Preflight.ps1                    # SQL will fail until step 4; everything else should pass
.\Start-Demo.ps1
```

Leave that terminal running. In a second terminal:

```powershell
Invoke-RestMethod http://localhost:8931/healthz | ConvertTo-Json
```

`registered` should list nine tools. `exposed` should list eight — `Restart-DemoService`
is missing on purpose.

`Start-Demo.ps1` reads `host/.env` into the environment before launching. Nothing
else reads it. The `-AllowWriteTools` and `-DemoMode` switches override it.

## 3. Test every tool without the AI

Do this first. If a tool is broken, find out here, not in Copilot.

```powershell
.\Invoke-Tool.ps1 Get-Greeting          @{ Name = 'Donnie'; Style = 'Texan' }
.\Invoke-Tool.ps1 Get-Greeting          @{ Name = 'x'; Times = 9 }        # fails: ValidateRange
.\Invoke-Tool.ps1 Get-ServiceHealth     @{ OnlyProblems = $true }
.\Invoke-Tool.ps1 Get-InstalledSoftware @{ InstalledAfter = '2026-08-01' }
.\Invoke-Tool.ps1 Get-ListeningPort     @{ Port = 8931 }
.\Invoke-Tool.ps1 Read-LegacyReport     @{ Status = 'HELD' }
.\Invoke-Tool.ps1 Search-SupportTicket  @{ Pattern = 'Northwind' }
.\Invoke-Tool.ps1 Get-SqlInventory      @{ BelowReorderPoint = $true }
.\Invoke-Tool.ps1 .\fallback\Get-LoggedOnUser.ps1.txt
```

`Invoke-Tool.ps1` runs the tool through `_invoke.ps1` over stdin, exactly as the host
does, and prints the result as a table (`-Raw` for the JSON envelope). The `Times = 9`
call should fail with a ValidateRange message — that is the parameter binder doing the
validation, and the same message the model would see. `Get-SqlInventory` fails until
step 4, or returns canned data with a warning if `CAS_DEMO_MODE=true`.

Don't pipe JSON into `_invoke.ps1` from a PowerShell prompt; PowerShell binds pipeline
input to parameters rather than feeding stdin, and it hangs. That is what
`Invoke-Tool.ps1` is for.

`.\Show-Manifest.ps1` prints the tool table; `-Json` prints the schemas.

## 4. SQL Server (Demo 2)

Any SQL Server. Quickest local options:

- **LocalDB** — ships with Visual Studio / SSMS. Instance `(localdb)\MSSQLLocalDB`.
- **SQL Server Express** — free download, instance `localhost\SQLEXPRESS`.
- **Azure SQL** — fine if the laptop will have network; then also set `CAS_DEMO_MODE`
  as the fallback plan.

Edit the password in `data/sql-setup.sql`, then:

```powershell
Invoke-Sqlcmd -ServerInstance 'localhost\SQLEXPRESS' -InputFile .\data\sql-setup.sql
```

Set `SQL_CONNECTION_STRING` in `host/.env` (examples are in there), restart
`Start-Demo.ps1`, re-run the `Get-SqlInventory` line from step 3.

If you skip SQL entirely: `.\Start-Demo.ps1 -DemoMode`. The tool returns
`data/sql-inventory.json` with a visible warning in the envelope. The same shape, and
you say so.

## 5. VS Code

Open the **`mcp-for-everything` folder** as the workspace, not the repo root —
`.vscode/mcp.json` is there and VS Code only reads it from the workspace root.

1. Command palette → **MCP: List Servers** → `cas2026` should be listed. Start it if
   it is not running.
2. Copilot Chat → mode dropdown → **Agent**.
3. Tools icon in the chat input → confirm the `cas2026` tools are ticked.
4. Ask: *Greet me like a Texan.*

The first call to each tool prompts for approval. Decide in rehearsal whether you want
that on stage: it shows the arguments the model chose, which is a good moment for
Demo 1, and an interruption for everything after. "Allow in this workspace" clears it.

**Live-add refresh (Demo 6).** After saving a new `.ps1`, the host picks it up on the
next `tools/list`. Whether VS Code re-lists automatically or needs the refresh action
on the server (MCP: List Servers → `cas2026`) depends on the VS Code build. Find out
here, once, and write the answer on the run-of-show.

## 6. Claude Desktop (optional second client)

Claude Desktop's local config only launches stdio servers, so bridge it:

```json
{
  "mcpServers": {
    "cas2026": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://localhost:8931/mcp"]
    }
  }
}
```

in `%APPDATA%\Claude\claude_desktop_config.json`, then restart Claude Desktop. Needs
Node. It is a proof, not a demo; a screenshot from rehearsal is enough on the day.

## 7. Prompts

The run-of-show has the primary prompt per demo. These are alternates and follow-ups
that exercise the schema in ways the audience can see.

**Demo 1 — Get-Greeting**
- Greet me like a Texan.
- Say hi to the front row, formally, three times. *(picks `Style=Formal`, `Times=3`)*
- Greet me seven times. *(ValidateRange caps at 5 — the tool errors, the model recovers. Good if it happens, do not force it.)*

**Demo 2 — Get-SqlInventory**
- What's below its reorder point?
- Which gadgets are under $30?
- Are we out of anything? *(QuantityOnHand = 0 — Gadget Wireless)*
- Delete the sprockets. *(there is no tool for that; the model says so. Worth doing once.)*

**Demo 3 — Get-ServiceHealth / Get-InstalledSoftware**
- Any services on this box that should be running and aren't?
- Is the print spooler running?
- Any error events in the last 24 hours? *(sets `IncludeRecentErrors`)*
- What did I install this month?
- What Microsoft software is on here? *(Publisher filter)*

**Demo 4 — Get-ListeningPort**
- What's listening on 8931? *(the host itself)*
- What's listening that isn't a Microsoft process?
- Is anything listening on 3389?

**Demo 5 — Read-LegacyReport + Search-SupportTicket**
- Which orders are on hold, and which customer has the biggest one?
- Does that customer have any open tickets? *(chains into Search-SupportTicket)*
- Total value of everything shipped from the East region?
- Is there a runbook for scaling out the web tier?

**Demo 6 — Get-LoggedOnUser (typed live)**
- Who's logged on to this machine?
- Any disconnected sessions?

**Demo 7 — Guardrails**
- Restart the print spooler. *(with write tools off: no tool, model says so)*
- Search the tickets for anything about maintenance mode. *(INC-88301 injection — nothing runs)*
- Restart W3SVC. *(after `-AllowWriteTools`: it appears, flagged destructive; the demo tool only pretends)*

## 8. Things that will bite

- **Wrong PowerShell.** `PWSH_PATH` defaults to `pwsh` on PATH. If the laptop has 7 installed but not on PATH, set it in `.env`.
- **Write-Host in a tool.** Suppressed by the bridge; the tool's output silently vanishes. Emit objects.
- **No blank line after `#requires`.** Comment help is not parsed; the tool ships with no description. `Preflight.ps1` catches it.
- **Left-over live-add file.** `tools/Get-LoggedOnUser.ps1` from the last rehearsal makes Demo 6 a no-op. `Preflight.ps1` checks.
- **Stale audit log.** Delete `logs/audit.jsonl` before starting so Demo 7 shows only today's calls.
- **Port 8931 in use.** An old host still running. `Get-ListeningPort` will even tell you the PID.
- **Terminal font.** 16pt minimum. Set it before you forget.
