// Builds slides/session1-mcp-for-everything.pptx
//
//   npm install pptxgenjs
//   node build-session1.js
//
// Working slides, not poster slides. Each one carries something the demo needs on
// screen - a diagram, a mapping table, raw data, a checklist. Speaker notes say
// what to show and what to point at. Delivery is the speaker's job.

const pptxgen = require("pptxgenjs");

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.33 x 7.5
pres.author = "Donnie Taylor";
pres.title = "MCP for Everything: Turning Any Data Source into an AI-Ready Tool";

// Same palette as the session 2 deck so the two read as a set.
// teal = PowerShell / our side, gold = the model's side, coral = changes state.
const C = {
  bg: "0F1419",
  card: "1C2530",
  cardEdge: "2C3949",
  text: "E9EEF5",
  muted: "8A9AAE",
  alert: "FF6B4A",
  calm: "5FD3BC",
  gold: "F2C14E",
};
const F = { head: "Calibri", body: "Calibri", mono: "Consolas" };
const W = 13.33;

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------
function slide(notes) {
  const s = pres.addSlide();
  s.background = { color: C.bg };
  if (notes) s.addNotes(notes);
  return s;
}

function title(s, text) {
  s.addText(text, {
    x: 0.7, y: 0.45, w: W - 1.4, h: 0.8,
    fontFace: F.head, fontSize: 32, bold: true, color: C.text, margin: 0,
  });
}

function section(s, text) {
  s.addText(text.toUpperCase(), {
    x: 0.7, y: 0.22, w: W - 1.4, h: 0.28,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.muted, margin: 0,
  });
}

function card(s, x, y, w, h, edge) {
  s.addShape(pres.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.06,
    fill: { color: C.card }, line: { color: edge ?? C.cardEdge, width: 1 },
  });
}

function bullets(s, items, { x = 0.7, y = 1.5, w = W - 1.4, h = 5, size = 20, color = C.text } = {}) {
  s.addText(
    items.map((t) => ({
      text: t,
      options: { bullet: { indent: 22 }, breakLine: true, paraSpaceAfter: 10 },
    })),
    { x, y, w, h, fontFace: F.body, fontSize: size, color, valign: "top", margin: 0 }
  );
}

function mono(s, lines, { x, y, w, h, size = 13, color = C.text }) {
  s.addText(lines.join("\n"), {
    x, y, w, h, fontFace: F.mono, fontSize: size, color, valign: "top", margin: 0,
    lineSpacingMultiple: 1.05,
  });
}

function footer(s, text) {
  s.addText(text, {
    x: 0.7, y: 6.75, w: W - 1.4, h: 0.4,
    fontFace: F.body, fontSize: 15, color: C.muted, margin: 0,
  });
}

function demoDivider(n, name, source, ask, notes) {
  const s = slide(notes);
  s.addText(`DEMO ${n}`, {
    x: 0.9, y: 2.0, w: 6, h: 0.4,
    fontFace: F.body, fontSize: 14, bold: true, charSpacing: 3, color: C.calm, margin: 0,
  });
  s.addText(name, {
    x: 0.9, y: 2.45, w: 11.5, h: 0.9,
    fontFace: F.head, fontSize: 40, bold: true, color: C.text, margin: 0,
  });
  s.addText(source, {
    x: 0.9, y: 3.4, w: 11.5, h: 0.5,
    fontFace: F.mono, fontSize: 15, color: C.muted, margin: 0,
  });
  card(s, 0.9, 4.5, 11.5, 1.1);
  s.addText("ASK", {
    x: 1.15, y: 4.65, w: 1, h: 0.28,
    fontFace: F.body, fontSize: 11, bold: true, charSpacing: 2, color: C.gold, margin: 0,
  });
  s.addText(ask, {
    x: 1.15, y: 4.95, w: 11, h: 0.55,
    fontFace: F.body, fontSize: 17, color: C.text, margin: 0,
  });
  return s;
}

