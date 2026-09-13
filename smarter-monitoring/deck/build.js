// =============================================================================
//  SUPERSEDED - DO NOT RUN THIS OVER THE DECK
// =============================================================================
//
//  This script generated the FIRST draft of smarter-monitoring.pptx. The deck
//  has since been edited by hand in PowerPoint: GIFs were added and a couple of
//  slides were removed. Running `node build.js` again would overwrite all of
//  that and put the placeholder wells back.
//
//  The .pptx is the source of truth from here. Make slide changes in PowerPoint.
//
//  Kept in the repo because it documents how the deck was laid out - the
//  palette, the grid, the card and badge helpers - which is useful if the deck
//  ever needs rebuilding from scratch, or if a second session wants to match it.
//
//  Last state it produced: 24 slides, five GIF placeholder wells.
//  Current deck: 22 slides, 3 GIFs, wells removed.
// =============================================================================

const pptxgen = require('pptxgenjs');

// --- palette -----------------------------------------------------------------
// The deck lives in the same colour language as the dashboard it demos: a dark
// console ground, with severity as the only saturated colour on the slide. The
// punchline of the whole talk is that the cause was amber, not red, so amber
// has to mean something everywhere it appears.
const BG    = '0E1621';
const PANEL = '19242F';
const PANEL2= '223140';
const TXT   = 'E9EFF6';
const MUT   = '8FA3B8';
const DIM   = '7C90A6';
const RED   = 'E0443E';
const AMB   = 'E8A33D';
const GRN   = '46B98A';
const BLU   = '5B9BD5';
const WHT   = 'FFFFFF';

const SANS = 'Calibri';
const MONO = 'Courier New';

const W = 13.333, H = 7.5, M = 0.65;

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE';
pres.author = 'Donnie Taylor';
pres.title  = 'Smarter Monitoring: Building an AI-Enhanced Event Pipeline';

function slide(notes) {
    const s = pres.addSlide();
    s.background = { color: BG };
    if (notes) s.addNotes(notes);
    return s;
}

// Section eyebrow + title, the standard head for a content slide.
function head(s, eyebrow, title, opts = {}) {
    const y = opts.y ?? 0.5;
    if (eyebrow) {
        s.addText(eyebrow.toUpperCase(), {
            x: M, y: y, w: 11, h: 0.3, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 12, bold: true, color: opts.eyebrowColor || AMB, charSpacing: 2
        });
    }
    s.addText(title, {
        x: M, y: y + 0.32, w: opts.tw ?? 11.8, h: 0.75, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: opts.size ?? 36, bold: true, color: TXT
    });
}

// The repeated motif: a filled circle carrying a glyph or number.
function badge(s, x, y, d, fill, label, labelColor) {
    s.addShape(pres.ShapeType.ellipse, { x, y, w: d, h: d, fill: { color: fill } });
    s.addText(label, {
        x, y, w: d, h: d, isTextBox: true, margin: 0, align: 'center', valign: 'middle',
        fontFace: SANS, fontSize: d > 0.55 ? 17 : 13, bold: true, color: labelColor || BG
    });
}

function card(s, x, y, w, h, fill) {
    s.addShape(pres.ShapeType.roundRect, {
        x, y, w, h, rectRadius: 0.06, fill: { color: fill || PANEL }
    });
}

// =============================================================================
// 1. Title
// =============================================================================
{
    const s = slide(
        'Open cold. Do not introduce yourself yet - go straight to the firehose slide and let them try to find the cause. Come back to who you are after they have felt the problem.'
    );
    s.addText('SMARTER MONITORING', {
        x: M, y: 2.15, w: 12, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, bold: true, color: AMB, charSpacing: 4
    });
    s.addText('Building an AI-Enhanced\nEvent Pipeline', {
        x: M, y: 2.6, w: 11.5, h: 1.9, isTextBox: true, margin: 0, lineSpacing: 52,
        fontFace: SANS, fontSize: 46, bold: true, color: WHT
    });
    s.addText('Correlating events from everywhere into the two that matter.', {
        x: M, y: 4.55, w: 10, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 17, color: MUT, italic: true
    });
    s.addText('Donnie Taylor   ·   The Cloud & AI Summit 2026', {
        x: M, y: 5.5, w: 10, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, color: TXT
    });

    // Three quiet severity dots, bottom right - the motif, introduced.
    [RED, AMB, GRN].forEach((c, i) =>
        s.addShape(pres.ShapeType.ellipse, { x: 11.64 + i * 0.42, y: 6.35, w: 0.22, h: 0.22, fill: { color: c } }));
}

