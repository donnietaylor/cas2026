// =============================================================================
//  staging.js  ->  staging.pptx
// =============================================================================
//
//  A scratch deck to copy slides OUT of. It never touches smarter-monitoring.pptx.
//
//      node staging.js         # writes staging.pptx in this folder
//
//  Then in PowerPoint: open staging.pptx alongside the real deck, right-click
//  the slide you want in the thumbnail pane, Copy, then right-click in the main
//  deck's pane and Paste with "Keep Source Formatting". The geometry, palette
//  and fonts already match, so it lands looking like the rest of the deck.
//
//  staging.pptx is gitignored - it is an output, and it is expected to churn.
//
//  SECTION 0b - which function runs when (three swim lanes) and the function
//              catalogue grouped by the question each one answers. Two slides.
//  SECTION 1 - code walkthrough. Six slides (C4 is three options - keep one) that give the room a view into the
//              pipeline between demos. Every snippet is real code from this
//              repo, trimmed to what fits on a projector. Line counts are
//              measured, not estimated.
//  SECTION 2 - layout catalogue. One slide per layout the deck uses, with
//              filler text, for building something new by hand.
//
// =============================================================================

const kit = require('./deck-kit');
const { C, M, CONTENT_W, MONO, SANS } = kit;

const d = kit.createDeck({ title: 'Smarter Monitoring - staging' });

// #############################################################################
// SECTION 0 - THE EVENT FLOW DIAGRAM
// #############################################################################
//
//  Native PowerPoint shapes, not an image - so it stays crisp on a projector
//  and any box can be nudged in PowerPoint without re-rendering anything.
//
{
    const s = d.slide(
        'The architecture slide. Walk it left to right once, then point at the two things that are not obvious: the dashed loop is the AI pass reading and writing the same table the ingest path writes, and the three question chips - same symptom, same incident, same problem - are the spine of the session. Roughly ninety seconds; do not narrate every box.'
    );
    d.head(s, 'sources to dashboard', 'The whole event flow');

    const ROW = 1.58, RH = 3.05;          // top row
    const BOT = 4.98, BH = 1.62;          // bottom row
    const mid = ROW + RH / 2;

    // --- 1. sources ----------------------------------------------------------
    d.card(s, M, ROW, 2.45, RH);
    s.addText('SOURCES', {
        x: M + 0.2, y: ROW + 0.16, w: 2.05, h: 0.25, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 10, bold: true, color: C.DIM, charSpacing: 1.5 });

    const srcs = [
        [C.BLU, 'OpenTelemetry', 'store-api on this laptop', 'via Application Insights'],
        [C.AMB, 'Azure Monitor', 'metric alert on failures', 'via an action group'],
        [C.GRN, '12 monitoring tools', 'Send-Event.ps1', 'REST + SAS'],
    ];
    srcs.forEach((src, i) => {
        const y = ROW + 0.5 + i * 0.85;
        d.dot(s, M + 0.2, y + 0.07, src[0], 0.15);
        s.addText(src[1], { x: M + 0.45, y, w: 1.9, h: 0.26, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 13, bold: true, color: C.TXT });
        s.addText(src[2], { x: M + 0.45, y: y + 0.25, w: 1.9, h: 0.22, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 9, color: C.MUT });
        s.addText(src[3], { x: M + 0.45, y: y + 0.46, w: 1.9, h: 0.22, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 10, color: C.DIM, italic: true });
    });

    d.arrow(s, 3.10, mid, 0.30, 'right');

    // --- 2. the hub ----------------------------------------------------------
    d.card(s, 3.40, ROW, 1.45, RH);
    s.addText('EVENT HUB', {
        x: 3.55, y: ROW + 0.16, w: 1.15, h: 0.25, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 10, bold: true, color: C.DIM, charSpacing: 1.5 });
    s.addText('One hub.\nEverything.', {
        x: 3.55, y: mid - 0.72, w: 1.15, h: 0.6, isTextBox: true, margin: 0, lineSpacing: 20,
        fontFace: SANS, fontSize: 15, bold: true, color: C.TXT });
    s.addText('monitoring-\nevents', {
        x: 3.55, y: mid - 0.05, w: 1.15, h: 1.3, isTextBox: true, margin: 0, lineSpacing: 14,
        fontFace: MONO, fontSize: 9, color: C.MUT });

    d.arrow(s, 4.85, mid, 0.30, 'right');

    // --- 3. the ingest function ---------------------------------------------
    d.card(s, 5.15, ROW, 3.20, RH);
    s.addText('INGESTEVENTS  ·  EVENT HUBS TRIGGER', {
        x: 5.35, y: ROW + 0.16, w: 2.9, h: 0.25, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 10, bold: true, color: C.DIM, charSpacing: 1 });

    const steps = [
        [C.BLU, 'Normalise', 'three shapes, one object'],
        [C.DIM, 'Drop successes', 'a success is not an event'],
        [C.GRN, 'Archive the raw event', 'nothing merged yet'],
        [C.AMB, 'Correlate', 'which incident, which symptom'],
    ];
    steps.forEach((st, i) => {
        const y = ROW + 0.46 + i * 0.56;
        d.badge(s, 5.35, y + 0.02, 0.28, st[0], String(i + 1));
        s.addText(st[1], { x: 5.72, y, w: 2.5, h: 0.24, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 13, bold: true, color: C.TXT });
        s.addText(st[2], { x: 5.72, y: y + 0.23, w: 2.5, h: 0.22, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 10, color: C.MUT });
    });
    d.chip(s, 5.35, ROW + 2.68, 1.20, 'same symptom?', C.AMB);
    d.chip(s, 6.63, ROW + 2.68, 1.25, 'same incident?', C.AMB);
    s.addText('no model', {
        x: 7.92, y: ROW + 2.68, w: 0.45, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 8.5, color: C.DIM, italic: true });

    d.arrow(s, 8.35, mid, 0.30, 'right');

    // --- 4. the tables -------------------------------------------------------
    d.card(s, 8.65, ROW, 1.70, RH);
    s.addText('TABLE STORAGE', {
        x: 8.82, y: ROW + 0.16, w: 1.4, h: 0.25, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 10, bold: true, color: C.DIM, charSpacing: 1 });

    [['RawEvents', 'every event,\nas it arrived'],
     ['Events', 'one row per\nsymptom + count'],
     ['Incidents', 'one row per\ngroup + verdict']].forEach((t, i) => {
        const y = ROW + 0.5 + i * 0.82;
        d.card(s, 8.82, y, 1.36, 0.68, C.PANEL2);
        s.addText(t[0], { x: 8.94, y: y + 0.06, w: 1.15, h: 0.22, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 11, bold: true, color: C.TXT });
        s.addText(t[1], { x: 8.94, y: y + 0.28, w: 1.15, h: 0.35, isTextBox: true, margin: 0,
            lineSpacing: 11, fontFace: SANS, fontSize: 9, color: C.MUT });
    });

    d.arrow(s, 10.35, mid, 0.30, 'right');

    // --- 5. endpoint and workbook -------------------------------------------
    d.card(s, 10.65, ROW, 2.05, 1.42);
    s.addText('GETINCIDENTS  ·  HTTP', {
        x: 10.82, y: ROW + 0.14, w: 1.75, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, bold: true, color: C.DIM, charSpacing: 1 });
    s.addText('Shapes the data\nfor the screen', {
        x: 10.82, y: ROW + 0.42, w: 1.75, h: 0.45, isTextBox: true, margin: 0, lineSpacing: 15,
        fontFace: SANS, fontSize: 12, bold: true, color: C.TXT });
    s.addText('?view= raw | summary\n       sources | tree', {
        x: 10.82, y: ROW + 0.92, w: 1.75, h: 0.4, isTextBox: true, margin: 0, lineSpacing: 12,
        fontFace: MONO, fontSize: 8.5, color: C.MUT });

    d.arrow(s, 11.68, ROW + 1.42, 0.28, 'down');

    d.card(s, 10.65, ROW + 1.70, 2.05, 1.35, C.PANEL2);
    s.addText('AZURE WORKBOOK', {
        x: 10.82, y: ROW + 1.84, w: 1.75, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, bold: true, color: C.DIM, charSpacing: 1 });
    s.addText('The dashboard', {
        x: 10.82, y: ROW + 2.10, w: 1.75, h: 0.28, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 13, bold: true, color: C.TXT });
    s.addText('custom endpoint,\nno Log Analytics', {
        x: 10.82, y: ROW + 2.42, w: 1.75, h: 0.4, isTextBox: true, margin: 0, lineSpacing: 12,
        fontFace: SANS, fontSize: 9.5, color: C.MUT });

    // --- 6. the AI pass, reading and writing the same table -----------------
    d.arrow(s, 9.50, ROW + RH, BOT - (ROW + RH), 'down', { color: C.RED });
    d.arrow(s, 9.95, ROW + RH, BOT - (ROW + RH), 'up', { color: C.RED });
    s.addText('reads', {
        x: 8.95, y: ROW + RH + 0.10, w: 0.5, h: 0.2, isTextBox: true, margin: 0, align: 'right',
        fontFace: SANS, fontSize: 9, color: C.DIM });
    s.addText('writes back', {
        x: 10.02, y: ROW + RH + 0.10, w: 0.9, h: 0.2, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, color: C.DIM });

    d.card(s, 5.15, BOT, 5.20, BH);
    s.addText('ANALYZETIMER  ·  EVERY MINUTE, ONLY WHEN SOMETHING CHANGED', {
        x: 5.35, y: BOT + 0.14, w: 4.8, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, bold: true, color: C.DIM, charSpacing: 0.5 });
    s.addText('Azure OpenAI  ·  gpt-4.1-mini', {
        x: 5.35, y: BOT + 0.42, w: 4.8, h: 0.3, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, bold: true, color: C.TXT });
    s.addText('Which incidents are one problem. Which one is the cause. What to do first.\n' +
              'The verdict is written back onto the incident rows.', {
        x: 5.35, y: BOT + 0.74, w: 4.8, h: 0.44, isTextBox: true, margin: 0, lineSpacing: 14,
        fontFace: SANS, fontSize: 11, color: C.MUT });
    d.chip(s, 5.35, BOT + 1.26, 1.20, 'same problem?', C.RED);
    s.addText('the only question that needs English', {
        x: 6.63, y: BOT + 1.26, w: 3.2, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, color: C.DIM, italic: true });

    // --- 7. how it authenticates --------------------------------------------
    d.card(s, M, BOT, 4.20, BH, C.PANEL2);
    s.addText('EVERY ARROW IN THIS DIAGRAM', {
        x: M + 0.2, y: BOT + 0.14, w: 3.8, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, bold: true, color: C.DIM, charSpacing: 1 });
    s.addText('No keys anywhere', {
        x: M + 0.2, y: BOT + 0.42, w: 3.8, h: 0.3, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, bold: true, color: C.GRN });
    s.addText('The Function App has a managed identity with three role assignments: read the hub, ' +
              'write the tables, call Azure OpenAI. Nothing in the pipeline holds a secret.', {
        x: M + 0.2, y: BOT + 0.76, w: 3.8, h: 0.7, isTextBox: true, margin: 0, lineSpacing: 14,
        fontFace: SANS, fontSize: 11, color: C.MUT });

    // --- 8. the side utilities ----------------------------------------------
    d.card(s, 10.65, BOT, 2.05, BH);
    s.addText('ALSO READS THE TABLES', {
        x: 10.82, y: BOT + 0.14, w: 1.75, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, bold: true, color: C.DIM, charSpacing: 1 });
    s.addText('Show-Incidents.ps1\nReset-Pipeline.ps1', {
        x: 10.82, y: BOT + 0.45, w: 1.75, h: 0.5, isTextBox: true, margin: 0, lineSpacing: 15,
        fontFace: MONO, fontSize: 10, color: C.TXT });
    s.addText('a short-lived SAS,\nfrom your terminal', {
        x: 10.82, y: BOT + 1.0, w: 1.75, h: 0.45, isTextBox: true, margin: 0, lineSpacing: 12,
        fontFace: SANS, fontSize: 9.5, color: C.MUT });

    s.addText('179 events in. 13 incidents and 2 root causes out. About four seconds of model time.', {
        x: M, y: 6.78, w: CONTENT_W, h: 0.3, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 12, color: C.DIM, italic: true });
}