// ===========================================================================
// 1 - Title
// ===========================================================================
{
  const s = slide("Open on this slide. Name, what you do, where the code is. One minute.");
  s.addText("MCP for Everything", {
    x: 0.9, y: 2.2, w: 11.5, h: 1.0,
    fontFace: F.head, fontSize: 50, bold: true, color: C.text, margin: 0,
  });
  s.addText("Turning Any Data Source into an AI-Ready Tool", {
    x: 0.9, y: 3.15, w: 11.5, h: 0.7,
    fontFace: F.head, fontSize: 28, color: C.calm, margin: 0,
  });
  s.addText("Donnie Taylor  ·  Cloud and AI Summit 2026", {
    x: 0.9, y: 4.3, w: 11.5, h: 0.4,
    fontFace: F.body, fontSize: 16, color: C.muted, margin: 0,
  });
  s.addText("github.com/donnietaylor/cas2026", {
    x: 0.9, y: 6.4, w: 11.5, h: 0.35,
    fontFace: F.mono, fontSize: 13, color: C.muted, margin: 0,
  });
}

// ===========================================================================
// 2 - About
// ===========================================================================
{
  const s = slide("Thirty seconds. The audience cares about the next slide, not this one.");
  title(s, "Donnie Taylor");
  bullets(s, [
    "Microsoft MVP",
    "DFWSMUG group leader",
    "PowerShell, endpoint management, Azure, local LLMs",
    "draith.com  ·  github.com/donnietaylor  ·  @donnietaylor.bsky.social",
  ], { y: 1.6, size: 20 });
}

// ===========================================================================
// 3 - The problem
// ===========================================================================
{
  const s = slide(
    "Ask for hands on each line. Every line gets hands. " +
    "Then the footer: none of these has an API, and none of them are getting one. " +
    "Every AI demo they saw this year assumed a REST endpoint existed."
  );
  section(s, "The problem");
  title(s, "Where the data actually is");
  bullets(s, [
    "A report the mainframe or ERP drops on a file share overnight",
    "A SQL Server with an ODBC driver and nothing else",
    "Windows itself: services, event logs, the registry",
    "A vendor executable that prints text and exits",
    "A folder of documents someone calls the knowledge base",
  ], { y: 1.55, h: 4.6, size: 22 });
  footer(s, "No API. Not getting one.");
}

// ===========================================================================
// 4 - Agenda
// ===========================================================================
{
  const s = slide("Set expectations: short on protocol, long on demos, one tool written live.");
  section(s, "Today");
  title(s, "Agenda");
  const rows = [
    ["What MCP defines, what we built", "10 min"],
    ["One tool per data source", "40 min"],
    ["Add a tool live", "10 min"],
    ["Guardrails", "7 min"],
    ["Q&A", "20 min"],
  ];
  let y = 1.6;
  rows.forEach(([what, t]) => {
    card(s, 0.7, y, 11.9, 0.68);
    s.addText(what, {
      x: 0.95, y, w: 9, h: 0.68, valign: "middle",
      fontFace: F.body, fontSize: 20, color: C.text, margin: 0,
    });
    s.addText(t, {
      x: 10.2, y, w: 2.2, h: 0.68, valign: "middle", align: "right",
      fontFace: F.mono, fontSize: 16, color: C.muted, margin: 0,
    });
    y += 0.82;
  });
}