// =============================================================================
// 2. The firehose
// =============================================================================
{
    const s = slide(
        'This is the cold open. Read two or three lines out loud, then stop talking and let the room look. Ask it straight: which one caused the others? Take a couple of guesses from the audience - people usually pick a critical. Nobody picks the backup job. That is the whole talk in thirty seconds.'
    );
    head(s, 'three minutes of production', '179 events. 12 tools. One cause.', { eyebrowColor: RED });

    const lines = [
        ['16:54:31', 'critical', 'sql-watch      sql-prod-03    Connection pool exhausted, 97 of 100 in use'],
        ['16:54:30', 'error   ', 'storage-watch  sql-prod-03    Disk read latency 480 ms, sustained'],
        ['16:54:30', 'critical', 'apm            app-web-01     Checkout failures 27 percent of requests'],
        ['16:54:29', 'error   ', 'auth-svc       app-api-03     Token validation failing, upstream returned 526'],
        ['16:54:28', 'warning ', 'net-monitor    fw-edge-01     Packet loss 2 percent on WAN interface'],
        ['16:54:28', 'critical', 'store-api      sql-prod-03    Call to sql-prod-03 failed (500)'],
        ['16:54:27', 'warning ', 'backup-agent   backup-01      Nightly backup of sql-prod-03 still running, 4 hours over window'],
        ['16:54:27', 'error   ', 'sql-watch      sql-prod-03    Lock wait time 4400 ms on OrderLines'],
        ['16:54:26', 'critical', 'cert-watch     lb-edge-02     TLS certificate for api.contoso.com expired'],
        ['16:54:26', 'warning ', 'vsphere        esx-04         Datastore DS-VOL-02 at 82 percent capacity'],
        ['16:54:25', 'critical', 'synthetic      probe-dfw      Login journey failing from 3 of 4 regions'],
        ['16:54:25', 'error   ', 'apm            app-web-01     Payments database connection timeout after 1500 ms'],
        ['16:54:24', 'warning ', 'patch-agent    win-print-02   Reboot pending for 11 days'],
    ];
    const sevColor = { 'critical': RED, 'error   ': AMB, 'warning ': DIM };

    card(s, M, 1.75, 12.05, 4.5, PANEL);
    lines.forEach((ln, i) => {
        const y = 1.90 + i * 0.325;
        s.addText(ln[0], { x: M + 0.25, y, w: 1.0, h: 0.3, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 11, color: DIM });
        s.addText(ln[1].trim(), { x: M + 1.3, y, w: 0.85, h: 0.3, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 11, bold: true, color: sevColor[ln[1]] });
        s.addText(ln[2], { x: M + 2.25, y, w: 9.5, h: 0.3, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 11, color: MUT });
    });

    s.addText('...and 166 more.', {
        x: M + 0.25, y: 6.3, w: 4, h: 0.3, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 12, color: DIM, italic: true
    });
    s.addText('Which one caused the rest?', {
        x: 7.6, y: 6.28, w: 5.1, h: 0.4, isTextBox: true, margin: 0, align: 'right',
        fontFace: SANS, fontSize: 20, bold: true, color: WHT
    });
}

// A slide built around one image. The well is a placeholder: drop the GIF on
// top of it, then delete the well. The caption underneath is the joke and stays
// either way, so the slide still works if the GIF never gets found.
function gifSlide(opts) {
    const s = slide(opts.notes);
    if (opts.eyebrow) {
        s.addText(opts.eyebrow.toUpperCase(), {
            x: M, y: 0.5, w: 11, h: 0.3, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 12, bold: true, color: opts.eyebrowColor || AMB, charSpacing: 2
        });
    }

    const wellW = 7.0, wellH = 3.94, wellX = (W - wellW) / 2, wellY = 1.15;
    card(s, wellX, wellY, wellW, wellH, PANEL);

    s.addText('DROP GIF HERE', {
        x: wellX, y: wellY + 1.35, w: wellW, h: 0.45, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 20, bold: true, color: AMB, charSpacing: 3
    });
    s.addText(opts.hint, {
        x: wellX + 0.6, y: wellY + 1.9, w: wellW - 1.2, h: 0.6, isTextBox: true, margin: 0,
        align: 'center', valign: 'top', fontFace: SANS, fontSize: 15, color: MUT
    });
    s.addText('about 1000 px wide  ·  under 3 MB  ·  cover this box, then delete it', {
        x: wellX, y: wellY + 2.75, w: wellW, h: 0.35, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 12, color: DIM, italic: true
    });

    s.addText(opts.caption, {
        x: M, y: 5.42, w: 12.05, h: 0.95, isTextBox: true, margin: 0, align: 'center',
        valign: 'top', fontFace: SANS, fontSize: opts.captionSize || 27, bold: true, color: WHT
    });
    if (opts.sub) {
        s.addText(opts.sub, {
            x: M, y: 6.35, w: 12.05, h: 0.4, isTextBox: true, margin: 0, align: 'center',
            fontFace: SANS, fontSize: 15, color: MUT, italic: true
        });
    }
    return s;
}

// =============================================================================
// GIF A - after the firehose
// =============================================================================
gifSlide({
    eyebrow: 'meanwhile, in the on-call channel',
    eyebrowColor: RED,
    hint: '"This is fine" - the dog at the table in the burning room.',
    caption: 'Nobody finds it by reading faster.',
    sub: 'Two seconds on this. Do not explain the joke.',
    notes: 'Land it and move. The room has just failed to find the cause, so this is a release valve, not a bit. If it gets a laugh, ride it straight into the introduction.'
});