// #############################################################################
// SECTION 0b - WHICH FUNCTION RUNS WHEN, AND WHICH QUESTION IT ANSWERS
// #############################################################################
//
//  Two slides that answer the question the code does not answer on its own:
//  the three questions in the story are not three passes in the code. Slide A
//  is the execution order per trigger; slide B is the function catalogue
//  grouped by role. Every name on both slides is a real function in the repo.
//
{
    // ------------------------------------------------------------------ A ----
    const s = d.slide(
        'The execution slide. Three swim lanes, one per trigger. The top lane is the one to spend time on: point at the row inside Add-EventToIncident and say that the incident is decided before the symptom - question two before question one - because they are the two halves of one row address. The other two lanes are a sentence each.'
    );
    d.head(s, 'three triggers, one table', 'Which function runs when');

    const LX = M + 0.18, LW = 1.85;          // lane label column
    const X0 = M + 2.2, X1 = M + CONTENT_W;          // chain area
    const CW = X1 - X0;

    // A box in a chain: a mono name (or a sans phrase), a description, an
    // optional question chip. Returns nothing; geometry is the caller's problem.
    const box = (x, y, w, h, name, desc, o = {}) => {
        s.addShape(d.pres.ShapeType.roundRect, {
            x, y, w, h, rectRadius: 0.05, fill: { color: C.PANEL2 },
            line: o.outline ? { color: o.outline, width: 1.25 } : undefined
        });
        const nameLines = (name.match(/\n/g) || []).length + 1;
        const nh = o.sans ? 0.24 : (nameLines > 1 ? 0.34 : 0.22);
        s.addText(name, {
            x: x + 0.1, y: y + 0.07, w: w - 0.2, h: nh, isTextBox: true, margin: 0, lineSpacing: 12,
            fontFace: o.sans ? SANS : MONO, fontSize: o.sans ? 10.5 : (w < 2 ? 8.5 : 9.5), bold: true,
            color: o.nameColor || C.TXT });
        s.addText(desc, {
            x: x + 0.1, y: y + 0.09 + nh, w: w - 0.2, h: h - nh - 0.16 - (o.chip ? 0.24 : 0),
            isTextBox: true, margin: 0, valign: 'top', lineSpacing: 11,
            fontFace: SANS, fontSize: 8.5, color: C.MUT });
        if (o.chip) d.chip(s, x + 0.1, y + h - 0.30, 1.25, o.chip[0], o.chip[1]);
        if (o.dot) d.dot(s, x + w - 0.24, y + 0.1, o.dot, 0.12);
    };

    const chain = (y, h, items, gap) => {
        const w = (CW - gap * (items.length - 1)) / items.length;
        items.forEach((it, i) => {
            const x = X0 + i * (w + gap);
            box(x, y, w, h, it[0], it[1], it[2] || {});
            if (i < items.length - 1) d.arrow(s, x + w + 0.03, y + h / 2, gap - 0.06, 'right');
        });
    };

    const laneLabel = (y, eyebrow, title, when, mod, modY = 1.34) => {
        s.addText(eyebrow, { x: LX, y: y + 0.14, w: LW, h: 0.22, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 9.5, bold: true, color: C.DIM, charSpacing: 1 });
        s.addText(title, { x: LX, y: y + 0.38, w: LW, h: 0.46, isTextBox: true, margin: 0, lineSpacing: 14,
            fontFace: SANS, fontSize: 12.5, bold: true, color: C.TXT });
        s.addText(when, { x: LX, y: y + 0.86, w: LW, h: 0.4, isTextBox: true, margin: 0, lineSpacing: 12,
            fontFace: SANS, fontSize: 9.5, color: C.MUT, italic: true });
        s.addText(mod, { x: LX, y: y + modY, w: LW, h: 0.24, isTextBox: true, margin: 0, lineSpacing: 12,
            fontFace: MONO, fontSize: 8.5, color: C.DIM });
    };

    // --- lane 1 : ingest ------------------------------------------------------
    const L1 = 1.50, L1H = 2.40;
    d.card(s, M, L1, CONTENT_W, L1H);
    laneLabel(L1, 'INGESTEVENTS', 'Event Hubs trigger', 'runs per batch,\nevery step per event', 'Normalize.psm1\nCorrelation.psm1');

    chain(L1 + 0.16, 0.66, [
        ['ConvertTo-PipelineEvent', 'Three payload shapes become one event object. Successes are dropped here - a success is not an event.', { dot: C.BLU }],
        ['Write-RawEvent', 'Archived exactly as it arrived, before anything is merged away. This is the RawEvents firehose.', { dot: C.GRN }],
        ['Add-EventToIncident', 'The correlator. Everything on the row below happens inside this one call, in this order.', { dot: C.AMB, outline: C.AMB }],
    ], 0.35);

    s.addText('inside Add-EventToIncident, for each event, left to right', {
        x: X0, y: L1 + 0.88, w: CW, h: 0.2, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, italic: true, color: C.AMB });

    chain(L1 + 1.08, 1.18, [
        ['Get-PrimaryKey\n→ Get-IncidentId', 'Which incident: host > resource > service > trace, then hashed.', { chip: ['same incident?', C.AMB] }],
        ['Get-Fingerprint', 'Which symptom. Digits → N, then source | kind | title | resource | host, hashed.', { chip: ['same symptom?', C.AMB] }],
        ['New-Incident', 'Create the incident row, or revive it if it went quiet longer than the window.'],
        ['Events(id, fp)\nseen in the window?', 'Yes: Count + 1, outcome deduped. No: POST a new symptom row, outcome new-symptom.', { sans: true }],
        ['Touch the incident', 'LastSeen and TouchedAt, unconditional. Nothing on the incident row is a counter, so nothing can race.', { sans: true }],
    ], 0.22);

    // --- lane 2 : analysis ----------------------------------------------------
    const L2 = L1 + L1H + 0.18, L2H = 1.46;
    d.card(s, M, L2, CONTENT_W, L2H);
    laneLabel(L2, 'ANALYZETIMER  ·  ANALYZE', 'Every minute,\nor on demand', 'one call to\nInvoke-IncidentAnalysis', 'Ai.psm1', 1.22);

    chain(L2 + 0.16, 1.14, [
        ['Get-OpenIncident', 'Every open incident seen in the last 60 minutes.'],
        ['Anything touched\nsince the last pass?', 'A meta row remembers LastRun. A quiet minute costs nothing. -Force skips the check for the demo.', { sans: true }],
        ['Get-IncidentBrief', 'Top 6 symptoms per incident. Row keys and plumbing stripped - the model sees the outage, not the schema.'],
        ['Invoke-OpenAI', 'One call. gpt-4.1-mini, temp 0, JSON out, parsed by ConvertFrom-ModelJson.', { chip: ['same problem?', C.RED] }],
        ['Write-IncidentVerdict', 'Once per incident: cause, downstream, unrelated or forgotten. Clusters of one are demoted. Then LastRun moves.'],
    ], 0.22);

    // --- lane 3 : the endpoint ------------------------------------------------
    const L3 = L2 + L2H + 0.18, L3H = 0.98;
    d.card(s, M, L3, CONTENT_W, L3H);
    s.addText('GETINCIDENTS', { x: LX, y: L3 + 0.14, w: LW, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9.5, bold: true, color: C.DIM, charSpacing: 1 });
    s.addText('HTTP, when the\nworkbook refreshes', { x: LX, y: L3 + 0.38, w: LW, h: 0.46, isTextBox: true, margin: 0, lineSpacing: 14,
        fontFace: SANS, fontSize: 12.5, bold: true, color: C.TXT });

    chain(L3 + 0.15, 0.68, [
        ['Read', 'Incidents open in the last 2 hours, plus their Events rows. Imports Plumbing.psm1 and nothing else.', { sans: true }],
        ['Shape', '?view= raw · summary · sources · tree · incidents · symptoms - one per visual on the workbook.', { sans: true }],
        ['Answer', 'JSON the workbook can colour. No correlation logic lives here; it is presentation only.', { sans: true }],
    ], 0.35);

    s.addText([
        { text: 'The first two questions are not two passes. ', options: { bold: true, color: C.TXT } },
        { text: 'They are the two halves of one row address - ', options: { color: C.MUT } },
        { text: 'Events(PartitionKey = incident id, RowKey = fingerprint)', options: { fontFace: MONO, color: C.AMB } },
        { text: ' - and the code works out the incident before the symptom.', options: { color: C.MUT } },
    ], {
        x: M, y: L3 + L3H + 0.12, w: CONTENT_W, h: 0.42, isTextBox: true, margin: 0, align: 'center',
        valign: 'top', fontFace: SANS, fontSize: 11 });
}