// ===========================================================================
// 5 - What MCP defines
// ===========================================================================
{
  const s = slide(
    "One slide on the protocol. Client, server, three primitives. " +
    "Say out loud that today is tools only so nobody waits for resources and prompts."
  );
  section(s, "Model Context Protocol");
  title(s, "What MCP defines");

  const cols = [
    ["Tools", "Model-controlled", "Functions the model can call. Query, look up, act.", C.calm, true],
    ["Resources", "Application-controlled", "Context the client hands over. Files, records.", C.muted, false],
    ["Prompts", "User-controlled", "Templates a person picks. Slash commands.", C.muted, false],
  ];
  let x = 0.7;
  cols.forEach(([name, ctl, body, color, hot]) => {
    card(s, x, 1.6, 3.8, 2.7, hot ? C.calm : C.cardEdge);
    s.addText(name, {
      x: x + 0.25, y: 1.8, w: 3.3, h: 0.5,
      fontFace: F.head, fontSize: 24, bold: true, color, margin: 0,
    });
    s.addText(ctl, {
      x: x + 0.25, y: 2.3, w: 3.3, h: 0.35,
      fontFace: F.body, fontSize: 13, color: C.muted, margin: 0,
    });
    s.addText(body, {
      x: x + 0.25, y: 2.75, w: 3.3, h: 1.4,
      fontFace: F.body, fontSize: 15, color: C.text, margin: 0, valign: "top",
    });
    x += 4.05;
  });

  bullets(s, [
    "A client (VS Code, Claude Desktop, an agent) connects to a server over stdio or HTTP",
    "The server says what it has; the client's model decides when to use it",
    "Today is tools only",
  ], { y: 4.7, h: 2, size: 17 });
}

// ===========================================================================
// 6 - A tool is four fields
// ===========================================================================
{
  const s = slide(
    "This is the whole contract. If you can produce these four things for a data source, " +
    "an AI client can use it. Everything in the demos is one of these over a different source."
  );
  section(s, "Model Context Protocol");
  title(s, "A tool is four fields");

  const fields = [
    ["name", "What the model calls it"],
    ["description", "When the model should use it"],
    ["inputSchema", "JSON Schema for the arguments"],
    ["result", "What comes back - text or structured content"],
  ];
  let y = 1.6;
  fields.forEach(([k, v]) => {
    card(s, 0.7, y, 5.6, 0.8);
    s.addText(k, {
      x: 0.95, y, w: 2.4, h: 0.8, valign: "middle",
      fontFace: F.mono, fontSize: 17, bold: true, color: C.gold, margin: 0,
    });
    s.addText(v, {
      x: 3.2, y, w: 3.0, h: 0.8, valign: "middle",
      fontFace: F.body, fontSize: 14, color: C.text, margin: 0,
    });
    y += 0.95;
  });

  card(s, 6.7, 1.6, 5.9, 4.6);
  mono(s, [
    "{",
    '  "name": "Get-SqlInventory",',
    '  "description": "Queries product inventory',
    '     in the ERP database...",',
    '  "inputSchema": {',
    '    "type": "object",',
    '    "properties": {',
    '      "Category": {',
    '        "type": "string",',
    '        "enum": ["Widgets","Gadgets",',
    '                 "Sprockets","All"] },',
    '      "BelowReorderPoint": {',
    '        "type": "boolean" }',
    "    }",
    "  }",
    "}",
  ], { x: 6.95, y: 1.75, w: 5.5, h: 4.4, size: 12.5 });
}