// =============================================================================
// 4. Who I am
// =============================================================================
{
    const s = slide('Keep this to sixty seconds. They came for the pipeline, not the resume.');
    head(s, 'before we go further', 'Donnie Taylor');

    const rows = [
        [AMB, 'Microsoft MVP, ninth consecutive year', 'Endpoint management, Azure, PowerShell, and increasingly AI plumbing.'],
        [BLU, 'DFWSMUG group leader', 'North Texas systems management user group.'],
        [GRN, 'Everything here is on GitHub', 'github.com/donnietaylor - deploy it in your own tenant in about ten minutes.'],
    ];
    rows.forEach((r, i) => {
        const y = 1.95 + i * 1.25;
        badge(s, M, y, 0.52, r[0], String(i + 1));
        s.addText(r[1], { x: M + 0.85, y: y - 0.04, w: 10.5, h: 0.4, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 20, bold: true, color: TXT });
        s.addText(r[2], { x: M + 0.85, y: y + 0.38, w: 10.5, h: 0.4, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 15, color: MUT });
    });

    s.addText('draith.com   ·   linkedin.com/in/donnietaylor   ·   @donnietaylor.bsky.social', {
        x: M, y: 6.35, w: 12, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 14, color: DIM
    });
}

// =============================================================================
// 4. Sponsor placeholder
// =============================================================================
{
    const s = slide('Replace this entire slide with the sponsor slide CAS emails you. Do not skip it - sponsors are why the ticket price is what it is.');
    card(s, 2.4, 2.75, 8.5, 1.85, PANEL);
    s.addText('SPONSOR SLIDE', {
        x: 2.4, y: 3.1, w: 8.5, h: 0.5, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 26, bold: true, color: AMB, charSpacing: 3
    });
    s.addText('Drop in the slide CAS sends. Delete this placeholder.', {
        x: 2.4, y: 3.75, w: 8.5, h: 0.4, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 16, color: MUT
    });
}

// =============================================================================
// 5. Three things called correlation
// =============================================================================
{
    const s = slide(
        'This slide is what makes the rest of the session legible. Most monitoring tools do the first. Some do the second. Almost nothing does the third, and the third is what the on-call engineer actually needs at 3am.'
    );
    head(s, 'the word does a lot of work', 'Three different things, one word');

    const cols = [
        [BLU, 'Deduplication', 'Is this the same thing I already saw?', 'Same failure, 300 times. One row, count 300.', 'Most tools do this.'],
        [AMB, 'Grouping', 'Do these belong to the same incident?', 'Same host, same resource, same trace.', 'Some tools do this.'],
        [RED, 'Causality', 'Did this one cause that one?', 'A backup job on one host starved a database on another.', 'Almost nothing does this.'],
    ];
    cols.forEach((c, i) => {
        const x = M + i * 4.15;
        card(s, x, 1.95, 3.75, 4.05, PANEL);
        badge(s, x + 0.35, 2.3, 0.5, c[0], String(i + 1));
        s.addText(c[1], { x: x + 0.35, y: 3.0, w: 3.05, h: 0.4, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 21, bold: true, color: TXT });
        s.addText(c[2], { x: x + 0.35, y: 3.5, w: 3.05, h: 0.6, isTextBox: true, margin: 0,
            valign: 'top', fontFace: SANS, fontSize: 15, color: c[0], italic: true });
        s.addText(c[3], { x: x + 0.35, y: 4.2, w: 3.05, h: 0.9, isTextBox: true, margin: 0,
            valign: 'top', fontFace: SANS, fontSize: 14, color: MUT });
        s.addText(c[4], { x: x + 0.35, y: 5.35, w: 3.05, h: 0.35, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 13, bold: true, color: DIM });
    });

    s.addText('Only the third one needs a model. That is the argument.', {
        x: M, y: 6.3, w: 12, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 17, bold: true, color: WHT
    });
}

