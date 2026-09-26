# Q&A Prep — MCP for Everything

Speaker reference for the ~20 min Q&A. Answers are short on purpose: say the first
sentence, stop, expand only if they follow up. Companion to [security.md](./security.md).

---

## What sets this apart (and what doesn't)

**Don't claim "first" or "only."** Schema-from-param-block is already done by
others (see below). If someone in the room knows them, conceding it up front wins
the exchange.

| Common approach | Examples | What it assumes | Where this differs |
|---|---|---|---|
| Give the model a shell | PowerShell.MCP, generic `run_command` servers | You trust the model with everything your account can do; safety = you watching | Model never writes code. It picks a tool and supplies values; the script is yours |
| Generic database server | text-to-SQL servers; Microsoft's SQL MCP Server (Data API builder) | You have a supported database and want CRUD over entities | Covers sources with no DB and no API: flat files, CLI text, CIM, registry. DAB is the better answer *if* your source is a supported DB |
| API → MCP converters | APIM / OpenAPI-to-MCP | An API exists | The whole premise is that one doesn't |
| Vendor servers | Azure MCP Server, GitHub, etc. | The vendor's product is the source | Your in-house estate isn't anyone's product |
| PowerShell MCP frameworks | pwsh.mcp.sdk (Kevin Marquette), PoshMCP, PowerShell Universal | Same idea: scripts/cmdlets become tools | See below |

**Honest differentiators vs. the PowerShell frameworks:**

1. **Permissions derived, not configured.** Approved verb + `SupportsShouldProcess`
   → read-only / destructive. Non-read-only tools are *hidden* (not just annotated)
   until named in `WRITE_TOOL_ALLOWLIST`. PoshMCP allowlists via a config file;
   I didn't find verb/ShouldProcess-driven exposure documented in the others.
2. **Zero registration.** No config file listing tools. Save the file, it's live.
3. **Process per call.** Each call is a fresh `pwsh`, JSON on stdin splatted into
   the real `param()`, killed at timeout. No shared runspace state, no command-line
   quoting.
4. **Guardrails in the box.** Output fencing, JSONL audit, default-deny — not left
   as an exercise.
5. **Readable host.** 126 lines on the official Python SDK. The audience can read
   the entire server in one sitting.

**The one-sentence version:** "Most MCP servers either assume an API exists or hand
the model a shell. This sits in between: your scripts, your queries, the model just
picks and fills in values — and the safety policy comes from PowerShell conventions
you already follow."

---

## Questions to expect

### Architecture

**"Why a Python host? Why not write the server in PowerShell or C#?"**
There's no official PowerShell MCP SDK; the Python one is official and pinned
(`mcp==1.27.0`). The host is plumbing — list and run. Tools stay PowerShell. A C#
host with an in-process runspace is a legit alternative and would be faster.

**"Isn't this just pwsh.mcp.sdk / PoshMCP?"**
Same core idea, yes, and they're worth looking at. Differences here: permission
policy from verbs/ShouldProcess, hidden-by-default, process isolation, audit and
fencing built in. Pick whichever fits; the pattern is the point.

**"Spawning pwsh per call — isn't that slow?"**
Yes, a few hundred ms of startup per call. Trade for isolation: no state leaking
between calls, clean kill on timeout. The manifest (~650 ms) is cached and only
regenerated when the tools folder changes. For high volume, a runspace pool is the
upgrade.

**"Why Streamable HTTP instead of stdio?"**
One server, many clients — VS Code, Claude Desktop, a Foundry agent — and it can
sit behind APIM later. Stdio is simpler for a single local client.

**"How does the client find out about a new tool? There's no list_changed notification."**
Correct — the host runs stateless, so it can't push `notifications/tools/list_changed`.
The server sees the file immediately; the client re-lists on its own schedule. In
VS Code that's the refresh on the server. (Know which one your build needs before
Demo 6.)

**"You only use tools. What about resources and prompts?"**
Tools are the only primitive every client supports well. The ticket folder could be
resources; it's a tool here because the model needs to *search* it, not browse it.

**"Why return text? The spec has `outputSchema` / `structuredContent`."**
Fair. The envelope is JSON inside text, which every client handles today. Deriving
`outputSchema` from `[OutputType()]` is a reasonable next step; client support is
still uneven.

**"How is this different from A2A?"**
Different layer. MCP is agent-to-tool; A2A is agent-to-agent. An agent talking A2A
can still call tools over MCP.

### Correctness

**"What if the model sends bad arguments?"**
Validated twice. JSON Schema has `additionalProperties: false`, enums, ranges. Then
PowerShell's own parameter binder enforces `ValidateSet`/`ValidateRange`/types
again. Failures come back as a structured `ok: false` envelope, not a stack trace.

**"Why is result always an array?"**
PowerShell unrolls one result to a scalar and many to an array. The model shouldn't
have to branch on shape. One rule: it's a list.

**"Does `ValidatePattern` map cleanly to JSON Schema `pattern`?"**
Mostly. .NET regex and the ECMA-262 flavor JSON Schema uses differ at the edges
(lookbehind, named groups, inline flags). Keep patterns simple, and remember
PowerShell re-validates anyway.

**"How many tools before the model gets confused?"**
It's the descriptions more than the count. Tens is fine; past that, split into
servers by domain and let the client toggle them. Clients also impose their own
per-request caps.

### Security

**"So I name a delete script `Get-Something` and it's read-only?"**
Yes. The verb is the author's declaration, not enforcement. That's why the boundary
is the identity the server runs as, not the classifier.

**"Aren't `readOnlyHint`/`destructiveHint` just hints?"**
Yes — clients aren't required to honor them. That's why write tools are *hidden*,
not just labelled.

**"Doesn't the fence solve prompt injection?"**
No. It reduces accidental compliance. The allowlist and the identity are what stop
it. (Demo 7 covers this.)

**"Where's auth? The spec has an OAuth 2.1 authorization model."**
None in the demo, deliberately — it binds 127.0.0.1. For anything else: Entra ID
via APIM or App Service auth in front. Per-user access needs on-behalf-of, which
this doesn't do. (security.md §6–7.)

**"Every call runs as one identity — how do I stop user A seeing user B's data?"**
You don't, in this design. That's the OBO gap, stated on the security slide.

**"What about secrets in tool output?"**
Not redacted. If a tool returns a connection string, the model sees it. Filter at
the tool; credentials come from managed identity/Key Vault, not the script.

### Operations / Azure

**"How would I host this in Azure?"**
File/SQL tools: Container Apps or App Service with pwsh, managed identity, APIM in
front. Windows-internals tools (CIM, registry, quser) need a Windows host, or run
against remote machines with that host's credentials.

**"Does it run on Linux?"**
Host and manifest, yes (pwsh 7). The CIM/registry/quser tools are Windows-only by
nature.

**"What does the audit log capture?"**
Timestamp, tool, arguments. Not the result, not who asked. Ship it to Log Analytics.

**"How do I version tools without breaking agents?"**
Renaming a parameter changes the schema; clients get it on the next list. Treat
param blocks like an API: add, don't rename.

---

## Known gaps (documented, not fixed)

- **Timed-out calls aren't audited.** Audit is written after the call returns; a
  killed call leaves no line. If asked: "log before the call, or in a `finally` —
  it's a two-line change."
- **The fence is a leading warning, not a delimited block.** No closing marker.