// ===========================================================================
// 7 - What we built
// ===========================================================================
{
  const s = slide(
    "Leave this up between demos. Every demo is a file in the right-hand box. " +
    "The Python file lists tools and runs one; it does not know any tool's name."
  );
  section(s, "Today's build");
  title(s, "What we built");

  const clients = ["VS Code Copilot", "Claude Desktop", "Any MCP client"];
  let cy = 2.0;
  clients.forEach((c) => {
    card(s, 0.7, cy, 2.75, 0.7);
    s.addText(c, {
      x: 0.85, y: cy, w: 2.5, h: 0.7, valign: "middle",
      fontFace: F.body, fontSize: 14, color: C.gold, margin: 0,
    });
    cy += 0.9;
  });

  card(s, 3.95, 2.1, 2.1, 2.3);
  s.addText("host/app.py", {
    x: 3.95, y: 2.3, w: 2.1, h: 0.5, align: "center",
    fontFace: F.mono, fontSize: 13, bold: true, color: C.text, margin: 0,
  });
  s.addText("lists the tools\nruns one\n~145 lines", {
    x: 3.95, y: 2.9, w: 2.1, h: 1.3, align: "center",
    fontFace: F.body, fontSize: 12.5, color: C.muted, margin: 0,
  });

  card(s, 6.55, 2.1, 1.85, 2.3);
  s.addText("pwsh 7", {
    x: 6.55, y: 2.1, w: 1.85, h: 2.3, align: "center", valign: "middle",
    fontFace: F.head, fontSize: 17, bold: true, color: C.calm, margin: 0,
  });

  const sources = [
    "SQL Server", "CIM / WMI", "Registry", "netstat, quser, any .exe",
    "Fixed-width file drop", "Folder of tickets",
  ];
  card(s, 8.9, 1.6, 3.7, 3.6, C.calm);
  s.addText("powershell/tools/*.ps1", {
    x: 9.1, y: 1.72, w: 3.4, h: 0.3,
    fontFace: F.mono, fontSize: 11, bold: true, color: C.calm, margin: 0,
  });
  let sy = 2.15;
  sources.forEach((src) => {
    s.addText(src, {
      x: 9.1, y: sy, w: 3.4, h: 0.34, valign: "middle",
      fontFace: F.body, fontSize: 13.5, color: C.text, margin: 0,
    });
    sy += 0.47;
  });

  [3.5, 6.1, 8.45].forEach((x) => {
    s.addShape(pres.ShapeType.line, {
      x, y: 3.25, w: 0.4, h: 0, line: { color: C.muted, width: 2, endArrowType: "triangle" },
    });
  });
  s.addText("MCP over HTTP", {
    x: 0.7, y: 4.9, w: 3.3, h: 0.3,
    fontFace: F.mono, fontSize: 11, color: C.muted, margin: 0,
  });
  s.addText("JSON in, JSON out", {
    x: 5.6, y: 4.5, w: 3.3, h: 0.3,
    fontFace: F.mono, fontSize: 11, color: C.muted, margin: 0,
  });

  footer(s, "Adding a tool is adding a file to the folder. The host is not edited again.");
}

// ===========================================================================
// 8 - Demo 1 divider
// ===========================================================================
demoDivider(1, "A script is a tool", "powershell/tools/Get-Greeting.ps1   ·   Show-Manifest.ps1",
  "Greet me like a Texan.",
  "Open the script first: param block, comment help, object out, nothing imported. " +
  "Run Show-Manifest -Json, put the schema next to the script, then the mapping slide. " +
  "Then ask Copilot. It picks Style = Texan because the enum told it the options.");

// ===========================================================================
// 9 - Param block -> JSON Schema
// ===========================================================================
{
  const s = slide(
    "Walk the rows top to bottom with the script and the generated JSON side by side. " +
    "The point: nobody wrote the schema. Get-ToolManifest.ps1 reads the param block."
  );
  section(s, "Demo 1");
  title(s, "How a param block becomes a schema");

  const rows = [
    ["[Parameter(Mandatory)]", "required"],
    ["[string]  [int]  [bool]  [datetime]", "type"],
    ["[ValidateSet('A','B')]", "enum"],
    ["[ValidateRange(1,5)]", "minimum / maximum"],
    [".PARAMETER help / HelpMessage", "property description"],
    [".SYNOPSIS", "tool description"],
    ["approved verb + SupportsShouldProcess", "readOnlyHint / destructiveHint"],
  ];
  s.addText("PowerShell", {
    x: 0.95, y: 1.5, w: 5.2, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.calm, margin: 0,
  });
  s.addText("JSON Schema / MCP", {
    x: 7.35, y: 1.5, w: 5.2, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.gold, margin: 0,
  });
  let y = 1.85;
  rows.forEach(([ps, js]) => {
    card(s, 0.7, y, 11.9, 0.58);
    s.addText(ps, {
      x: 0.95, y, w: 5.7, h: 0.58, valign: "middle",
      fontFace: F.mono, fontSize: 14, color: C.calm, margin: 0,
    });
    s.addText("→", {
      x: 6.7, y, w: 0.4, h: 0.58, valign: "middle", align: "center",
      fontFace: F.body, fontSize: 16, color: C.muted, margin: 0,
    });
    s.addText(js, {
      x: 7.35, y, w: 5.1, h: 0.58, valign: "middle",
      fontFace: F.mono, fontSize: 14, color: C.gold, margin: 0,
    });
    y += 0.66;
  });
  footer(s, "Get-ToolManifest.ps1 reads the AST. No schema is written by hand.");
}

