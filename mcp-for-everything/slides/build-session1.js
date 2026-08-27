const pptxgen = require("pptxgenjs");

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE";           // 13.33 x 7.5
pres.author = "Donnie Taylor";
pres.title = "MCP for Everything: Turning Any Data Source into an AI-Ready Tool";

// ---------------------------------------------------------------------------
// Identical palette and helpers to build-session2.js, on purpose: the two talks
// are given by the same person at the same conference and should read as a set.
// Kept duplicated rather than factored into a shared module - each generator
// stays a single self-contained file you can run without a build step.
//
// Semantics here: teal = your PowerShell, gold = the model's side of the
// contract, coral = anything that changes state.
// ---------------------------------------------------------------------------
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

const F = { head: "Calibri", body: "Calibri", mono: "Courier New" };
const W = 13.33;

function slide() {
  const s = pres.addSlide();
  s.background = { color: C.bg };
  return s;
}

function title(s, text, opts = {}) {
  s.addText(text, {
    x: 0.7, y: opts.y ?? 0.55, w: W - 1.4, h: 0.9,
    fontFace: F.head, fontSize: opts.size ?? 40, bold: true,
    color: opts.color ?? C.text, align: "left", margin: 0,
  });
}

function kicker(s, text, color) {
  s.addText(text.toUpperCase(), {
    x: 0.7, y: 0.28, w: W - 1.4, h: 0.3,
    fontFace: F.body, fontSize: 13, bold: true, charSpacing: 2,
    color: color ?? C.calm, margin: 0,
  });
}

function card(s, x, y, w, h) {
  s.addShape(pres.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.08,
    fill: { color: C.card }, line: { color: C.cardEdge, width: 1 },
  });
}

function numberCircle(s, x, y, n, color) {
  s.addShape(pres.ShapeType.ellipse, { x, y, w: 0.52, h: 0.52, fill: { color } });
  s.addText(String(n), {
    x, y, w: 0.52, h: 0.52, align: "center", valign: "middle",
    fontFace: F.head, fontSize: 18, bold: true, color: C.bg, margin: 0,
  });
}

function demoSlide(n, name, line, watch, accent) {
  const s = slide();
  s.addText(`DEMO ${n}`, {
    x: 0.9, y: 1.9, w: 6, h: 0.4,
    fontFace: F.body, fontSize: 15, bold: true, charSpacing: 3, color: accent, margin: 0,
  });
  s.addText(name, {
    x: 0.9, y: 2.35, w: 11.5, h: 1.0,
    fontFace: F.head, fontSize: 42, bold: true, color: C.text, margin: 0,
  });
  s.addText(line, {
    x: 0.9, y: 3.45, w: 10.8, h: 0.8,
    fontFace: F.body, fontSize: 19, color: C.muted, margin: 0,
  });
  card(s, 0.9, 4.65, 11.5, 1.15);
  s.addText("WATCH FOR", {
    x: 1.15, y: 4.82, w: 2, h: 0.28,
    fontFace: F.body, fontSize: 11, bold: true, charSpacing: 2, color: accent, margin: 0,
  });
  s.addText(watch, {
    x: 1.15, y: 5.1, w: 11.0, h: 0.55,
    fontFace: F.body, fontSize: 15, color: C.text, margin: 0,
  });
  return s;
}