{
    // ------------------------------------------------------------------ B ----
    const s = d.slide(
        'The catalogue. Do not read it aloud; let it sit while you say the one sentence at the bottom. The thing to point at is the same-symptom row: one function, four lines, and the middle row - the plumbing - which is its own module now and knows nothing about correlation.'
    );
    d.head(s, 'every function, by job', 'Which function answers which question');

    const LW = 2.35;
    const line = (name, desc, last) => ([
        { text: name, options: { fontFace: MONO, fontSize: 10, bold: true, color: C.TXT } },
        { text: '   ' + desc, options: { fontFace: SANS, fontSize: 10, color: C.MUT, breakLine: !last } },
    ]);

    const rows = [
        {
            h: 0.95, role: 'Normalise', mod: 'Normalize.psm1 (10)',
            lines: [
                ['ConvertTo-PipelineEvent', 'the entry point: sniffs the payload shape and hands off'],
                ['ConvertFrom-AppInsightsRecord · -AzureMonitorAlert · -ScriptEvent', 'one per shape'],
                ['Get-HostFromTarget', 'a dependency’s Target becomes the host, so the app’s failed call joins the server’s incident'],
                ['Get-Field · Get-ExceptionMessage · Format-Time · New-PipelineEvent', 'helpers'],
            ]
        },
        {
            h: 0.66, role: 'Same symptom?', chip: ['question 1', C.AMB], mod: 'Correlation.psm1',
            lines: [
                ['Get-Fingerprint', 'SHA256 of source | kind | title with digits → N | resource | host.  Four lines. The whole answer.'],
            ]
        },
        {
            h: 0.95, role: 'Same incident?', chip: ['question 2', C.AMB], mod: 'Correlation.psm1',
            lines: [
                ['Get-PrimaryKey · Get-IncidentId', 'the one key that decides the incident, and the id derived from it'],
                ['Get-EventKey', 'every key the event carries, for the “correlated on” line'],
                ['Add-EventToIncident', 'the orchestrator - the only thing IngestEvents calls after archiving'],
                ['New-Incident · Write-RawEvent', 'the writes; neither is conditional'],
            ]
        },
        {
            h: 0.78, role: 'Plumbing', mod: 'Plumbing.psm1 (9)', roleColor: C.DIM,
            lines: [
                ['Invoke-Table · Get-TableRow · Get-OpenIncident · Measure-Incident', 'Table Storage over REST, and the totals the incident row does not store'],
                ['Get-ResourceToken · Get-StorageToken', 'managed identity, one token per resource, cached'],
                ['Get-HttpStatus · ConvertTo-TableLiteral · ConvertTo-Utc', 'the small conversions everyone leans on'],
            ]
        },
        {
            h: 0.95, role: 'Same problem?', chip: ['question 3', C.RED], mod: 'Ai.psm1 (5)',
            lines: [
                ['Invoke-IncidentAnalysis', 'the pass: fetch, skip if quiet, brief, ask, write back'],
                ['Get-IncidentBrief', 'what the model is allowed to see'],
                ['Invoke-OpenAI · ConvertFrom-ModelJson', 'the one call, and the JSON it must return'],
                ['Write-IncidentVerdict', 'one incident’s verdict, a plain merge - it sends no counters'],
            ]
        },
        {
            h: 0.66, role: 'Presentation', mod: 'GetIncidents/run.ps1', roleColor: C.BLU,
            lines: [
                ['six ?view= shapes', 'raw · summary · sources · tree · incidents · symptoms'],
                ['Format-Count · Format-Age · Write-Json · Get-TableRow', 'local helpers - that last one is a filter query, not the module’s point read'],
            ]
        },
    ];

    let y = 1.52;
    rows.forEach(r => {
        d.card(s, M, y, CONTENT_W, r.h);
        s.addText(r.role, { x: M + 0.22, y: y + 0.11, w: LW - 0.3, h: 0.26, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 13, bold: true, color: r.roleColor || C.TXT });
        if (r.chip) d.chip(s, M + 0.22, y + 0.40, 0.85, r.chip[0], r.chip[1]);
        s.addText(r.mod, { x: M + 0.22 + (r.chip ? 0.93 : 0), y: y + 0.40, w: LW - 0.3 - (r.chip ? 0.93 : 0), h: 0.22,
            isTextBox: true, margin: 0, fontFace: MONO, fontSize: r.chip ? 8 : 8.5, color: C.DIM });
        const runs = [];
        r.lines.forEach((l, i) => runs.push(...line(l[0], l[1], i === r.lines.length - 1)));
        s.addText(runs, { x: M + LW, y: y + 0.08, w: CONTENT_W - LW - 0.2, h: r.h - 0.14,
            isTextBox: true, margin: 0, valign: 'top', lineSpacing: 15 });
        y += r.h + 0.11;
    });

    s.addText('35 functions. Three of them decide what belongs together. One of them talks to a model.', {
        x: M, y: y + 0.02, w: CONTENT_W, h: 0.3, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 12, color: C.DIM, italic: true });
}