// ===========================================================================
// 10 - Demo 2 divider
// ===========================================================================
demoDivider(2, "The old database", "powershell/tools/Get-SqlInventory.ps1   ·   SQL Server, read-only login",
  "What's below its reorder point?",
  "Ask first, then open the script. Show the WHERE clause with @Category / @MaxPrice / @BelowReorder: " +
  "the model sent parameters, the SQL is in the file. Then the read-only login. " +
  "If asked why not let it write SQL: because then the security model is whatever the model typed. " +
  "Demo mode falls back to data/sql-inventory.json.");

// ===========================================================================
// 11 - Demo 3 divider
// ===========================================================================
demoDivider(3, "Windows internals", "Get-ServiceHealth.ps1 (CIM)   ·   Get-InstalledSoftware.ps1 (registry)",
  "Any services that should be running and aren't?   ·   What did I install this month?",
  "Services via Win32_Service with OnlyProblems. Add IncludeRecentErrors for event log errors if there is time. " +
  "Then the registry: two Uninstall keys, same place Add/Remove Programs reads. " +
  "Both have been on every Windows box for thirty years, neither has an HTTP endpoint.");

// ===========================================================================
// 12 - Demo 4 divider
// ===========================================================================
demoDivider(4, "Command-line tools", "powershell/tools/Get-ListeningPort.ps1   ·   netstat.exe -ano",
  "What's listening on 8931?   ·   Anything listening that isn't a Microsoft process?",
  "Run netstat -ano in the terminal first so they see the raw text. Then the script and the pattern slide. " +
  "8931 is the MCP host itself, which is a nice moment. " +
  "The PID-to-process join is the thing netstat never did for anyone.");

// ===========================================================================
// 13 - The CLI pattern
// ===========================================================================
{
  const s = slide(
    "This is the reusable part. Any executable that prints text: run it, regex each line, emit an object. " +
    "Named groups keep it readable. The filter and sort at the end are normal PowerShell."
  );
  section(s, "Demo 4");
  title(s, "Wrapping anything that prints text");

  card(s, 0.7, 1.55, 11.9, 3.4);
  mono(s, [
    "$pattern = '^\\s*TCP\\s+(?<Local>\\S+):(?<Port>\\d+)\\s+\\S+\\s+LISTENING\\s+(?<Pid>\\d+)\\s*$'",
    "",
    "netstat.exe -ano |",
    "    ForEach-Object {",
    "        if ($_ -match $pattern) {",
    "            [PSCustomObject]@{",
    "                Port        = [int]$Matches.Port",
    "                ProcessId   = [int]$Matches.Pid",
    "                ProcessName = $procs[[int]$Matches.Pid] ?? 'unknown'",
    "            }",
    "        }",
    "    }",
  ], { x: 0.95, y: 1.7, w: 11.5, h: 3.2, size: 13 });

  bullets(s, [
    "Run the executable, one line per record",
    "One regex with named groups per line shape",
    "Emit objects; the host turns them into JSON",
  ], { y: 5.15, h: 1.6, size: 17 });
}

// ===========================================================================
// 14 - Demo 5 divider
// ===========================================================================
demoDivider(5, "The nightly extract", "powershell/tools/Read-LegacyReport.ps1   ·   data/legacy-orders.txt",
  "Which orders are on hold, and which customer has the biggest one?   Does that customer have any open tickets?",
  "Raw file on screen first (next slide). Ask who has one. Then the column map in the script, then Copilot. " +
  "The second question makes it chain Read-LegacyReport into Search-SupportTicket on its own. " +
  "The producing system was not touched.");