// ===========================================================================
// 1 - Title
// ===========================================================================
{
  const s = slide();
  s.addText("SESSION 1", {
    x: 0.9, y: 1.75, w: 8, h: 0.35,
    fontFace: F.body, fontSize: 14, bold: true, charSpacing: 3, color: C.calm, margin: 0,
  });
  s.addText("MCP for Everything", {
    x: 0.9, y: 2.15, w: 11.5, h: 1.05,
    fontFace: F.head, fontSize: 54, bold: true, color: C.text, margin: 0,
  });
  s.addText("Turning Any Data Source into an AI-Ready Tool", {
    x: 0.9, y: 3.15, w: 11.5, h: 0.7,
    fontFace: F.head, fontSize: 30, color: C.calm, margin: 0,
  });
  s.addText("Donnie Taylor   ·   Cloud and AI Summit 2026", {
    x: 0.9, y: 4.35, w: 11.5, h: 0.4,
    fontFace: F.body, fontSize: 16, color: C.muted, margin: 0,
  });
  s.addText("github.com/donnietaylor/cas2026", {
    x: 0.9, y: 6.35, w: 11.5, h: 0.35,
    fontFace: F.mono, fontSize: 13, color: C.muted, margin: 0,
  });
  s.addNotes(
    "Do NOT open on this slide and do not introduce yourself yet. Open in Copilot Chat with " +
    "the joined question about held orders. Come back here after the punchline lands."
  );
}

// ===========================================================================
// 2 - Cold open backdrop: the file nobody wants to talk about
// ===========================================================================
{
  const s = slide();
  kicker(s, "Where that answer came from", C.alert);
  title(s, "There is no API.");

  const lines = [
    "REPORT: NIGHTLY ORDER EXTRACT       RUN 2026-08-17 02:00:14  PAGE 0001",
    "ORDER ID  CUSTOMER                    ORDERDATE STATUS    AMOUNT",
    "--------------------------------------------------------------------",
    "ORD-004417Contoso Manufacturing       2026-08-11SHIPPED   18450.00",
    "ORD-004419Northwind Traders           2026-08-12HELD      97300.25",
    "ORD-004422Woodgrove Bank              2026-08-14HELD      54120.00",
    "ORD-004424Litware Holdings            2026-08-15OPEN     233400.00",
    "ORD-004426Relecloud Services          2026-08-16HELD      76500.00",
  ];

  card(s, 0.7, 2.0, 8.0, 2.85);
  let y = 2.18;
  lines.forEach((line, i) => {
    s.addText(line, {
      x: 0.95, y, w: 7.6, h: 0.3,
      fontFace: F.mono, fontSize: 10.5,
      color: i < 3 ? C.muted : C.text, margin: 0, valign: "middle",
    });
    y += 0.33;
  });

  const facts = [
    ["No vendor.", "Nobody sells this. Nobody supports it."],
    ["No API.", "There never will be one."],
    ["No changes.", "The producing system is untouched."],
  ];
  let fy = 2.0;
  facts.forEach(([head, sub]) => {
    card(s, 9.0, fy, 3.6, 0.85);
    s.addText(head, {
      x: 9.25, y: fy + 0.08, w: 3.1, h: 0.35,
      fontFace: F.head, fontSize: 19, bold: true, color: C.alert, margin: 0,
    });
    s.addText(sub, {
      x: 9.25, y: fy + 0.43, w: 3.2, h: 0.32,
      fontFace: F.body, fontSize: 11.5, color: C.muted, margin: 0,
    });
    fy += 1.0;
  });

  s.addText("Twenty lines of PowerShell, and an AI agent can reason about it.", {
    x: 0.7, y: 5.45, w: 11.9, h: 0.5,
    fontFace: F.head, fontSize: 24, bold: true, color: C.calm, margin: 0,
  });
  s.addText("Every organisation has three of these. That is what the word \"Everything\" is doing in the title.", {
    x: 0.7, y: 6.05, w: 11.9, h: 0.5,
    fontFace: F.body, fontSize: 16, color: C.muted, margin: 0,
  });

  s.addNotes(
    "Ask who has a file like this. Every hand goes up. THEN introduce yourself - you have " +
    "earned the room. They came for a title with 'Everything' in it; you proved it in four minutes."
  );
}