// =============================================================================
// 6. Architecture
// =============================================================================
{
    const s = slide(
        'One diagram, and the only slide that shows plumbing - the demo cannot. Note the two correlation stages are separate on purpose: the deterministic one owns identity, the model never creates or merges an incident.'
    );
    head(s, 'what we are building', 'Five moving parts, none of them exotic');

    const stages = [
        ['Sources',  'OpenTelemetry\nAzure Monitor\n12 tools', BLU],
        ['Event Hub', 'one hub\n2 partitions\npartition by host', MUT],
        ['Function',  'normalize\nfingerprint\ngroup by key', AMB],
        ['Tables',    'raw events\nsymptoms\nincidents', MUT],
        ['AI pass',   'read the text\nfind the cause\nname the action', RED],
    ];
    const bw = 2.15, gap = 0.32;
    stages.forEach((st, i) => {
        const x = M + i * (bw + gap);
        card(s, x, 2.35, bw, 2.15, PANEL);
        s.addShape(pres.ShapeType.ellipse, { x: x + bw / 2 - 0.11, y: 2.12, w: 0.22, h: 0.22, fill: { color: st[2] } });
        s.addText(st[0], { x: x, y: 2.6, w: bw, h: 0.4, isTextBox: true, margin: 0, align: 'center',
            fontFace: SANS, fontSize: 18, bold: true, color: TXT });
        s.addText(st[1], { x: x + 0.15, y: 3.12, w: bw - 0.3, h: 1.2, isTextBox: true, margin: 0,
            align: 'center', lineSpacing: 17,
            fontFace: MONO, fontSize: 11, color: MUT });
        if (i < stages.length - 1) {
            s.addText('>', { x: x + bw, y: 3.15, w: gap, h: 0.4, isTextBox: true, margin: 0, align: 'center',
                fontFace: SANS, fontSize: 20, bold: true, color: DIM });
        }
    });

    card(s, M, 4.95, 12.05, 1.35, PANEL2);
    s.addText([
        { text: 'The split matters. ', options: { bold: true, color: WHT } },
        { text: 'The deterministic stage owns incident identity - it decides what is one problem. ' +
                'The model only reads and annotates. A model that can rewrite identity is a model that can lose your data.',
          options: { color: MUT } },
    ], { x: M + 0.3, y: 5.2, w: 11.4, h: 0.9, isTextBox: true, margin: 0,
         fontFace: SANS, fontSize: 15 });
}

// =============================================================================
// 7. The three sources
// =============================================================================
{
    const s = slide(
        'Three genuinely different shapes arriving on one hub. The point of the third is that it is fake infrastructure - I am not deploying a SQL box to prove a correlation engine works.'
    );
    head(s, 'everything lands on one hub', 'Where the events come from');

    const src = [
        [BLU, 'OpenTelemetry', 'A real Flask app on this laptop',
         'Requests, dependencies and exceptions, one trace per checkout, exported through Application Insights.'],
        [AMB, 'Azure Monitor', 'A metric alert on failed requests',
         'Common alert schema, straight to the hub via an action group. No glue code.'],
        [GRN, 'Third-party tools', 'Twelve of them, all fictional',
         'sql-watch, storage-watch, backup-agent, cert-watch, net-monitor... a PowerShell script standing in for the estate.'],
    ];
    src.forEach((c, i) => {
        const y = 1.95 + i * 1.5;
        card(s, M, y, 12.05, 1.32, PANEL);
        badge(s, M + 0.32, y + 0.4, 0.52, c[0], String(i + 1));
        s.addText(c[1], { x: M + 1.05, y: y + 0.22, w: 3.2, h: 0.4, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 19, bold: true, color: TXT });
        s.addText(c[2], { x: M + 1.05, y: y + 0.68, w: 3.2, h: 0.4, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 13, color: c[0], italic: true });
        s.addText(c[3], { x: M + 4.5, y: y + 0.3, w: 7.3, h: 0.8, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 14, color: MUT });
    });
}

// =============================================================================
// 8. DEMO marker
// =============================================================================
function demoSlide(n, title, bullets, notes) {
    const s = slide(notes);
    s.addShape(pres.ShapeType.rect, { x: 0, y: 0, w: W, h: H, fill: { color: '15100C' } });
    s.addText(`DEMO ${n}`, {
        x: M, y: 2.25, w: 6, h: 0.45, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, bold: true, color: AMB, charSpacing: 5
    });
    s.addText(title, {
        x: M, y: 2.75, w: 11.5, h: 1.0, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 42, bold: true, color: WHT
    });
    s.addText(bullets.map((b, i) => ({
        text: b, options: { bullet: true, breakLine: i < bullets.length - 1 }
    })), {
        x: M + 0.05, y: 4.05, w: 10.5, h: 1.6, isTextBox: true, margin: 0, valign: 'top',
        fontFace: SANS, fontSize: 16, color: MUT, paraSpaceAfter: 8, bullet: { indent: 14 }
    });
    return s;
}

demoSlide(1, 'Break everything', [
    './Break-Everything.ps1 - one command, one outage',
    'Live checkout traffic starts failing for real',
    'Twelve tools begin reporting, 68 events over about forty seconds',
    'Watch the raw stream arrive in the workbook',
], 'Run it and talk over it. The checkouts going red in the terminal are real HTTP calls against the Flask app on this machine. Do not skip the raw view - that is the "can you find it" screen again, now live.');