// #############################################################################
// SECTION 1 - CODE WALKTHROUGH
// #############################################################################

// -----------------------------------------------------------------------------
// C1. The whole trigger, on one slide
// -----------------------------------------------------------------------------
{
    const s = d.slide(
        'Show this before the first demo. The point is that the function that reads the hub is trivially small - all the interesting work is behind three verbs. Read the three lines in the inner loop out loud and move on; the next slides open each one up.'
    );
    d.head(s, 'ingestevents / run.ps1  ·  34 lines', 'The whole trigger');

    const h1 = d.codePanel(s, M, 1.95, CONTENT_W, null, null, [
        ['foreach ($message in @($eventHubMessages)) {', C.TXT],
        ['    $payload = $message | ConvertFrom-Json -Depth 50', C.MUT],
        ['', C.MUT],
        ['    foreach ($event in ConvertTo-PipelineEvent -Payload $payload) {', C.TXT],
        ['        if ($event.Success) { $dropped++; continue }  # a success is not news', C.DIM],
        ['', C.MUT],
        ['        Write-RawEvent      -Event $event   # keep the firehose', C.GRN],
        ['        Add-EventToIncident -Event $event   # correlate it', C.AMB],
        ['    }', C.TXT],
        ['}', C.TXT],
    ], { size: 15 });

    d.callout(s, 1.95 + h1 + 0.35, [
        { text: 'Read the hub, normalise, throw away the successes, correlate. ',
          options: { bold: true, color: C.WHT } },
        { text: 'Everything else in this session is one of those three verbs, opened up.',
          options: { color: C.MUT } },
    ], { h: 0.95, size: 17 });
}