// ===========================================================================
// 3 - M x N
// ===========================================================================
{
  const s = slide();
  kicker(s, "Why a standard at all");
  title(s, "The same argument as ODBC, LSP and USB");

  card(s, 0.7, 1.95, 5.7, 3.7);
  s.addText("WITHOUT A STANDARD", {
    x: 1.0, y: 2.2, w: 5.1, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.alert, margin: 0,
  });
  s.addText("M × N", {
    x: 1.0, y: 2.6, w: 5.1, h: 0.9,
    fontFace: F.head, fontSize: 52, bold: true, color: C.alert, margin: 0,
  });
  s.addText(
    "Every AI client × every data source is its own bespoke integration. " +
    "Four clients and six systems is twenty-four things to build and maintain.",
    { x: 1.0, y: 3.6, w: 5.1, h: 1.2, fontFace: F.body, fontSize: 15, color: C.text, margin: 0 }
  );
  s.addText("You are the integration.", {
    x: 1.0, y: 4.9, w: 5.1, h: 0.4,
    fontFace: F.body, fontSize: 15, italic: true, color: C.muted, margin: 0,
  });

  card(s, 6.9, 1.95, 5.7, 3.7);
  s.addText("WITH ONE", {
    x: 7.2, y: 2.2, w: 5.1, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.calm, margin: 0,
  });
  s.addText("M + N", {
    x: 7.2, y: 2.6, w: 5.1, h: 0.9,
    fontFace: F.head, fontSize: 52, bold: true, color: C.calm, margin: 0,
  });
  s.addText(
    "Each client speaks the protocol once. Each source is exposed once. " +
    "Four clients and six systems is ten things, and they compose.",
    { x: 7.2, y: 3.6, w: 5.1, h: 1.2, fontFace: F.body, fontSize: 15, color: C.text, margin: 0 }
  );
  s.addText("You write the tool. Once.", {
    x: 7.2, y: 4.9, w: 5.1, h: 0.4,
    fontFace: F.body, fontSize: 15, italic: true, color: C.muted, margin: 0,
  });

  s.addText("This argument has worked every previous time somebody made it.", {
    x: 0.7, y: 6.0, w: 11.9, h: 0.5,
    fontFace: F.head, fontSize: 20, bold: true, color: C.text, margin: 0,
  });
  s.addNotes("Don't oversell novelty. The room has seen this shape before, and that is the reassuring part, not the boring part.");
}

// ===========================================================================
// 4 - Three primitives
// ===========================================================================
{
  const s = slide();
  kicker(s, "What MCP actually defines");
  title(s, "Three primitives. We use one.");

  const prims = [
    ["Tools", "Model-controlled", "The model decides when to call them. Actions and queries. This is 95% of today.", C.calm, true],
    ["Resources", "Application-controlled", "Context the host chooses to hand over. Files, records, documents.", C.muted, false],
    ["Prompts", "User-controlled", "Templates a person picks deliberately. Slash commands, canned workflows.", C.muted, false],
  ];

  let x = 0.7;
  prims.forEach(([name, control, body, colour, focus]) => {
    card(s, x, 2.0, 3.95, 3.2);
    s.addText(name, {
      x: x + 0.3, y: 2.3, w: 3.35, h: 0.5,
      fontFace: F.head, fontSize: 26, bold: true, color: colour, margin: 0,
    });
    s.addText(control, {
      x: x + 0.3, y: 2.85, w: 3.35, h: 0.3,
      fontFace: F.mono, fontSize: 11, color: focus ? C.calm : C.muted, margin: 0,
    });
    s.addText(body, {
      x: x + 0.3, y: 3.3, w: 3.35, h: 1.4,
      fontFace: F.body, fontSize: 14, color: focus ? C.text : C.muted, margin: 0,
    });
    x += 4.15;
  });

  s.addText(
    "Say this out loud now, so nobody waits ninety minutes for the other two.",
    { x: 0.7, y: 5.6, w: 11.9, h: 0.5, fontFace: F.body, fontSize: 17, italic: true, color: C.muted, margin: 0 }
  );
  s.addNotes("Being explicit about scope early buys goodwill. People get annoyed when a talk quietly never covers something it listed.");
}