// =============================================================================
// 9. Layer 1 - fingerprint
// =============================================================================
{
    const s = slide(
        'No intelligence here at all. A hash of source, kind, host and the title with digit runs collapsed. Be honest about the tradeoff: "Port 22 closed" and "Port 443 closed" collapse together too. Worth it.'
    );
    head(s, 'layer one · no model involved', 'Fingerprinting: the same thing, again');

    card(s, M, 1.95, 7.4, 2.5, PANEL);
    const raw = [
        'Disk read latency 410 ms, sustained',
        'Disk read latency 455 ms, sustained',
        'Disk read latency 480 ms, sustained',
        'Disk read latency 512 ms, sustained',
        'Disk read latency 498 ms, sustained',
        'Disk read latency 466 ms, sustained',
    ];
    raw.forEach((r, i) => s.addText(r, {
        x: M + 0.3, y: 2.12 + i * 0.36, w: 6.9, h: 0.32, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 12, color: MUT
    }));

    s.addText('>', { x: 8.2, y: 3.0, w: 0.5, h: 0.4, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 24, bold: true, color: AMB });

    card(s, 8.85, 2.55, 3.85, 1.3, PANEL2);
    s.addText('Disk read latency N ms, sustained', {
        x: 9.1, y: 2.75, w: 3.35, h: 0.5, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 12, color: TXT });
    s.addText('seen 6 times', {
        x: 9.1, y: 3.3, w: 3.35, h: 0.35, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 14, bold: true, color: AMB });

    card(s, M, 4.75, 12.05, 1.55, PANEL);
    s.addText([
        { text: 'Every run of digits collapses.  ', options: { bold: true, color: WHT } },
        { text: 'Durations, counts, percentages and addresses are values, not identities - so 300 identical ' +
                'checkout failures become one row with a count, not 300 rows.\n', options: { color: MUT } },
        { text: 'The honest cost: ', options: { bold: true, color: AMB } },
        { text: '"Port 22 closed" and "Port 443 closed" now collapse together too.', options: { color: MUT } },
    ], { x: M + 0.3, y: 4.98, w: 11.4, h: 1.1, isTextBox: true, margin: 0,
         fontFace: SANS, fontSize: 15, lineSpacing: 22 });
}

// =============================================================================
// 10. Layer 2 - shared keys
// =============================================================================
{
    const s = slide(
        'Still no model. The incident id is a hash of the primary key, which is why two workers racing on the same host write to the same row instead of creating two incidents. Mention that briefly - it is the kind of detail this audience respects.'
    );
    head(s, 'layer two · still no model', 'Shared keys: the same incident');

    const keys = [
        [BLU, 'resource', 'Azure resource id', 'Everything App Insights exports for one component.'],
        [AMB, 'host', 'sql-prod-03', 'Four tools reporting the same machine - grouped, with nothing but a string match.'],
        [MUT, 'service', 'store-api', 'The role name, when there is no host.'],
        [MUT, 'trace', 'operation id', 'Last on purpose: every request has its own, so it is the worst grouping key there is.'],
    ];
    keys.forEach((k, i) => {
        const y = 1.95 + i * 1.05;
        card(s, M, y, 12.05, 0.9, PANEL);
        s.addShape(pres.ShapeType.ellipse, { x: M + 0.32, y: y + 0.33, w: 0.24, h: 0.24, fill: { color: k[0] } });
        s.addText(k[1], { x: M + 0.78, y: y + 0.24, w: 1.5, h: 0.42, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 15, bold: true, color: TXT });
        s.addText(k[2], { x: M + 2.4, y: y + 0.26, w: 2.6, h: 0.4, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 13, color: k[0] });
        s.addText(k[3], { x: M + 5.2, y: y + 0.26, w: 6.6, h: 0.4, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 14, color: MUT });
    });

    s.addText('Incident identity is a hash of the primary key - so two workers racing on the same host write to the same incident, not two.', {
        x: M, y: 6.3, w: 12, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, color: DIM, italic: true
    });
}

// =============================================================================
// 11. Instrumentation earns the correlation
// =============================================================================
{
    const s = slide(
        'This is the advocacy slide and probably the most useful thing anyone takes home. Five lines of span attributes did work that would otherwise need a model. Say it plainly: good telemetry is cheaper than inference.'
    );
    head(s, 'the part worth arguing about', 'Instrumentation earns the correlation', { eyebrowColor: GRN });

    card(s, M, 1.95, 6.5, 3.1, PANEL);
    s.addText('store_api.py', {
        x: M + 0.3, y: 2.1, w: 5.9, h: 0.3, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 12, color: MUT });
    const code = [
        ['with tracer.start_as_current_span(', TXT],
        ['    "SELECT payments.pending",', MUT],
        ['    kind=trace.SpanKind.CLIENT,', MUT],
        ['    attributes={', MUT],
        ['        "db.system": "mssql",', MUT],
        ['        "server.address": "sql-prod-03",', GRN],
        ['    },', MUT],
        ['):', TXT],
    ];
    code.forEach((c, i) => s.addText(c[0], {
        x: M + 0.3, y: 2.45 + i * 0.29, w: 5.9, h: 0.27, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 12, color: c[1]
    }));

    card(s, 7.55, 1.95, 5.15, 3.1, PANEL2);
    s.addText('What that buys', {
        x: 7.85, y: 2.15, w: 4.6, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 19, bold: true, color: TXT });
    s.addText([
        { text: 'App Insights exports the dependency with Target = sql-prod-03', options: { bullet: true, breakLine: true } },
        { text: 'The pipeline reads that as a host', options: { bullet: true, breakLine: true } },
        { text: 'The app\'s failure joins the database\'s incident', options: { bullet: true, breakLine: true } },
        { text: 'No model. No prompt. No tokens.', options: { bullet: true, bold: true, color: GRN } },
    ], { x: 7.9, y: 2.7, w: 4.5, h: 2.1, isTextBox: true, margin: 0, valign: 'top',
         fontFace: SANS, fontSize: 14, color: MUT, paraSpaceAfter: 9, bullet: { indent: 14 } });

    card(s, M, 5.3, 12.05, 1.0, PANEL);
    s.addText([
        { text: 'Instrument properly and you need less AI. ', options: { bold: true, color: GRN } },
        { text: 'Shared keys are earned by good telemetry. The model is for the link nothing emitted.', options: { color: TXT } },
    ], { x: M + 0.3, y: 5.55, w: 11.4, h: 0.55, isTextBox: true, margin: 0,
         fontFace: SANS, fontSize: 17 });
}