// -----------------------------------------------------------------------------
// C2. Normalisation
// -----------------------------------------------------------------------------
{
    const s = d.slide(
        'Three sources, three completely different JSON shapes, and none of them agree on what a field is called. This is the unglamorous half of any pipeline like this and it is worth saying so - people underestimate it every time.'
    );
    d.head(s, 'normalize.psm1  ·  122 lines', 'Three shapes, one object', { eyebrowColor: C.BLU });

    const h2 = d.codePanel(s, M, 1.95, 7.6, null, null, [
        ['function Get-PayloadShape {', C.TXT],
        ['  if ($Payload.records)         { \'appinsights\' }  # diagnostic setting', C.MUT],
        ['  if ($Payload.data.essentials) { \'alert\' }        # common alert schema', C.MUT],
        ['  if ($Payload.tool)            { \'script\' }       # our own senders', C.MUT],
        ['}', C.TXT],
    ], { size: 13 });

    d.card(s, 8.6, 1.95, 4.1, h2, C.PANEL2);
    s.addText('Out the other side', {
        x: 8.9, y: 2.12, w: 3.6, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, bold: true, color: C.TXT });
    s.addText('Source  Kind     Time\nSeverity Title   Message\nTraceId Host     Resource', {
        x: 8.9, y: 2.52, w: 3.6, h: 1.1, isTextBox: true, margin: 0, lineSpacing: 19,
        fontFace: MONO, fontSize: 11, color: C.MUT });

    d.callout(s, 1.95 + h2 + 0.4, [
        { text: 'Every source disagrees about field names. ', options: { bold: true, color: C.WHT } },
        { text: 'OperationId or operation_Id. TimeGenerated or time or timestamp. ' +
                'Nothing downstream can be written until one object comes out of here - and this is ' +
                'the part everyone underestimates when they plan a pipeline like this.',
          options: { color: C.MUT } },
    ], { h: 1.25, size: 15 });
}

// -----------------------------------------------------------------------------
// C3. Same symptom? - concept and code on one slide
// -----------------------------------------------------------------------------
{
    const s = d.slide(
        'Question one, in full. Three lines. Say plainly that this is the entire deduplication engine and that it involves no intelligence of any kind - it is a hash of a string with the numbers taken out. Then be honest about the cost: "Port 22 closed" and "Port 443 closed" collapse together too. Worth it.'
    );
    d.head(s, 'correlation.psm1  ·  is this the same symptom?', 'Deduplication is three lines');

    const h3 = d.codePanel(s, M, 1.95, CONTENT_W, null, null, [
        ['$title = $Event.Title -replace \'\\d+\', \'N\'          # 480 ms and 8 ms are the same symptom', C.AMB],
        ['$seed  = "$Source|$Kind|$title|$ResourceId|$Host".ToLowerInvariant()', C.TXT],
        ['$hash  = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($seed))', C.TXT],
    ], { size: 14 });

    const y3 = 1.95 + h3 + 0.3, ch = 1.95;
    d.card(s, M, y3, 5.75, ch);
    s.addText('What goes in', {
        x: M + 0.35, y: y3 + 0.15, w: 5.05, h: 0.32, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, bold: true, color: C.MUT });
    s.addText(['410', '455', '480', '512', '498', '466'].map(n => `Disk read latency ${n} ms, sustained`).join('\n'), {
        x: M + 0.35, y: y3 + 0.5, w: 5.05, h: 1.4, isTextBox: true, margin: 0, lineSpacing: 16,
        fontFace: MONO, fontSize: 11, color: C.MUT });

    s.addText('>', { x: 6.45, y: y3 + 0.7, w: 0.5, h: 0.5, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 26, bold: true, color: C.AMB });

    d.card(s, 6.95, y3, 5.75, ch, C.PANEL2);
    s.addText('What comes out', {
        x: 7.3, y: y3 + 0.15, w: 5.05, h: 0.32, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, bold: true, color: C.GRN });
    s.addText('Disk read latency N ms, sustained', {
        x: 7.3, y: y3 + 0.62, w: 5.05, h: 0.35, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 13, color: C.TXT });
    s.addText('one row  ·  seen 6 times', {
        x: 7.3, y: y3 + 1.12, w: 5.05, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, bold: true, color: C.AMB });

    d.callout(s, y3 + ch + 0.22, [
        { text: 'Every run of digits collapses.  ', options: { bold: true, color: C.WHT } },
        { text: 'Durations, counts, percentages and addresses are values, not identities - 300 identical ' +
                'checkout failures become one row with a count, not 300 rows.  ', options: { color: C.MUT } },
        { text: 'The honest cost: ', options: { bold: true, color: C.AMB } },
        { text: '"Port 22 closed" and "Port 443 closed" collapse together too.', options: { color: C.MUT } },
    ], { h: 1.0, size: 14 });
}

// -----------------------------------------------------------------------------
// C4. Same incident? - three options. Pick one, delete the other two.
//     The old "Identity is derived, not invented" slide is gone: it showed the
//     answer before anyone knew what the question was.
//     Each option carries a small OPTION chip top right - delete it after pasting.
// -----------------------------------------------------------------------------

// Option A - no code. Four real alerts, one machine name, one incident.
{
    const s = d.slide(
        'OPTION A - no code. Point at the right-hand column: every alert names the machine it is about. Two different tools, four different complaints, one machine name. That name is what groups them. No model, no lookup - it is a string match. If the room wants the fallback order (Azure resource, then app name), that is on the layer-two slide.'
    );
    d.head(s, 'is this the same incident?', 'Same machine, same incident');
    d.chip(s, 10.78, 0.54, 1.9, 'option a · no code', C.DIM);

    s.addText('Four alerts from two different tools. Every one of them names the machine it is about.', {
        x: M, y: 1.62, w: CONTENT_W, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 17, color: C.MUT });

    const top = 2.3, lw = 8.1, rowH = 0.62;
    const alerts = [
        ['storage-watch', 'Disk read latency 480 ms, sustained'],
        ['storage-watch', 'Write queue depth 56, above threshold 8'],
        ['sql-watch',     'Lock wait time 3100 ms on OrderLines'],
        ['sql-watch',     'Connection pool exhausted, 100 of 100'],
    ];
    const lh = 0.55 + alerts.length * rowH + 0.15;
    d.card(s, M, top, lw, lh);
    [['TOOL', 0.3], ['ALERT', 1.9], ['MACHINE', 6.35]].forEach(([t, dx]) =>
        s.addText(t, { x: M + dx, y: top + 0.2, w: 1.6, h: 0.25, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 10, bold: true, color: C.DIM, charSpacing: 1.5 }));
    alerts.forEach((a, i) => {
        const y = top + 0.55 + i * rowH;
        s.addText(a[0], { x: M + 0.3, y, w: 1.55, h: 0.4, isTextBox: true, margin: 0, valign: 'middle',
            fontFace: MONO, fontSize: 12, color: C.DIM });
        s.addText(a[1], { x: M + 1.9, y, w: 4.4, h: 0.4, isTextBox: true, margin: 0, valign: 'middle',
            fontFace: MONO, fontSize: 12, color: C.TXT });
        s.addText('sql-prod-03', { x: M + 6.35, y, w: 1.6, h: 0.4, isTextBox: true, margin: 0, valign: 'middle',
            fontFace: MONO, fontSize: 13, bold: true, color: C.AMB });
    });

    const rx = M + lw + 0.75, rw = M + CONTENT_W - rx;
    d.arrow(s, M + lw + 0.12, top + lh / 2, 0.5, 'right', { color: C.AMB });
    d.card(s, rx, top, rw, lh, C.PANEL2);
    s.addText('ONE INCIDENT', { x: rx + 0.3, y: top + 0.2, w: rw - 0.6, h: 0.25, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 10, bold: true, color: C.DIM, charSpacing: 1.5 });
    s.addText('sql-prod-03', { x: rx + 0.3, y: top + 0.75, w: rw - 0.6, h: 0.5, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 22, bold: true, color: C.AMB });
    s.addText('4 symptoms  ·  2 tools', { x: rx + 0.3, y: top + 1.4, w: rw - 0.6, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, color: C.TXT });
    s.addText('grouped by the name alone', { x: rx + 0.3, y: top + 1.85, w: rw - 0.6, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 14, italic: true, color: C.GRN });

    d.callout(s, top + lh + 0.35, [
        { text: 'Group by the machine name.  ', options: { bold: true, color: C.WHT } },
        { text: 'Any alert that says sql-prod-03 lands in the sql-prod-03 incident, whichever tool sent it. ' +
                'No model, no lookup table - a string match.', options: { color: C.MUT } },
    ], { h: 1.0, size: 17 });
}