// ===========================================================================
// 5 - Architecture (leave up)
// ===========================================================================
{
  const s = slide();
  kicker(s, "Today's build");
  title(s, "Where everything in this session lives");

  const clients = ["VS Code Copilot", "Claude Desktop", "Python client"];
  let cy = 2.0;
  clients.forEach((c) => {
    card(s, 0.7, cy, 2.75, 0.72);
    s.addText(c, {
      x: 0.85, y: cy, w: 2.45, h: 0.72, valign: "middle",
      fontFace: F.body, fontSize: 13, color: C.gold, margin: 0,
    });
    cy += 0.92;
  });

  card(s, 3.95, 2.2, 2.05, 2.2);
  s.addText("FastAPI\n+ uvicorn", {
    x: 3.95, y: 2.35, w: 2.05, h: 1.2, align: "center", valign: "middle",
    fontFace: F.head, fontSize: 16, bold: true, color: C.text, margin: 0,
  });
  s.addText("app.py\n145 lines", {
    x: 3.95, y: 3.5, w: 2.05, h: 0.7, align: "center",
    fontFace: F.mono, fontSize: 10, color: C.muted, margin: 0,
  });

  card(s, 6.5, 2.2, 1.9, 2.2);
  s.addText("pwsh 7", {
    x: 6.5, y: 2.2, w: 1.9, h: 2.2, align: "center", valign: "middle",
    fontFace: F.head, fontSize: 17, bold: true, color: C.calm, margin: 0,
  });

  const sources = ["Azure Resource Graph", "Azure SQL", "Entra ID", "CIM / WMI", "Files, tickets, legacy"];
  card(s, 8.9, 1.7, 3.7, 3.2);
  s.addText("tools/*.ps1", {
    x: 9.15, y: 1.85, w: 3.3, h: 0.3,
    fontFace: F.mono, fontSize: 11, bold: true, color: C.muted, margin: 0,
  });
  let sy = 2.3;
  sources.forEach((src) => {
    s.addText(src, {
      x: 9.15, y: sy, w: 3.3, h: 0.34,
      fontFace: F.body, fontSize: 13, color: C.text, margin: 0, valign: "middle",
    });
    sy += 0.48;
  });

  s.addShape(pres.ShapeType.line, {
    x: 3.5, y: 3.3, w: 0.4, h: 0, line: { color: C.cardEdge, width: 2, endArrowType: "triangle" },
  });
  s.addShape(pres.ShapeType.line, {
    x: 6.05, y: 3.3, w: 0.4, h: 0, line: { color: C.cardEdge, width: 2, endArrowType: "triangle" },
  });
  s.addShape(pres.ShapeType.line, {
    x: 8.45, y: 3.3, w: 0.4, h: 0, line: { color: C.cardEdge, width: 2, endArrowType: "triangle" },
  });

  s.addText("MCP / Streamable HTTP", {
    x: 0.7, y: 4.95, w: 3.3, h: 0.3,
    fontFace: F.mono, fontSize: 10.5, color: C.muted, margin: 0,
  });

  s.addText("You write the right-hand column. You never touch the middle again.", {
    x: 0.7, y: 5.45, w: 11.9, h: 0.5,
    fontFace: F.head, fontSize: 20, bold: true, color: C.calm, margin: 0,
  });
  s.addNotes("Leave this up. Point back at it whenever you start a demo so the room always knows which box you are in.");
}

