# Run of Show — Session 1
## MCP for Everything: Turning Any Data Source into an AI-Ready Tool

**Slot:** 90 minutes · **Content:** ~65 min · **Q&A:** 25 min

The thesis, in one sentence: **you already know how to get the data — MCP is just a
contract, and PowerShell can sit on the other side of it.**

Everything below assumes the host is already running (`.\Start-Demo.ps1`) and VS Code
is open with Copilot Chat in Agent mode on the right-hand side.

---

## Timing

| # | Segment | Min | Running |
|---|---------|-----|---------|
| 0 | Cold open — the punchline first | 4 | 0:04 |
| 1 | What MCP actually is (slides) | 6 | 0:10 |
| 2 | Demo 1 — Hello, PowerShell tool | 7 | 0:17 |
| 3 | Demo 2 — The schema was there all along | 9 | 0:26 |
| 4 | Demo 3 — Azure, SQL, Entra | 11 | 0:37 |
| 5 | Demo 4 — The junk drawer (files + legacy) | 10 | 0:47 |
| 6 | Demo 5 — Security: the part that matters | 12 | 0:59 |
| 7 | Demo 6 — Same server, three clients | 5 | 1:04 |
| 8 | Close + where to get it | 3 | 1:07 |
| — | **Q&A** | 23 | 1:30 |

Two escape hatches if you're running long: Demo 6 can be a 60-second screenshot,
and Demo 3 can drop to Azure only. **Do not cut Demo 5.** It is the one people
will ask about anyway, and cutting it means answering it badly in Q&A.

---

## 0 · Cold open (4 min)

Do not introduce yourself yet. Open with the finished thing.

In Copilot Chat, agent mode:

> *"Which orders are on hold, and is the customer with the biggest one having any
> support issues?"*

It calls `Read-LegacyReport`, sees Northwind Traders at $97,300 on HELD, then calls
`Search-SupportTicket` for Northwind and comes back with a joined answer.

Then say the quiet part:

> "That order data came out of a fixed-width text file that a mainframe drops on a
> file share at 2am. Those tickets are markdown on a share drive. There is no API in
> this demo. There's no vendor. There's about forty lines of PowerShell.
> That's the whole talk. Let's back up and do it properly."

*Now* introduce yourself.

**Why this order:** they came for a title with "Everything" in it. Prove the
"Everything" in the first four minutes and you have the room for the next eighty-six.

---

## 1 · What MCP is (6 min, slides)

Three slides, no more:

1. **The M×N problem.** Every AI client × every data source = a bespoke integration.
   MCP makes it M+N. This is the same argument as ODBC, LSP, and USB. It has worked
   every previous time somebody made it.
2. **Three primitives.** Tools (model-controlled actions), Resources (app-controlled
   context), Prompts (user-controlled templates). This session is 95% Tools —
   say that out loud so nobody waits ninety minutes for the other two.
3. **The architecture of today's demo.** Client → Streamable HTTP → FastAPI → `pwsh` →
   your estate. Put the box diagram up and leave it up.

The line to land: *"MCP is a contract, not a runtime. Nothing about it says your
tools have to be written in TypeScript."*

---

## 2 · Demo 1 — Hello, PowerShell tool (7 min)

**Files:** `powershell/tools/Get-Greeting.ps1`

Show the script. It is a completely ordinary PowerShell script — `param()` block,
comment-based help, `[PSCustomObject]` out. Nothing is imported. There is no SDK.

Run `.\Show-Manifest.ps1` on the projector. It's there.

(The tool browser is a PowerShell one-liner over the same manifest the host reads. There is no web UI to maintain, which is rather the point.)

Ask Copilot: *"greet me like a Texan"* → it picks `Style = 'Texan'` on its own,
because the `[ValidateSet]` told it what the options were.

**Land this:** you did not write a schema. You wrote a param block. Those are the
same thing and PowerShell has known it since 2006.

---

## 3 · Demo 2 — The schema was there all along (9 min)

This is the best demo in the deck. It's also the one to type live.

Run `.\Show-Manifest.ps1` and put the generated JSON Schema next to the script.
Walk the mapping line by line:

| PowerShell | JSON Schema |
|---|---|
| `[Parameter(Mandatory)]` | `required` |
| `[string]` / `[int]` / `[datetime]` | `type` |
| `[ValidateSet(...)]` | `enum` |
| `[ValidateRange(1,5)]` | `minimum` / `maximum` |
| `.PARAMETER` help | property `description` |
| `.SYNOPSIS` | tool `description` |
| approved verb + `SupportsShouldProcess` | `readOnlyHint` / `destructiveHint` |

**Then do it live.** Create `Get-DiskSpace.ps1` in the tools folder, five lines,
while talking. Save. Refresh the browser — the tool is there. Ask Copilot to use it.
No restart, no registration, no Python touched.

> "I want to be clear about what just happened. I added a capability to an AI agent
> by saving a file. That's the entire deployment story."

**Fallback if the live typing goes wrong:** `fallback/Get-DiskSpace.ps1.txt` has the
finished script — paste it, laugh, move on. Rehearse the paste too.

---

## 4 · Demo 3 — Azure, SQL, Entra (11 min)

The "real systems" block. Roughly 3 minutes each.