// Option B - follow one alert through the three steps. Real values throughout.
{
    const s = d.slide(
        'OPTION B - follow one alert. Step one is a real alert from the demo. Step two: we pick the one label to group on - the machine name if the alert has one, otherwise the Azure resource, otherwise the app name. Step three: that label is hashed into the incident id. inc-de92ae29a9bb is the real id for sql-prod-03. The punchline is the callout: every other alert about that machine computes the same id, so it lands in the same incident without anyone searching for it.'
    );
    d.head(s, 'is this the same incident?', 'Follow one alert');
    d.chip(s, 10.78, 0.54, 1.9, 'option b · walkthrough', C.DIM);

    const steps = [
        [C.BLU, 'An alert arrives',               'sql-watch  ·  Lock wait 3100 ms  ·  sql-prod-03', C.TXT,
            'Tool, what went wrong, and which machine.'],
        [C.AMB, 'Pick the label to group on',      'host:sql-prod-03', C.AMB,
            'The machine name if it has one. Otherwise the Azure resource, then the app name.'],
        [C.GRN, 'Turn the label into an id',       'inc-de92ae29a9bb', C.GRN,
            'A hash of the label. Same label in, same id out - every time.'],
    ];
    const y0 = 1.8, h = 1.12, pitch = 1.3;
    steps.forEach((st, i) => {
        const y = y0 + i * pitch;
        d.card(s, M, y, CONTENT_W, h);
        d.badge(s, M + 0.32, y + (h - 0.52) / 2, 0.52, st[0], String(i + 1));
        s.addText(st[1], { x: M + 1.05, y: y + 0.2, w: 4.2, h: 0.42, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 20, bold: true, color: C.TXT });
        s.addText(st[4], { x: M + 1.05, y: y + 0.62, w: 4.4, h: 0.42, isTextBox: true, margin: 0, valign: 'top',
            fontFace: SANS, fontSize: 12, color: C.MUT });
        s.addText(st[2], { x: M + 5.6, y: y + 0.2, w: 6.2, h: h - 0.4, isTextBox: true, margin: 0, valign: 'middle',
            fontFace: MONO, fontSize: i === 0 ? 15 : 20, bold: i > 0, color: st[3] });
        if (i < steps.length - 1) d.arrow(s, M + 0.58, y + h + 0.02, 0.16, 'down', { color: C.DIM });
    });

    d.callout(s, y0 + steps.length * pitch + 0.1, [
        { text: 'The next alert about sql-prod-03 - from any tool - computes ', options: { color: C.MUT } },
        { text: 'inc-de92ae29a9bb', options: { bold: true, color: C.GRN, fontFace: MONO } },
        { text: ' too.  ', options: { color: C.MUT } },
        { text: 'Same incident, and nobody had to look anything up.', options: { bold: true, color: C.WHT } },
    ], { h: 0.95, size: 17 });
}

// Option C - the code, but only after the question is on the screen.
{
    const s = d.slide(
        'OPTION C - the code, set up first. Read the subtitle before touching the code: we do not search for an incident, we calculate its id. Two lines do it, and the comments show the real values. Then the two cards: different tools, different complaints, same id. Save the "why" for the callout - two workers handling alerts for the same machine at the same moment would both search, both miss and both create an incident. Calculating the id means they both write to the same row.'
    );
    d.head(s, 'correlation.psm1  ·  is this the same incident?', 'Calculate the incident, don\'t search for it');
    d.chip(s, 10.78, 0.54, 1.9, 'option c · code', C.DIM);

    s.addText('Every alert has to land in an incident. Instead of looking one up, we calculate its id from the alert itself.', {
        x: M, y: 1.62, w: CONTENT_W, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 17, color: C.MUT });

    const ch = d.codePanel(s, M, 2.2, CONTENT_W, null, null, [
        ['$key = Get-PrimaryKey $Event                     # "host:sql-prod-03"', C.AMB],
        ['$id  = \'inc-\' + (Sha256 $key).Substring(0, 12)   # "inc-de92ae29a9bb"', C.GRN],
    ], { size: 16 });

    const cy = 2.2 + ch + 0.3, cw = (CONTENT_W - 0.4) / 2, cardH = 1.3;
    [['storage-watch', 'Disk read latency 480 ms, sustained'],
     ['sql-watch',     'Lock wait time 3100 ms on OrderLines']].forEach((c, i) => {
        const x = M + i * (cw + 0.4);
        d.card(s, x, cy, cw, cardH);
        s.addText(c[0] + '  ·  sql-prod-03', { x: x + 0.3, y: cy + 0.18, w: cw - 0.6, h: 0.3, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 12, color: C.DIM });
        s.addText(c[1], { x: x + 0.3, y: cy + 0.48, w: cw - 0.6, h: 0.3, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 12, color: C.TXT });
        s.addText('->  inc-de92ae29a9bb', { x: x + 0.3, y: cy + 0.84, w: cw - 0.6, h: 0.32, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 15, bold: true, color: C.GRN });
    });

    d.callout(s, cy + cardH + 0.3, [
        { text: 'Why calculate it?  ', options: { bold: true, color: C.WHT } },
        { text: 'Two workers can handle alerts for the same machine at the same moment. If both searched for an open ' +
                'incident, both would miss and both would create one. A calculated id means they both write to the same row.',
          options: { color: C.MUT } },
    ], { h: 1.05, size: 15 });
}

