# Run of Show — Session 1
## MCP for Everything: Turning Any Data Source into an AI-Ready Tool

**Slot:** 90 minutes · **Content:** ~68 min · **Q&A:** ~20 min

The point of the session: most of what runs a business has no API and is never
getting one. MCP is the adapter. Every tool in this talk is the same four fields
(name, description, input schema, result) sitting over a different ugly source, and
by the end you add one live.

PowerShell is the implementation because it is what the room already writes. It is
not the message.

Setup before walking on: host running (`.\Start-Demo.ps1`), VS Code open with Copilot
Chat in Agent mode on the right, a terminal on the left, `tools/` folder visible in
the explorer. Font 16pt+ everywhere.

---

## Timing

| # | Segment | Min | Running |
|---|---------|-----|---------|
| 1 | Intro and the problem | 5 | 0:05 |
| 2 | What MCP defines, what we built | 6 | 0:11 |
| 3 | Demo 1 — A script is a tool | 6 | 0:17 |
| 4 | Demo 2 — The old database | 8 | 0:25 |
| 5 | Demo 3 — Windows internals | 7 | 0:32 |
| 6 | Demo 4 — Command-line tools | 8 | 0:40 |
| 7 | Demo 5 — The nightly extract | 8 | 0:48 |
| 8 | Demo 6 — Add a tool live | 10 | 0:58 |
| 9 | Demo 7 — Guardrails | 7 | 1:05 |
| 10 | Applying this, close | 3 | 1:08 |
| — | Q&A | ~22 | 1:30 |

Running long: Demo 3 can drop to services only (saves 3), Demo 7 can drop the
injection ticket (saves 3). Do not cut Demo 6; it is the reason people came.

Optional if it is built and there is time: Demo 8, the same server from an Azure AI
Foundry agent. Three minutes, at the end, before Q&A.

---

## 1 · Intro and the problem (5 min)

Slides 1–2. Name, what you do, where the code is. Keep it to a minute.

Then the problem slide. Read the list, ask for hands on each one:

- A report a mainframe or ERP drops on a file share overnight
- A SQL Server that has an ODBC driver and nothing else
- Windows itself: services, event logs, registry
- A vendor executable that prints text and exits
- A folder of documents that someone calls "the knowledge base"

None of them have an API. None of them are getting one. Every AI demo you have seen
this year assumed they did.

Agenda slide (4): what MCP defines (short), then one tool per source, then we add one
live.

## 2 · What MCP defines, what we built (6 min)

Slides 5–7.

**MCP in one slide.** Client, server, three primitives (tools, resources, prompts).
Tools are the only one used today; say so.

**A tool is four fields.** Name, description, input schema, result. That is the
entire contract. Show the JSON. If you can produce those four things for a data
source, an AI client can use it.

**What we built.** Architecture slide. Client on the left, one Python file in the
middle that does two things (list the tools, run one), pwsh, then a folder of `.ps1`
files. Every demo is a file in that folder. Leave this slide up as the return point.

## 3 · Demo 1 — A script is a tool (6 min)

**Files:** `powershell/tools/Get-Greeting.ps1`, `Show-Manifest.ps1`

Open `Get-Greeting.ps1`. Point out that it is a normal script: `param()` block,
comment-based help, an object out. Nothing imported.

Run `.\Show-Manifest.ps1 -Json` and put the generated schema next to the script.
Walk the mapping slide (slide 9): `Mandatory` → `required`, type → `type`,
`ValidateSet` → `enum`, `ValidateRange` → `minimum`/`maximum`, help → `description`.

In Copilot: *"Greet me like a Texan."* It picks `Style = 'Texan'` because the enum
told it the options.

Point to make: the schema is derived. Nobody wrote it.

## 4 · Demo 2 — The old database (8 min)

**Files:** `powershell/tools/Get-SqlInventory.ps1`

In Copilot: *"What's below its reorder point?"*

Then open the script. Two things to show:

1. The `WHERE` clause uses `@Category`, `@MaxPrice`, `@BelowReorder`. The model
   sent parameters, not SQL. The SQL is in the file.
2. The connection string is a read-only login.

If someone asks "why not just let it write SQL": because then the security model is
whatever the model typed. Expose the questions you are willing to answer.

Demo mode returns `data/sql-inventory.json` if SQL is unreachable. Same shape.

## 5 · Demo 3 — Windows internals (7 min)

**Files:** `powershell/tools/Get-ServiceHealth.ps1`, `powershell/tools/Get-InstalledSoftware.ps1`

Services via CIM: *"Any services on this box that should be running and aren't?"*
`OnlyProblems` does the filter. Add `IncludeRecentErrors` if there is time: event log
errors from the last 24 hours in the same call.

Installed software via registry: *"What did I install this month?"* Show the two
Uninstall keys in the script. This is the same place Add/Remove Programs reads from.

Point to make: CIM and the registry have been on every Windows machine for thirty
years. Neither has an HTTP endpoint. Both are two-line reads.

## 6 · Demo 4 — Command-line tools (8 min)

**Files:** `powershell/tools/Get-ListeningPort.ps1`

Run `netstat -ano` in the terminal first. Let them look at it.

Open the script. The pattern (slide 13) is: run the executable, match each line
against a regex with named groups, emit an object. Then the one useful thing netstat
never did: join the PID to a process name.