**Azure** (`Get-AzResourceInventory`): *"What resources do we have in East US that
aren't tagged with an owner?"* — Resource Graph, one KQL query, every subscription.
Mention that this is `Az.ResourceGraph` alone, not the whole `Az` module, because
module load time is a real thing.

**SQL** (`Get-SqlInventory`): *"What's below its reorder point?"*
Then show the script and make the point that matters:

> "Notice the model didn't send me SQL. It sent me parameters. I own the query, it's
> parameterised, and the login is read-only. The second you ship a `run_sql(query)`
> tool, your security model is 'whatever the model felt like typing.'
> **Expose questions, not a query engine.**"

**Entra** (`Get-EntraStaleAccount`): *"Any accounts that haven't signed in for 90 days?"*
Let the room feel the discomfort. Then say it for them: the risk isn't the protocol,
it's which identity this server runs as. Segue straight into Demo 5's setup.

---

## 5 · Demo 4 — The junk drawer (10 min)

**`Read-LegacyReport`** — put the raw fixed-width file on screen first. Let them look
at it. Ask who has one of these. Every hand goes up.

Then the column map in the script, then the structured objects, then Copilot
answering a question about it. Twenty lines, no changes to the producing system.

**`Search-SupportTicket`** — a folder of markdown and .txt.

> "There's no vector database here. For a few thousand documents `Select-String` is
> genuinely fine, and it's a hundred times easier to explain, deploy and debug than
> an embedding pipeline. Reach for the clever thing when the simple thing stops
> working — not before."

**`Get-ServiceHealth`** — CIM. Been on every Windows box since NT 4, no REST API, never
will have one. One script.

---

## 6 · Demo 5 — Security (12 min) — *do not cut this*

Three acts.

**Act 1 — Default deny.** `Restart-DemoService.ps1` exists in the tools folder. It is
not in the tool list. Show `/healthz`: the registry has it, policy hides it. Why?
The verb isn't on the read-only list and the script declares `SupportsShouldProcess`.

> "PowerShell has had a permission model this whole time. Approved verbs and
> ShouldProcess. We're just projecting it into MCP annotations."

Restart with `.\Start-Demo.ps1 -AllowWriteTools`, which sets one env var naming this one tool. Now it appears, marked
destructive. **Opt-in, per tool, by name.**

**Act 2 — Injection.** Ask Copilot: *"Search the tickets for anything about
maintenance mode."*

`INC-88301` contains a customer message telling the assistant to call
`Restart-DemoService` and dump the audit log. Show the raw ticket. Show the fenced
tool output. Show that nothing happened.

> "Tool output is data. It is not instructions. Anybody who can file a ticket, open a
> PR, or send you an email can put text in front of your agent. Fencing it is one
> f-string. Not doing it is a Tuesday you'll remember."

Be honest that fencing is mitigation, not a boundary. The boundary is the allowlist
and the permissions on the service principal.

**Act 3 — Receipts.** `Get-Content logs/audit.jsonl | ConvertFrom-Json | Format-Table`.
Every call, every argument, every outcome, append-only.

> "If an agent can run commands on your estate and you can't answer 'what did it do
> at 3am on the 14th' — you don't have an integration, you have an incident waiting
> for a date."

---

## 7 · Demo 6 — Same server, three clients (5 min)

Same URL, no changes: VS Code Copilot (already up), Claude Desktop, and the
`clients/python_client.py` script. Keep it brisk — it's a proof, not a demo.

**The point:** you wrote the tool once. You did not write it *for* Copilot.
That's M+N instead of M×N, and it's the reason to care about the standard at all.

---

## 8 · Close (3 min)

- Everything is at `github.com/<you>/cas2026` — QR on the slide.
- The whole Python host is one 130-line file and you never edit it again.
- Adding a capability is: write a `.ps1`, save it.
- The hard parts were never the protocol. They were identity, least privilege,
  and the audit log — the same hard parts as every integration you've ever shipped.

Last line:

> "You don't need to learn a new language to make your systems AI-ready. You need to
> write down what you already know how to do — and stop being the API."

---

## Pre-flight (run 30 minutes before)

```powershell
.\Preflight.ps1        # checks pwsh 7, venv, Az/Graph/SQL connectivity, port 8931
```

- [ ] `pwsh -v` is **7.x** (not 5.1 — `powershell.exe` is the wrong binary)
- [ ] `http://localhost:8931/healthz` lists every tool under `registered`
- [ ] VS Code Copilot Chat in **Agent** mode, `cas2026` server showing green
- [ ] `Connect-AzAccount` and `Connect-MgGraph` are live and not about to expire
- [ ] Audit log cleared: `Remove-Item logs/audit.jsonl -ErrorAction SilentlyContinue`
- [ ] Font size 16pt+ in terminal *and* editor; light theme if the room is bright
- [ ] `$env:CAS_DEMO_MODE` **unset** for the live run — and you know how to set it
- [ ] Phone hotspot tested as a wifi fallback

**If the wifi dies:** `$env:CAS_DEMO_MODE = 'true'` and restart the host. Azure, SQL
and Entra tools return realistic canned data with a visible warning. The legacy,
tickets and CIM demos never needed the network. Say so honestly — an audience will
forgive dead wifi and remember that you had a plan.