// -----------------------------------------------------------------------------
// C5. The AI stage
// -----------------------------------------------------------------------------
{
    const s = d.slide(
        'Deflate the AI stage deliberately. It is one HTTP call with temperature zero and a JSON contract. The interesting engineering is everywhere except here - and that is the honest shape of most production AI features.'
    );
    d.head(s, 'ai.psm1  ·  the model call is 29 lines of it', 'Asking the model is the easy part', { eyebrowColor: C.RED });

    const h5 = d.codePanel(s, M, 1.95, CONTENT_W, null, null, [
        ['$body = @{', C.TXT],
        ['    messages = @(', C.MUT],
        ['        @{ role = \'system\'; content = $SystemPrompt }', C.MUT],
        ['        @{ role = \'user\';   content = ($incidents | ConvertTo-Json -Depth 8) }', C.MUT],
        ['    )', C.MUT],
        ['    temperature     = 0                          # same events, same answer', C.AMB],
        ['    response_format = @{ type = \'json_object\' }   # not prose, a contract', C.AMB],
        ['}', C.TXT],
        ['', C.MUT],
        ['Invoke-RestMethod -Uri $uri -Method Post -Body ($body | ConvertTo-Json -Depth 10) `', C.TXT],
        ['    -Headers @{ Authorization = "Bearer $(Get-ResourceToken ...)" }  # managed identity', C.GRN],
    ], { size: 13 });

    d.callout(s, 1.95 + h5 + 0.35, [
        { text: 'The prompt is 698 words. The code that sends it is 29 lines. ',
          options: { bold: true, color: C.WHT } },
        { text: 'Everything else in this repo exists to make sure the question is worth asking.',
          options: { color: C.MUT } },
    ], { h: 0.95, size: 17 });
}

// -----------------------------------------------------------------------------
// C6. Where the lines actually are
// -----------------------------------------------------------------------------
{
    const s = d.slide(
        'The closing code slide, and the one that makes the argument. Ninety-seven percent of the code is not AI. If they remember one number from the technical half of the session, make it this one.'
    );
    d.head(s, '912 lines of powershell', 'Where the lines actually are');

    const parts = [
        ['The dashboard endpoint',    'GetIncidents',     256, C.BLU],
        ['The AI stage (100 is the prompt)', 'Ai.psm1',   244, C.RED],
        ['Deterministic correlation', 'Correlation.psm1', 138, C.AMB],
        ['Normalising three shapes',  'Normalize.psm1',   122, C.BLU],
        ['Table Storage plumbing',    'Plumbing.psm1',     88, C.DIM],
        ['The Event Hubs trigger',    'IngestEvents',      33, C.GRN],
        ['Timer + HTTP triggers',     'Analyze*',          31, C.GRN],
    ];
    const maxLines = 256, barMax = 5.4, x0 = 5.9;

    parts.forEach((p, i) => {
        const y = 1.95 + i * 0.52;
        s.addText(p[0], { x: M, y: y + 0.02, w: 3.3, h: 0.35, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 15, color: C.TXT });
        s.addText(p[1], { x: M + 3.35, y: y + 0.05, w: 1.9, h: 0.3, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 11, color: C.DIM });
        s.addShape(d.pres.ShapeType.rect, {
            x: x0, y: y + 0.06, w: Math.max(0.06, barMax * p[2] / maxLines), h: 0.26,
            fill: { color: p[3] } });
        s.addText(String(p[2]), {
            x: x0 + barMax + 0.15, y: y + 0.02, w: 0.8, h: 0.32, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 15, bold: true, color: C.TXT });
    });

    d.callout(s, 5.85, [
        { text: 'The model call is 29 of those lines. ', options: { bold: true, color: C.GRN } },
        { text: 'Ninety-seven percent of this is plumbing, normalising and arithmetic - which is ' +
                'roughly the ratio you should expect from any AI feature that actually ships.',
          options: { color: C.TXT } },
    ], { h: 1.0, size: 16 });
}

// #############################################################################
// SECTION 2 - LAYOUT CATALOGUE
// #############################################################################

// -----------------------------------------------------------------------------
// L1. Statement slide
// -----------------------------------------------------------------------------
{
    const s = d.slide('LAYOUT: statement. One idea, no supporting text. Use it when you want the room looking at you rather than the screen.');
    s.addText('STATEMENT SLIDE', {
        x: M, y: 2.5, w: 11, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 14, bold: true, color: C.AMB, charSpacing: 4 });
    s.addText('The loudest thing is almost never the cause.', {
        x: M, y: 3.0, w: 11.5, h: 1.4, isTextBox: true, margin: 0, lineSpacing: 52,
        fontFace: SANS, fontSize: 44, bold: true, color: C.WHT });
    s.addText('A one-line qualifier lives here, if it needs one.', {
        x: M, y: 4.5, w: 10, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 17, color: C.MUT, italic: true });
}

// -----------------------------------------------------------------------------
// L2. Three cards across
// -----------------------------------------------------------------------------
{
    const s = d.slide('LAYOUT: three-card row. Comparisons, taxonomies, before/during/after. Works with two to four items; the helper sizes them to the content width.');
    d.head(s, 'eyebrow goes here', 'Three cards across');
    d.cardRow(s, [
        { color: C.BLU, title: 'First thing', sub: 'The question it answers?',
          body: 'Two lines of supporting detail, no more than about twenty words.',
          foot: 'A closing beat.' },
        { color: C.AMB, title: 'Second thing', sub: 'The question it answers?',
          body: 'Keep the three bodies roughly the same length or the row looks broken.',
          foot: 'A closing beat.' },
        { color: C.RED, title: 'Third thing', sub: 'The question it answers?',
          body: 'The last card is where the argument lands, so give it the accent colour.',
          foot: 'A closing beat.' },
    ]);
    s.addText('The line under the row is where you say what the three add up to.', {
        x: M, y: 6.3, w: CONTENT_W, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 17, bold: true, color: C.WHT });
}

// -----------------------------------------------------------------------------
// L3. Stacked rows
// -----------------------------------------------------------------------------
{
    const s = d.slide('LAYOUT: numbered rows. Sequences, lists of three or four, anything where order matters. Three rows breathe; four is the maximum before it gets cramped.');
    d.head(s, 'eyebrow goes here', 'Stacked rows');
    d.rows(s, [
        { color: C.AMB, title: 'A bold statement per row',
          body: 'And one line of detail underneath it, in muted grey.' },
        { color: C.BLU, title: 'The rows are full content width',
          body: 'Which makes them read faster than columns from the back of a room.' },
        { color: C.GRN, title: 'Three is the comfortable number',
          body: 'Four fits. Five means the slide wants to be two slides.' },
    ]);
}