In Copilot: *"What's listening on 8931?"* — it finds the MCP host itself. Then:
*"Anything listening that isn't a Microsoft process?"*

Point to make: any executable that prints text is a data source. The parsing is
the whole job, and it is a regex.

## 7 · Demo 5 — The nightly extract (8 min)

**Files:** `powershell/tools/Read-LegacyReport.ps1`, `data/legacy-orders.txt`

Put `legacy-orders.txt` on screen (slide 15 has it too). Header, ruler line,
fixed-width columns, no delimiters, footer with a total. Ask who has one of these.

Open the script. The column map is an array of name/start/length. That map normally
lives in a Word document from 2004; here it lives in the script. Skip headers and
rulers, substring each column, emit objects.

In Copilot: *"Which orders are on hold, and which customer has the biggest one?"*
Then, because `Search-SupportTicket` is also loaded: *"Does that customer have any
open tickets?"* — it chains the two tools on its own.

Point to make: the system that produces this file was not touched. Twenty lines.

## 8 · Demo 6 — Add a tool live (10 min)

**Files:** type `powershell/tools/Get-LoggedOnUser.ps1`; fallback at
`fallback/Get-LoggedOnUser.ps1.txt`

Run `quser` in the terminal. Header row, one row per session, the current one
prefixed with `>`. Disconnected sessions have no session name, so the columns
shift — mention that, it is why the parse is a regex and not a split.

Put slide 17 up (the five things a tool file needs) and type:

1. `#requires -Version 7.0`, blank line, `<# .SYNOPSIS ... #>`
2. `param()` with a `[ValidateSet('Active','Disc','All')] $State`
3. `quser.exe | Select-Object -Skip 1 | ForEach-Object { if ($_ -match $pattern) { [PSCustomObject]@{...} } }`

Save. Run `.\Show-Manifest.ps1` — it is in the list. Then `/healthz` in the browser —
the host sees it too, no restart.

VS Code caches a server's tool list on its side. Confirm in rehearsal whether your
build picks the new tool up on the next request; if not, the fix is the refresh
action on the `cas2026` server in the MCP servers view, which is a click, not a
restart of anything we own. Know which one it is before you walk on.

Ask: *"Who's logged on to this machine?"*

Nothing on our side was restarted or registered. The Python file was not opened.

If the typing goes wrong: paste `fallback/Get-LoggedOnUser.ps1.txt`, say so, move on.
Rehearse the paste as well as the typing.

Before the session: make sure `tools/Get-LoggedOnUser.ps1` does not exist from the
last rehearsal. `Preflight.ps1` checks.

## 9 · Demo 7 — Guardrails (7 min)

**Files:** `powershell/tools/Restart-DemoService.ps1`, `logs/audit.jsonl`,
`data/tickets/INC-88301-customer-complaint.txt`

Slide 19 has the four points. Demo each briefly.

**Default deny.** `Restart-DemoService.ps1` is in the folder. Open
`http://localhost:8931/healthz`: it is under `registered`, not under `exposed`. The
verb is not on the read-only list and the script declares `SupportsShouldProcess`.
`.\Start-Demo.ps1 -AllowWriteTools` names it in an env var and it appears, flagged
destructive. Opt-in, per tool, by name.

**Tool output is data.** Ask Copilot: *"Search the tickets for anything about
maintenance mode."* `INC-88301` contains text telling the assistant to restart the
service and dump the audit log. Show the raw ticket, show the fenced output in the
response, show that nothing ran. Fencing is mitigation; the allowlist and the
identity the host runs as are the boundary.

**Audit log.** `Get-Content logs/audit.jsonl | ConvertFrom-Json | Format-Table`.
Timestamp, tool, arguments, every call.

**Identity.** One sentence: the server runs as some account. That account's
permissions are the real ceiling. Nothing in MCP changes that.

## 10 · Applying this, close (3 min)

Slide 20: pick the source you got asked about last week, write the script you would
have run by hand, put it in the folder. Three rules: emit objects, blank line after
`#requires`, read-only verb unless it really changes something.

Slide 21: repo, contact.

## Optional · Demo 8 — Same server, Azure AI Foundry agent (3 min)

Only if the tunnel and the agent are set up and tested that morning. Point a Foundry
agent at the same `/mcp` URL through a dev tunnel, ask it one of the questions from
earlier, show the same tool being called. The tool was written once; the client is
irrelevant. Otherwise skip it and mention it in one sentence on slide 20.

---

## Pre-flight (30 minutes before)

```powershell
.\Preflight.ps1
```

- [ ] `pwsh -v` is 7.x, not `powershell.exe`
- [ ] `http://localhost:8931/healthz` lists every tool under `registered`
- [ ] Copilot Chat in **Agent** mode, `cas2026` server showing connected
- [ ] `tools/Get-LoggedOnUser.ps1` does **not** exist
- [ ] `logs/audit.jsonl` deleted
- [ ] `$env:CAS_DEMO_MODE` unset; you know how to set it
- [ ] Terminal and editor at 16pt+
- [ ] Phone hotspot tested

If the network dies, only Demo 2 (SQL) cares. `.\Start-Demo.ps1 -DemoMode` returns
the canned inventory with a visible warning. Everything else is local.