// ===========================================================================
// 6 - THE THESIS
// ===========================================================================
{
  const s = slide();
  s.addText("MCP is a contract,", {
    x: 1.0, y: 2.35, w: 11.3, h: 0.95,
    fontFace: F.head, fontSize: 46, bold: true, color: C.text, margin: 0,
  });
  s.addText("not a runtime.", {
    x: 1.0, y: 3.3, w: 11.3, h: 0.95,
    fontFace: F.head, fontSize: 46, bold: true, color: C.calm, margin: 0,
  });
  s.addText(
    "Nothing about it says your tools have to be written in TypeScript. " +
    "You already know how to get this data — you just haven't written it down where an agent can reach it.",
    { x: 1.0, y: 4.65, w: 10.8, h: 1.0, fontFace: F.body, fontSize: 17, italic: true, color: C.muted, margin: 0 }
  );
  s.addNotes("This is the line the whole talk hangs on. Say it slowly. Everything after this is evidence for it.");
}

// ===========================================================================
// Demos 1 and 2
// ===========================================================================
demoSlide(1, "Hello, PowerShell tool", "An ordinary .ps1. No SDK, no imports, nothing to learn.",
  "It picks Style = 'Texan' on its own, because [ValidateSet] told it the options.", C.calm)
  .addNotes("Show the script first, then Show-Manifest.ps1, then ask Copilot. Land it: you did not write a schema, you wrote a param block - and those are the same thing.");

demoSlide(2, "The schema was there all along", "PowerShell has described its own parameters since 2006.",
  "Save a new .ps1 mid-sentence and watch it appear. No restart, no registration, no Python touched.", C.calm)
  .addNotes("This is the one to type live. Fallback is fallback/Get-DiskSpace.ps1.txt - rehearse the paste as well as the typing.");

// ===========================================================================
// The money slide - the mapping
// ===========================================================================
{
  const s = slide();
  kicker(s, "Demo 2 · the mapping");
  title(s, "You already wrote the schema");

  const rows = [
    ["[Parameter(Mandatory)]", "required"],
    ["[string] / [int] / [datetime]", "type"],
    ["[ValidateSet('A','B')]", "enum"],
    ["[ValidateRange(1,5)]", "minimum / maximum"],
    [".PARAMETER help", "property description"],
    [".SYNOPSIS", "tool description"],
    ["approved verb + ShouldProcess", "readOnlyHint / destructiveHint"],
  ];

  s.addText("POWERSHELL", {
    x: 0.95, y: 1.85, w: 5.2, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.calm, margin: 0,
  });
  s.addText("JSON SCHEMA", {
    x: 7.35, y: 1.85, w: 5.2, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.gold, margin: 0,
  });

  let y = 2.15;
  rows.forEach(([ps, js]) => {
    card(s, 0.7, y, 11.9, 0.56);
    s.addText(ps, {
      x: 0.95, y, w: 5.6, h: 0.56, valign: "middle",
      fontFace: F.mono, fontSize: 13, color: C.calm, margin: 0,
    });
    s.addText("→", {
      x: 6.7, y, w: 0.4, h: 0.56, valign: "middle",
      fontFace: F.body, fontSize: 14, color: C.muted, margin: 0,
    });
    s.addText(js, {
      x: 7.35, y, w: 5.0, h: 0.56, valign: "middle",
      fontFace: F.mono, fontSize: 13, color: C.gold, margin: 0,
    });
    y += 0.63;
  });

  s.addText("Nothing here is generated by hand. It is read out of the script.", {
    x: 0.7, y: 6.72, w: 11.9, h: 0.45,
    fontFace: F.head, fontSize: 19, bold: true, color: C.text, margin: 0,
  });
  s.addNotes("This is the photograph-this slide. Put the generated JSON next to the .ps1 and walk it line by line.");
}

// ===========================================================================
// Demo 3 + the query-engine slide
// ===========================================================================
demoSlide(3, "Azure, SQL, Entra", "The systems you actually run, wired up in about fifteen lines each.",
  "The model never sends SQL. It sends parameters. You own the query.", C.calm)
  .addNotes("Three minutes each. Az.ResourceGraph alone, not the whole Az module - load time is real. Let the Entra one make the room slightly uncomfortable, then say why.");