// -----------------------------------------------------------------------------
// L4. Two panels
// -----------------------------------------------------------------------------
{
    const s = d.slide('LAYOUT: two panels. Limits and costs, pros and cons, before and after. Both panels are the same width - the numbers here are correct, do not eyeball it.');
    d.head(s, 'eyebrow goes here', 'Two panels, equal weight', { eyebrowColor: C.RED });

    d.card(s, M, 1.95, 5.75, 4.35);
    s.addText('The left one', {
        x: M + 0.35, y: 2.2, w: 5.05, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 21, bold: true, color: C.RED });
    s.addText([
        { text: 'A short bullet', options: { bullet: true, breakLine: true } },
        { text: 'Another short bullet', options: { bullet: true, breakLine: true } },
        { text: 'Keep them to one line each where you can', options: { bullet: true, breakLine: true } },
        { text: 'Five is the ceiling', options: { bullet: true } },
    ], { x: M + 0.4, y: 2.62, w: 5.0, h: 3.3, isTextBox: true, margin: 0, valign: 'top',
         fontFace: SANS, fontSize: 15, color: C.MUT, paraSpaceAfter: 10, bullet: { indent: 14 } });

    d.card(s, 6.95, 1.95, 5.75, 4.35);
    s.addText('The right one', {
        x: 7.3, y: 2.2, w: 5.1, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 21, bold: true, color: C.GRN });
    [['~3.5k', 'a number worth saying out loud, with its unit spelled out beside it'],
     ['1/min', 'the second number'],
     ['0',     'the third number - zero is the most persuasive one you have']]
        .forEach((c, i) => {
            const y = 2.8 + i * 1.15;
            s.addText(c[0], { x: 7.3, y, w: 1.55, h: 0.55, isTextBox: true, margin: 0,
                fontFace: SANS, fontSize: 27, bold: true, color: C.TXT });
            s.addText(c[1], { x: 8.95, y: y + 0.04, w: 3.5, h: 0.8, isTextBox: true, margin: 0,
                fontFace: SANS, fontSize: 14, color: C.MUT });
        });
}

// -----------------------------------------------------------------------------
// L5. Causal chain
// -----------------------------------------------------------------------------
{
    const s = d.slide('LAYOUT: chain. Cause at the top, consequences below, triangles between. The colour of the top badge is the whole point.');
    d.head(s, 'eyebrow goes here', 'A chain of consequences');

    const chain = [
        [C.AMB, 'first-host', 'warning', 'The quiet thing that started it, described in one line.'],
        [C.RED, 'second-host', 'critical', 'What that did downstream, on a different machine.'],
        [C.RED, 'third-host', 'critical', 'What the user actually noticed.'],
    ];
    chain.forEach((c, i) => {
        const y = 1.95 + i * 1.32;
        d.card(s, M, y, CONTENT_W, 1.08);
        d.badge(s, M + 0.3, y + 0.27, 0.55, c[0], String(i + 1));
        s.addText(c[1], { x: M + 1.05, y: y + 0.18, w: 2.4, h: 0.4, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 16, bold: true, color: C.TXT });
        s.addText(c[2], { x: M + 1.05, y: y + 0.6, w: 2.4, h: 0.32, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 13, bold: true, color: c[0] });
        s.addText(c[3], { x: M + 3.6, y: y + 0.31, w: 8.2, h: 0.5, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 15, color: C.MUT });
        if (i < chain.length - 1) s.addShape(d.pres.ShapeType.triangle, {
            x: M + 0.49, y: y + 1.14, w: 0.17, h: 0.13, rotate: 180, fill: { color: C.DIM } });
    });

    d.callout(s, 5.85, [
        { text: 'DO NOW  ', options: { bold: true, color: C.GRN } },
        { text: 'The concrete first action, naming the thing to act on.', options: { color: C.TXT } },
    ], { h: 0.95 });
}

// -----------------------------------------------------------------------------
// L6. Log wall
// -----------------------------------------------------------------------------
{
    const s = d.slide('LAYOUT: log wall. Real-looking output, monospace, severity coloured. It should be hard to read - that is usually why it is on screen.');
    d.head(s, 'eyebrow goes here', 'A wall of machine output', { eyebrowColor: C.RED });
    d.logWall(s, [
        ['16:54:31', 'critical', 'sql-watch      sql-prod-03    Connection pool exhausted, 97 of 100 in use'],
        ['16:54:30', 'error',    'storage-watch  sql-prod-03    Disk read latency 480 ms, sustained'],
        ['16:54:29', 'warning',  'backup-agent   backup-01      Nightly backup still running, 4 hours over window'],
        ['16:54:28', 'critical', 'apm            app-web-01     Checkout failures 27 percent of requests'],
        ['16:54:27', 'info',     'net-monitor    fw-edge-01     Carrier maintenance window opened'],
    ]);
    s.addText('The question you want them holding while they read it.', {
        x: M, y: 4.2, w: CONTENT_W, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 20, bold: true, color: C.WHT });
}

// -----------------------------------------------------------------------------
// L7. Process flow
// -----------------------------------------------------------------------------
{
    const s = d.slide('LAYOUT: flow. Architecture, pipelines, stages. Five boxes is the comfortable maximum at this width; four reads better.');
    d.head(s, 'eyebrow goes here', 'A flow, left to right');

    const stages = [
        ['Stage one', 'what\nhappens\nhere', C.BLU],
        ['Stage two', 'what\nhappens\nhere', C.MUT],
        ['Stage three', 'what\nhappens\nhere', C.AMB],
        ['Stage four', 'what\nhappens\nhere', C.MUT],
        ['Stage five', 'what\nhappens\nhere', C.RED],
    ];
    const bw = 2.15, gap = 0.32;
    stages.forEach((st, i) => {
        const x = M + i * (bw + gap);
        d.card(s, x, 2.35, bw, 2.15);
        d.dot(s, x + bw / 2 - 0.11, 2.12, st[2]);
        s.addText(st[0], { x, y: 2.6, w: bw, h: 0.4, isTextBox: true, margin: 0, align: 'center',
            fontFace: SANS, fontSize: 18, bold: true, color: C.TXT });
        s.addText(st[1], { x: x + 0.15, y: 3.12, w: bw - 0.3, h: 1.2, isTextBox: true, margin: 0,
            align: 'center', lineSpacing: 17, fontFace: MONO, fontSize: 11, color: C.MUT });
        if (i < stages.length - 1) s.addText('>', {
            x: x + bw, y: 3.15, w: gap, h: 0.4, isTextBox: true, margin: 0, align: 'center',
            fontFace: SANS, fontSize: 20, bold: true, color: C.DIM });
    });

    d.callout(s, 4.95, [
        { text: 'The thing about the diagram that is not obvious from the diagram. ',
          options: { bold: true, color: C.WHT } },
        { text: 'Usually a design decision and why it was made that way.', options: { color: C.MUT } },
    ], { h: 1.35, size: 15 });
}

// -----------------------------------------------------------------------------
// L8. Demo marker
// -----------------------------------------------------------------------------
d.demo('N', 'What you are about to run', [
    'The command, verbatim, so you can read it off the screen',
    'What the room should watch for',
    'The number that should change',
    'The bit that always surprises people',
], 'LAYOUT: demo marker. Warm ground so it is obvious in presenter view that a demo is coming. Put the literal command in the first bullet.');

// -----------------------------------------------------------------------------
// L9. Image / GIF well
// -----------------------------------------------------------------------------
d.imageSlide({
    eyebrow: 'eyebrow goes here',
    hint: 'What image belongs here, described well enough that you can go find it.',
    caption: 'The caption is the joke, or the point.',
    sub: 'And an optional line underneath it.',
    notes: 'LAYOUT: image well. Drop the image over the grey box, then delete the box. The caption stays either way, so the slide still works if the image never turns up.',
});

d.save('staging.pptx').then(f => console.log('wrote', f));