// =============================================================================
// 12. DEMO 2
// =============================================================================
demoSlide(2, 'What two layers of arithmetic can do', [
    '179 events collapse to 26 distinct symptoms, then 13 incidents',
    'Four tools reporting sql-prod-03 arrive as one incident',
    'The laptop app sits inside it, because its span named the host',
    'And the room still cannot see the cause',
], 'Land the last bullet hard. Thirteen incidents is a real improvement and it is still thirteen things to look at. The backup job is sitting there as a warning nobody would open.');

// =============================================================================
// 13. Layer 3 - language
// =============================================================================
{
    const s = slide(
        'Now the model earns its place. The link between backup-01 and sql-prod-03 exists only in English - no shared host, no shared resource, no trace. No amount of key matching finds it.'
    );
    head(s, 'layer three · where the model earns it', 'Some links only exist in the words', { eyebrowColor: RED });

    card(s, M, 2.0, 5.75, 1.55, PANEL);
    s.addShape(pres.ShapeType.ellipse, { x: M + 0.3, y: 2.28, w: 0.22, h: 0.22, fill: { color: AMB } });
    s.addText('backup-01', { x: M + 0.68, y: 2.18, w: 4.6, h: 0.4, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 15, bold: true, color: TXT });
    s.addText('"Nightly backup of sql-prod-03 still running,\n4 hours over window"', {
        x: M + 0.3, y: 2.68, w: 5.15, h: 0.7, isTextBox: true, margin: 0, lineSpacing: 18,
        fontFace: MONO, fontSize: 12, color: MUT });

    card(s, 6.95, 2.0, 5.75, 1.55, PANEL);
    s.addShape(pres.ShapeType.ellipse, { x: 7.25, y: 2.28, w: 0.22, h: 0.22, fill: { color: RED } });
    s.addText('sql-prod-03', { x: 7.63, y: 2.18, w: 4.6, h: 0.4, isTextBox: true, margin: 0,
        fontFace: MONO, fontSize: 15, bold: true, color: TXT });
    s.addText('"Disk read latency 480 ms, sustained"\n"Lock wait 4400 ms - waiting on disk, not on a query"', {
        x: 7.25, y: 2.68, w: 5.15, h: 0.7, isTextBox: true, margin: 0, lineSpacing: 18,
        fontFace: MONO, fontSize: 12, color: MUT });

    s.addText('No shared host.  No shared resource.  No shared trace.  Nothing to match on.', {
        x: M, y: 3.8, w: 12.05, h: 0.4, isTextBox: true, margin: 0, align: 'center',
        fontFace: SANS, fontSize: 17, bold: true, color: DIM });

    card(s, M, 4.4, 12.05, 1.9, PANEL2);
    s.addText('The only thing connecting them is that one of them says the other one\'s name.', {
        x: M + 0.3, y: 4.65, w: 11.4, h: 0.45, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 20, bold: true, color: WHT });
    s.addText('That is a reading comprehension problem, not a data problem. It is the one part of this pipeline ' +
              'that could not be written as a rule - and the cause is a warning, on a host nobody was paging about, ' +
              'underneath twelve criticals.', {
        x: M + 0.3, y: 5.2, w: 11.4, h: 0.9, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 15, color: MUT });
}

// =============================================================================
// GIF B - before the AI pass
// =============================================================================
gifSlide({
    eyebrow: 'the easy way to look clever',
    eyebrowColor: RED,
    hint: 'The conspiracy corkboard - red string connecting everything to everything. ' +
          'Charlie from It\'s Always Sunny is the canonical one.',
    caption: 'Connecting everything is not correlation.',
    sub: 'It is the failure mode that looks most like success.',
    notes: 'This is the best-fitting joke in the deck because the picture IS the point. Set up the next demo with it: the interesting question is not what the model connects, it is what it refuses to connect. Then go run the analysis.'
});

// =============================================================================
// 15. DEMO 3
// =============================================================================
demoSlide(3, 'Ask the model', [
    'One call, every open incident at once - grouping, cause, and the first action',
    'Two root causes found across thirteen incidents',
    'Five things it reviewed and deliberately left alone',
    'Roughly 3,500 tokens and about four seconds',
], 'Point at the red herrings as hard as at the root cause. A correlator that connects everything is as useless as one that connects nothing. The firewall packet loss during carrier maintenance is there to be left alone, and it was.');

