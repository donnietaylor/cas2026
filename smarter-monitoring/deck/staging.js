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
//  SECTION 1 - code walkthrough. Six slides that give the room a view into the
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
        'The architecture slide. Walk it left to right once, then point at the two things that are not obvious: the dashed loop is the AI pass reading and writing the same table the ingest path writes, and the three LAYER chips are the spine of the session. Roughly ninety seconds; do not narrate every box.'
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
        [C.GRN, '12 monitoring tools', 'Send-Event.ps1', 'REST + SAS, key = host'],
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
    s.addText('monitoring-\nevents\n\n2 partitions\npartition key\n= host', {
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
        [C.AMB, 'Correlate', 'fingerprint, then shared key'],
    ];
    steps.forEach((st, i) => {
        const y = ROW + 0.46 + i * 0.56;
        d.badge(s, 5.35, y + 0.02, 0.28, st[0], String(i + 1));
        s.addText(st[1], { x: 5.72, y, w: 2.5, h: 0.24, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 13, bold: true, color: C.TXT });
        s.addText(st[2], { x: 5.72, y: y + 0.23, w: 2.5, h: 0.22, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 10, color: C.MUT });
    });
    d.chip(s, 5.72, ROW + 2.68, 0.72, 'layer 1', C.AMB);
    d.chip(s, 6.52, ROW + 2.68, 0.72, 'layer 2', C.AMB);
    s.addText('no model involved', {
        x: 7.32, y: ROW + 2.68, w: 0.95, h: 0.22, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 9, color: C.DIM, italic: true });

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
    d.chip(s, 5.35, BOT + 1.26, 0.72, 'layer 3', C.RED);
    s.addText('the only stage that reads English', {
        x: 6.15, y: BOT + 1.26, w: 3.2, h: 0.22, isTextBox: true, margin: 0,
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
    d.head(s, 'pipeline.psm1  ·  176 lines', 'Three shapes, one object', { eyebrowColor: C.BLU });

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
// C3. Dedup
// -----------------------------------------------------------------------------
{
    const s = d.slide(
        'Layer one, in full. Three lines. Say plainly that this is the entire deduplication engine and that it involves no intelligence of any kind - it is a hash of a string with the numbers taken out.'
    );
    d.head(s, 'correlation.psm1  ·  the whole of layer one', 'Deduplication is three lines');

    const h3 = d.codePanel(s, M, 1.95, CONTENT_W, null, null, [
        ['$title = $Event.Title -replace \'\\d+\', \'N\'          # 480 ms and 8 ms are the same symptom', C.AMB],
        ['', C.MUT],
        ['$seed  = "$Source|$Kind|$title|$ResourceId|$Host".ToLowerInvariant()', C.TXT],
        ['', C.MUT],
        ['$hash  = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($seed))', C.TXT],
    ], { size: 14 });

    const y3 = 1.95 + h3 + 0.35;
    d.card(s, M, y3, 5.75, 1.9);
    s.addText('What goes in', {
        x: M + 0.35, y: y3 + 0.17, w: 5.05, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, bold: true, color: C.MUT });
    s.addText('Disk read latency 410 ms, sustained\nDisk read latency 455 ms, sustained\nDisk read latency 480 ms, sustained', {
        x: M + 0.35, y: y3 + 0.57, w: 5.05, h: 1.1, isTextBox: true, margin: 0, lineSpacing: 19,
        fontFace: MONO, fontSize: 12, color: C.MUT });

    d.card(s, 6.95, y3, 5.75, 1.9, C.PANEL2);
    s.addText('What comes out', {
        x: 7.3, y: y3 + 0.17, w: 5.05, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, bold: true, color: C.GRN });
    s.addText('Disk read latency N ms, sustained', {
        x: 7.3, y: y3 + 0.6, w: 5.05, h: 0.35, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 13, color: C.TXT });
    s.addText('one row  ·  seen 3 times', {
        x: 7.3, y: y3 + 1.1, w: 5.05, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, bold: true, color: C.AMB });
}

// -----------------------------------------------------------------------------
// C4. Derived identity
// -----------------------------------------------------------------------------
{
    const s = d.slide(
        'Layer two. The ordering is the interesting bit - trace is last on purpose because every request has its own, so it is the worst grouping key available. Then the id is derived from the key rather than generated, which is what makes the whole thing safe under concurrency.'
    );
    d.head(s, 'correlation.psm1  ·  the whole of layer two', 'Identity is derived, not invented');

    const h4 = d.codePanel(s, M, 1.95, CONTENT_W, null, null, [
        ['function Get-PrimaryKey {', C.TXT],
        ['    if ($Event.Host)       { return "host:$($Event.Host)" }', C.AMB],
        ['    if ($Event.ResourceId) { return "resource:$($Event.ResourceId)" }', C.MUT],
        ['    if ($Event.Service)    { return "service:$($Event.Service)" }', C.MUT],
        ['    if ($Event.TraceId)    { return "trace:$($Event.TraceId)" }   # last: one per request', C.DIM],
        ['}', C.TXT],
        ['', C.MUT],
        ['$incidentId = \'inc-\' + (Sha256 $primaryKey).Substring(0, 12)', C.GRN],
    ], { size: 15 });

    d.callout(s, 1.95 + h4 + 0.35, [
        { text: 'Two workers, one row. ', options: { bold: true, color: C.GRN } },
        { text: 'The hub has two partitions, so two invocations correlate the same host at the same ' +
                'instant. Because the id is computed from the key rather than generated, they both ' +
                'write to the same incident - and the loser of the race gets a 409 it can ignore.',
          options: { color: C.TXT } },
    ], { h: 1.25, size: 15 });
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
    d.head(s, '1,151 lines of powershell', 'Where the lines actually are');

    const parts = [
        ['Deterministic correlation', 'Correlation.psm1', 348, C.AMB],
        ['The AI stage',              'Ai.psm1',          290, C.RED],
        ['The dashboard endpoint',    'GetIncidents',     272, C.BLU],
        ['Normalising three shapes',  'Pipeline.psm1',    176, C.BLU],
        ['The Event Hubs trigger',    'IngestEvents',      34, C.GRN],
        ['Timer + HTTP triggers',     'Analyze*',          31, C.GRN],
    ];
    const maxLines = 348, barMax = 5.4, x0 = 5.9;

    parts.forEach((p, i) => {
        const y = 1.95 + i * 0.62;
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