{
  const s = slide();
  kicker(s, "The design rule that matters", C.alert);
  title(s, "Expose questions, not a query engine");

  card(s, 0.7, 1.95, 5.85, 2.45);
  s.addText("DON'T", {
    x: 1.0, y: 2.15, w: 5.2, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.alert, margin: 0,
  });
  s.addText('tool("run_sql", { query: string })', {
    x: 1.0, y: 2.55, w: 5.3, h: 0.4,
    fontFace: F.mono, fontSize: 14, color: C.alert, margin: 0,
  });
  s.addText(
    "Your security model is now \"whatever the model felt like typing\", and no amount of " +
    "prompt engineering fixes it.",
    { x: 1.0, y: 3.1, w: 5.3, h: 1.1, fontFace: F.body, fontSize: 14, color: C.text, margin: 0 }
  );

  card(s, 6.75, 1.95, 5.85, 2.45);
  s.addText("DO", {
    x: 7.05, y: 2.15, w: 5.2, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.calm, margin: 0,
  });
  s.addText("Get-SqlInventory -Category -MaxPrice", {
    x: 7.05, y: 2.55, w: 5.3, h: 0.4,
    fontFace: F.mono, fontSize: 13, color: C.calm, margin: 0,
  });
  s.addText(
    "You own the SQL. It is parameterised. The login is read-only. The model supplies " +
    "values, never syntax.",
    { x: 7.05, y: 3.1, w: 5.3, h: 1.1, fontFace: F.body, fontSize: 14, color: C.text, margin: 0 }
  );

  s.addText(
    "The model is not the attacker. Whoever gets text in front of the model is.",
    { x: 0.7, y: 4.85, w: 11.9, h: 0.5, fontFace: F.head, fontSize: 22, bold: true, color: C.text, margin: 0 }
  );
  s.addText(
    "Same rule for files: take an identifier and resolve it yourself, never take a path.",
    { x: 0.7, y: 5.5, w: 11.9, h: 0.4, fontFace: F.body, fontSize: 16, color: C.muted, margin: 0 }
  );
  s.addNotes("This is the single most reusable idea in the session. Most MCP database servers on GitHub get this wrong.");
}

// ===========================================================================
// Demo 4 + Demo 5 + security
// ===========================================================================
demoSlide(4, "The junk drawer", "Fixed-width mainframe extracts, a folder of tickets, and CIM.",
  "No vector database. Select-String is genuinely fine for a few thousand documents.", C.calm)
  .addNotes("Reach for the clever thing when the simple thing stops working, not before. An embedding pipeline here would be a hundred times harder to explain, deploy and debug.");

demoSlide(5, "Security", "The risky part is not the protocol. It's that you handed a model a shell.",
  "A tool that changes state is invisible until you name it. Then a ticket tries to call it anyway.", C.alert)
  .addNotes("Do not cut this demo. Three acts: default deny, injection, audit log. People will ask about it in Q&A regardless - better to have answered it well on your own terms.");

{
  const s = slide();
  kicker(s, "Demo 5 · the real boundary", C.alert);
  title(s, "The identity is the security boundary");

  const rows = [
    ["User.Read.All", "it reads your directory", C.muted],
    ["User.ReadWrite.All", "it disables accounts", C.alert],
    ["db_datareader", "it reads your data", C.muted],
    ["db_owner", "it drops your tables", C.alert],
    ["your own admin session", "everything you can do, with none of your judgment", C.alert],
  ];

  s.addText("IF THE SERVER HOLDS", {
    x: 0.95, y: 1.9, w: 5.2, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.muted, margin: 0,
  });
  s.addText("THE WORST CASE IS", {
    x: 6.35, y: 1.9, w: 5.2, h: 0.3,
    fontFace: F.body, fontSize: 12, bold: true, charSpacing: 2, color: C.muted, margin: 0,
  });

  let y = 2.35;
  rows.forEach(([perm, worst, colour]) => {
    card(s, 0.7, y, 11.9, 0.66);
    s.addText(perm, {
      x: 0.95, y, w: 5.0, h: 0.66, valign: "middle",
      fontFace: F.mono, fontSize: 14, color: C.text, margin: 0,
    });
    s.addText(worst, {
      x: 6.35, y, w: 6.0, h: 0.66, valign: "middle",
      fontFace: F.body, fontSize: 15, color: colour, margin: 0,
    });
    y += 0.76;
  });

  s.addText(
    "Everything else is defence in depth. This is the actual boundary.",
    { x: 0.7, y: 6.35, w: 11.9, h: 0.5, fontFace: F.head, fontSize: 21, bold: true, color: C.alert, margin: 0 }
  );
  s.addNotes(
    "Get-EntraStaleAccount is read-only by design - but the same fifteen lines with Update-MgUser " +
    "would be a very polite way to disable your CEO's account. Dedicated service principal, least privilege, reviewed."
  );
}