// =============================================================================
// GIF C - the reveal
// =============================================================================
gifSlide({
    eyebrow: 'the cause was a warning',
    eyebrowColor: AMB,
    hint: '"Always has been" - the two astronauts, one holding a pistol.',
    caption: 'The loudest thing is almost never the cause.',
    sub: 'Twelve criticals. The answer was an amber warning nobody was paged for.',
    notes: 'Say the top line out loud - it is the single most portable idea in the session and the thing people will repeat to their team on Monday. Then go to the chain slide and walk it.'
});

// =============================================================================
// 16. The answer
// =============================================================================
{
    const s = slide(
        'Flip back here if the room loses the thread during any demo. This is the scenario on one slide.'
    );
    head(s, 'what it found', 'The chain, in the order it happened');

    const chain = [
        [AMB, 'backup-01',   'warning',  'Nightly backup overran its window and is still reading sql-prod-03 at 11 MB/s'],
        [RED, 'sql-prod-03', 'critical', 'Disk saturated, lock waits climbing, connection pool exhausted at 100 of 100'],
        [RED, 'app-web-01',  'critical', 'Checkout failing 27% of requests - timeouts, not application errors'],
    ];
    chain.forEach((c, i) => {
        const y = 1.95 + i * 1.32;
        card(s, M, y, 12.05, 1.08, PANEL);
        badge(s, M + 0.3, y + 0.28, 0.55, c[0], String(i + 1));
        s.addText(c[1], { x: M + 1.05, y: y + 0.2, w: 2.4, h: 0.4, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: 16, bold: true, color: TXT });
        s.addText(c[2], { x: M + 1.05, y: y + 0.62, w: 2.4, h: 0.32, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 13, bold: true, color: c[0] });
        s.addText(c[3], { x: M + 3.6, y: y + 0.33, w: 8.2, h: 0.5, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 15, color: MUT });
        // A real triangle, not a glyph: a text 'v' in a 0.2in gap gets clipped by
        // the card above and reads as dirt on a projector.
        if (i < 2) s.addShape(pres.ShapeType.triangle, {
            x: M + 0.49, y: y + 1.14, w: 0.17, h: 0.13, rotate: 180, fill: { color: DIM } });
    });

    card(s, M, 5.85, 12.05, 0.95, PANEL2);
    s.addText([
        { text: 'DO NOW  ', options: { bold: true, color: GRN } },
        { text: 'Kill job SQL-NIGHTLY-FULL on backup-01 to relieve I/O pressure on sql-prod-03, then recycle the application pool.',
          options: { color: TXT } },
    ], { x: M + 0.3, y: 6.08, w: 11.4, h: 0.5, isTextBox: true, margin: 0,
         fontFace: SANS, fontSize: 16 });
}

// =============================================================================
// GIF D - before the honest slide
// =============================================================================
gifSlide({
    eyebrow: 'before you deploy this on monday',
    eyebrowColor: GRN,
    hint: 'Something rickety but working - a Rube Goldberg contraption, a wobbling ' +
          'table wedged with a matchbook, a shopping trolley with one bad wheel.',
    caption: 'This is about 900 lines of PowerShell.',
    sub: 'It is not a product, and the next slide is the part I would want to hear.',
    notes: 'Optional - this is the one to cut first if questions have run long. If you keep it, do not oversell the self-deprecation; one line, then straight into what it does not do. Admitting the limits here is what makes the takeaways land.'
});

// =============================================================================
// 17. Where this falls over
// =============================================================================
{
    const s = slide(
        'Do not skip this one. Saying where it breaks is what makes the rest credible, and this room can smell a sales pitch.'
    );
    head(s, 'the honest part', 'Where this falls over', { eyebrowColor: RED });

    card(s, M, 1.95, 5.75, 4.35, PANEL);
    s.addText('What it does not do', {
        x: M + 0.35, y: 2.2, w: 5.05, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 21, bold: true, color: RED });
    s.addText([
        { text: 'No ticketing, no paging, no auto-remediation', options: { bullet: true, breakLine: true } },
        { text: 'One window at a time - no history, no trends', options: { bullet: true, breakLine: true } },
        { text: 'A model can be confidently wrong, and will be', options: { bullet: true, breakLine: true } },
        { text: 'Same events, same answer only because temperature is zero', options: { bullet: true, breakLine: true } },
        { text: 'Nobody has run this on a real estate, including me', options: { bullet: true } },
    ], { x: M + 0.4, y: 2.62, w: 5.0, h: 3.3, isTextBox: true, margin: 0, valign: 'top',
         fontFace: SANS, fontSize: 15, color: MUT, paraSpaceAfter: 10,
         bullet: { indent: 14 } });

    card(s, 6.95, 1.95, 5.75, 4.35, PANEL);
    s.addText('What it costs', {
        x: 7.3, y: 2.2, w: 5.1, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 21, bold: true, color: GRN });

    const costs = [
        ['~3.5k', 'tokens per analysis pass, all thirteen incidents in one call'],
        ['1/min', 'and it skips the call entirely when nothing changed'],
        ['0', 'keys anywhere - managed identity end to end'],
    ];
    costs.forEach((c, i) => {
        const y = 2.8 + i * 1.15;
        s.addText(c[0], { x: 7.3, y: y, w: 1.55, h: 0.55, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 27, bold: true, color: TXT });
        s.addText(c[1], { x: 8.95, y: y + 0.04, w: 3.5, h: 0.8, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 14, color: MUT });
    });
}