// ===========================================================================
// 15 - The raw file
// ===========================================================================
{
  const s = slide(
    "Header, ruler, fixed-width columns with no delimiters, footer with a total. " +
    "The column map (name, start, length) is the only thing the script needs, and it normally lives in a " +
    "Word document nobody can find."
  );
  section(s, "Demo 5");
  title(s, "legacy-orders.txt");

  card(s, 0.7, 1.5, 11.9, 3.75);
  mono(s, [
    "REPORT: NIGHTLY ORDER EXTRACT          RUN 2026-08-17 02:00:14   PAGE 0001",
    "ORDER ID  CUSTOMER                    ORDERDATE STATUS    AMOUNT      REGION",
    "--------------------------------------------------------------------------------",
    "ORD-004417Contoso Manufacturing       2026-08-11SHIPPED   18450.00    CENTRAL",
    "ORD-004418Fabrikam Residences         2026-08-12OPEN      2295.50     WEST",
    "ORD-004419Northwind Traders           2026-08-12HELD      97300.25    EAST",
    "ORD-004422Woodgrove Bank              2026-08-14HELD      54120.00    EAST",
    "ORD-004424Litware Holdings            2026-08-15OPEN      233400.00   EAST",
    "ORD-004426Relecloud Services          2026-08-16HELD      76500.00    CENTRAL",
    "--------------------------------------------------------------------------------",
    "TOTAL RECORDS: 10",
  ], { x: 0.95, y: 1.65, w: 11.5, h: 3.5, size: 12 });

  card(s, 0.7, 5.4, 11.9, 1.25);
  mono(s, [
    "@{ Name = 'OrderId';  Start = 0;  Length = 10 }    @{ Name = 'Customer'; Start = 10; Length = 28 }",
    "@{ Name = 'Status';   Start = 48; Length = 10 }    @{ Name = 'Amount';   Start = 58; Length = 12 }",
  ], { x: 0.95, y: 5.6, w: 11.5, h: 1.0, size: 12, color: C.calm });
}

// ===========================================================================
// 16 - Demo 6 divider
// ===========================================================================
demoDivider(6, "Add a tool live", "type powershell/tools/Get-LoggedOnUser.ps1   ·   quser.exe",
  "Who's logged on to this machine?",
  "Run quser first. Point out the > prefix and that disconnected sessions have no session name, so columns shift. " +
  "Next slide up while typing. Save, Show-Manifest, /healthz, then ask. " +
  "Fallback: paste fallback/Get-LoggedOnUser.ps1.txt and say so. " +
  "Make sure the file does not already exist from rehearsal.");

// ===========================================================================
// 17 - What a tool file needs
// ===========================================================================
{
  const s = slide(
    "Keep this up while typing. The blank line after #requires matters: without it PowerShell stops " +
    "parsing comment help and the tool ships with no description."
  );
  section(s, "Demo 6");
  title(s, "What a tool file needs");

  const items = [
    ["#requires -Version 7.0", "then a blank line"],
    ["<# .SYNOPSIS ... #>", "becomes the description the model reads"],
    ["[CmdletBinding()] param( ... )", "becomes the input schema"],
    ["[ValidateSet] / [ValidateRange] / Mandatory", "constrain what the model can send"],
    ["[PSCustomObject]@{ ... }", "objects out, never Write-Host"],
  ];
  let y = 1.55;
  items.forEach(([code, why]) => {
    card(s, 0.7, y, 11.9, 0.78);
    s.addText(code, {
      x: 0.95, y, w: 6.2, h: 0.78, valign: "middle",
      fontFace: F.mono, fontSize: 15, color: C.calm, margin: 0,
    });
    s.addText(why, {
      x: 7.3, y, w: 5.2, h: 0.78, valign: "middle",
      fontFace: F.body, fontSize: 15, color: C.text, margin: 0,
    });
    y += 0.9;
  });
  footer(s, "Save it in powershell/tools/. Nothing else.");
}