// ===========================================================================
// Demo 6
// ===========================================================================
demoSlide(6, "Same server, three clients", "VS Code Copilot, Claude Desktop, and a plain Python script.",
  "One URL, zero changes. You wrote the tool - you did not write it FOR Copilot.", C.gold)
  .addNotes("Keep this brisk, it is a proof rather than a demo. If you are running long, a screenshot does the job in sixty seconds.");

// ===========================================================================
// Takeaways
// ===========================================================================
{
  const s = slide();
  kicker(s, "Take home");
  title(s, "Five things");

  const items = [
    ["Your param block is a schema.", "Mandatory, ValidateSet, ValidateRange and comment help are already JSON Schema."],
    ["Approved verbs are a permission model.", "Get/Read/Search are read-only. Everything else should be opt-in, by name."],
    ["Expose questions, not a query engine.", "The model supplies values. You own the syntax. Always."],
    ["Tool output is data, not instructions.", "Anyone who can file a ticket can put text in front of your agent."],
    ["The identity is the boundary.", "Least privilege on the service principal beats every prompt you can write."],
  ];

  let y = 1.85;
  items.forEach(([head, body], i) => {
    numberCircle(s, 0.75, y, i + 1, i < 3 ? C.calm : C.alert);
    s.addText(head, {
      x: 1.5, y: y - 0.02, w: 10.9, h: 0.38,
      fontFace: F.head, fontSize: 20, bold: true, color: C.text, margin: 0,
    });
    s.addText(body, {
      x: 1.5, y: y + 0.36, w: 10.9, h: 0.38,
      fontFace: F.body, fontSize: 14, color: C.muted, margin: 0,
    });
    y += 0.95;
  });
  s.addNotes("Two minutes maximum. The Q&A is worth more than a sixth bullet.");
}

// ===========================================================================
// Close
// ===========================================================================
{
  const s = slide();
  s.addText("You don't need a new language", {
    x: 1.0, y: 2.3, w: 11.3, h: 0.8,
    fontFace: F.head, fontSize: 34, color: C.muted, margin: 0,
  });
  s.addText("to make your systems AI-ready.\nYou need to write down what you\nalready know — and stop being the API.", {
    x: 1.0, y: 3.15, w: 11.3, h: 2.0,
    fontFace: F.head, fontSize: 34, bold: true, color: C.text, margin: 0,
  });
  s.addText("github.com/donnietaylor/cas2026", {
    x: 1.0, y: 5.65, w: 8, h: 0.45,
    fontFace: F.mono, fontSize: 18, color: C.calm, margin: 0,
  });
  s.addText("Runs offline. Add a capability by saving a file.", {
    x: 1.0, y: 6.1, w: 9, h: 0.4,
    fontFace: F.body, fontSize: 14, color: C.muted, margin: 0,
  });
  s.addNotes("Leave this up through Q&A so the repo URL stays on screen. Put the QR code here before the conference.");
}

pres.writeFile({ fileName: "/home/claude/build/deck/session1-mcp-for-everything.pptx" })
  .then((f) => console.log("wrote", f));