// =============================================================================
// 17. Takeaways
// =============================================================================
{
    const s = slide('Three, not seven. If they remember one, make it the middle one.');
    head(s, 'if you remember three things', 'Takeaways');

    const t = [
        [BLU, 'Do the arithmetic first',
         'Fingerprinting and key matching removed 92% of the volume before anything read a word. Cheap, instant, and it never hallucinates.'],
        [GRN, 'Instrumentation earns the correlation',
         'One OpenTelemetry span attribute did work a model would otherwise have to do. Good telemetry is cheaper than inference.'],
        [RED, 'Use the model for the reading problem',
         'Ask it to connect what only prose connects, judge it on what it refuses to connect, and never let it own your data model.'],
    ];
    t.forEach((r, i) => {
        const y = 1.95 + i * 1.5;
        card(s, M, y, 12.05, 1.32, PANEL);
        badge(s, M + 0.32, y + 0.4, 0.55, r[0], String(i + 1));
        s.addText(r[1], { x: M + 1.1, y: y + 0.2, w: 10.5, h: 0.42, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 21, bold: true, color: TXT });
        s.addText(r[2], { x: M + 1.1, y: y + 0.66, w: 10.5, h: 0.55, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 14, color: MUT });
    });
}

// =============================================================================
// 18. Contact
// =============================================================================
{
    const s = slide('Leave this up during the last questions. Invite people up - CAS specifically asks speakers to be findable afterwards.');
    s.addText('Take it and break it', {
        x: M, y: 2.1, w: 11, h: 0.9, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 42, bold: true, color: WHT
    });
    s.addText('Everything in this session deploys into your own tenant with one script.', {
        x: M, y: 3.05, w: 11, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 17, color: MUT
    });

    const links = [
        [GRN, 'github.com/donnietaylor', 'Deploy-Azure.ps1, then Break-Everything.ps1'],
        [BLU, 'draith.com', 'Write-ups and the longer version of the argument'],
        [AMB, '@donnietaylor.bsky.social', 'Also on LinkedIn - come find me at the party'],
    ];
    links.forEach((l, i) => {
        const y = 3.85 + i * 0.92;
        s.addShape(pres.ShapeType.ellipse, { x: M, y: y + 0.14, w: 0.26, h: 0.26, fill: { color: l[0] } });
        s.addText(l[1], { x: M + 0.5, y: y, w: 5.2, h: 0.45, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 20, bold: true, color: TXT });
        s.addText(l[2], { x: M + 5.9, y: y + 0.05, w: 6.2, h: 0.4, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 14, color: MUT });
    });

    s.addText('Questions - now, or all week.', {
        x: M, y: 6.6, w: 11, h: 0.4, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, color: DIM, italic: true
    });
}

// =============================================================================
// 19. Appendix divider
// =============================================================================
{
    const s = slide('Hidden safety net. If the network dies, walk these screenshots instead of the live demo. Capture them at the end of a good rehearsal run and drop them in behind this slide.');
    s.addText('APPENDIX', {
        x: M, y: 2.9, w: 8, h: 0.5, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, bold: true, color: MUT, charSpacing: 5
    });
    s.addText('If the wifi dies', {
        x: M, y: 3.4, w: 11, h: 0.85, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 38, bold: true, color: TXT
    });
    s.addText('Screenshots of each demo stage go behind this slide: raw stream, the funnel, the tree with root cause, and the terminal output. Capture them at the end of a clean rehearsal.', {
        x: M, y: 4.4, w: 9.5, h: 0.9, isTextBox: true, margin: 0,
        fontFace: SANS, fontSize: 16, color: MUT
    });
}

// =============================================================================
// GIF E - hidden. Jump here when the demo breaks.
// =============================================================================
gifSlide({
    eyebrow: 'hidden slide - jump here if the demo dies',
    eyebrowColor: RED,
    hint: 'Whatever says "well, that happened" to you. A polite shrug, a small ' +
          'fire being calmly ignored, a dumpster on a river.',
    caption: 'The demo gods have opinions.',
    sub: 'Right-click this slide in PowerPoint and Hide Slide, so it never appears by accident.',
    notes: 'HIDE THIS SLIDE. Then learn where it is in the deck so you can jump to it by number. Having a prepared joke for a broken demo reads as confidence; scrambling reads as panic. After the laugh, go to the appendix screenshots and narrate what would have happened.'
});

pres.writeFile({ fileName: '/home/claude/deck/smarter-monitoring.pptx' })
    .then(f => console.log('wrote', f));