// ===========================================================================
// 18 - Demo 7 divider
// ===========================================================================
demoDivider(7, "Guardrails", "Restart-DemoService.ps1   ·   /healthz   ·   logs/audit.jsonl   ·   INC-88301",
  "Search the tickets for anything about maintenance mode.",
  "Four short things, next slide has them. Default deny: healthz shows registered vs exposed, then -AllowWriteTools. " +
  "Injection: the ticket tells the assistant to restart the service; show the raw ticket, the fenced output, nothing ran. " +
  "Audit: Get-Content logs/audit.jsonl | ConvertFrom-Json | Format-Table. Identity: one sentence.");

// ===========================================================================
// 19 - Guardrails
// ===========================================================================
{
  const s = slide(
    "Fencing tool output is mitigation, not a boundary. The boundary is the allowlist and the account " +
    "the host runs as. Say that plainly."
  );
  section(s, "Demo 7");
  title(s, "Guardrails");

  const items = [
    ["Default deny", "Non-read-only verbs and SupportsShouldProcess are hidden unless named in WRITE_TOOL_ALLOWLIST. Per tool, by name.", C.alert],
    ["Tool output is data", "Every result is wrapped as untrusted content. Anyone who can file a ticket can put text in front of the model.", C.gold],
    ["Audit log", "Timestamp, tool, arguments, every call. Append-only. logs/audit.jsonl.", C.calm],
    ["Identity", "The host runs as an account. That account's permissions are the ceiling. MCP changes nothing about that.", C.muted],
  ];
  let y = 1.55;
  items.forEach(([head, body, color]) => {
    card(s, 0.7, y, 11.9, 1.12, color);
    s.addText(head, {
      x: 0.95, y: y + 0.1, w: 3.2, h: 0.9, valign: "middle",
      fontFace: F.head, fontSize: 19, bold: true, color, margin: 0,
    });
    s.addText(body, {
      x: 4.2, y: y + 0.1, w: 8.2, h: 0.9, valign: "middle",
      fontFace: F.body, fontSize: 14.5, color: C.text, margin: 0,
    });
    y += 1.25;
  });
}

// ===========================================================================
// 20 - Applying this
// ===========================================================================
{
  const s = slide(
    "Send them home with a task. The same server works from any client - mention Foundry Agent Service " +
    "and Copilot Studio here, or demo it if the tunnel is up and there is time."
  );
  section(s, "Your environment");
  title(s, "Applying this on Monday");
  bullets(s, [
    "Pick the source you got asked about last week",
    "Write the script you would have run by hand; return objects",
    "Put it in the folder. Read-only verb unless it really changes something",
    "Run the host as an account with the permissions you would give a new hire",
    "Same server, any client: VS Code, Claude Desktop, Copilot Studio, Azure AI Foundry agents",
  ], { y: 1.6, h: 4.6, size: 20 });
}

// ===========================================================================
// 21 - Close
// ===========================================================================
{
  const s = slide("Repo has the host, every tool, the run of show and this deck's build script. Q&A.");
  s.addText("github.com/donnietaylor/cas2026", {
    x: 0.9, y: 2.4, w: 11.5, h: 0.8,
    fontFace: F.mono, fontSize: 30, bold: true, color: C.calm, margin: 0,
  });
  s.addText("mcp-for-everything/  —  host, tools, run of show, slides", {
    x: 0.9, y: 3.25, w: 11.5, h: 0.5,
    fontFace: F.body, fontSize: 18, color: C.muted, margin: 0,
  });
  s.addText("Donnie Taylor  ·  draith.com  ·  @donnietaylor.bsky.social", {
    x: 0.9, y: 4.5, w: 11.5, h: 0.4,
    fontFace: F.body, fontSize: 16, color: C.text, margin: 0,
  });
  s.addText("Questions", {
    x: 0.9, y: 5.6, w: 11.5, h: 0.6,
    fontFace: F.head, fontSize: 28, bold: true, color: C.text, margin: 0,
  });
}

pres.writeFile({ fileName: "session1-mcp-for-everything.pptx" }).then((f) => console.log("wrote", f));
