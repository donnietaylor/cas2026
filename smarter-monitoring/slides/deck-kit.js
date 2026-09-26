// =============================================================================
//  deck-kit.js - the deck's visual language, as code
// =============================================================================
//
//  Palette, grid and layout helpers shared by anything that generates slides
//  for this session. Nothing in here writes a file; it only builds decks in
//  memory. That is deliberate - the main deck is hand-edited in PowerPoint and
//  nothing generated should ever be able to overwrite it.
//
//  Usage:
//      const kit = require('./deck-kit');
//      const d = kit.createDeck({ title: 'Staging' });
//      const s = d.slide('speaker notes here');
//      d.head(s, 'eyebrow', 'Title');
//      d.card(s, kit.M, 2.0, 12.05, 1.2);
//      await d.save('staging.pptx');
//
// =============================================================================

const pptxgen = require('pptxgenjs');

// --- palette -----------------------------------------------------------------
// A dark console ground, with severity as the only saturated colour on the
// slide. The punchline of the talk is that the cause was amber, not red, so
// amber has to mean the same thing everywhere it appears.
const C = {
    BG:     '0E1621',   // slide ground
    PANEL:  '19242F',   // card
    PANEL2: '223140',   // card, one step up - for the callout in a stack of cards
    TXT:    'E9EFF6',   // primary text
    MUT:    '8FA3B8',   // secondary text
    DIM:    '7C90A6',   // captions, timestamps - the floor for projected contrast
    RED:    'E0443E',   // critical
    AMB:    'E8A33D',   // warning, and the accent colour of the deck
    GRN:    '46B98A',   // healthy, resolved, "no model needed"
    BLU:    '5B9BD5',   // informational
    WHT:    'FFFFFF',
    DEMO:   '15100C',   // the warmer ground used only on demo marker slides
};

const SANS = 'Calibri';       // body and titles
const MONO = 'Courier New';   // anything a machine emitted: logs, hosts, code

// Slide geometry. LAYOUT_WIDE is 13.333 x 7.5in; M is the side margin every
// content slide aligns to, so content width is always 12.05.
const W = 13.333, H = 7.5, M = 0.65, CONTENT_W = W - M * 2;

function createDeck(opts = {}) {
    const pres = new pptxgen();
    pres.layout = 'LAYOUT_WIDE';
    pres.author = opts.author || 'Donnie Taylor';
    pres.title = opts.title || 'Smarter Monitoring';

    const d = {};
    d.pres = pres;

    d.slide = function (notes) {
        const s = pres.addSlide();
        s.background = { color: C.BG };
        if (notes) s.addNotes(notes);
        return s;
    };

    // Eyebrow + title: the standard head on every content slide.
    d.head = function (s, eyebrow, title, o = {}) {
        const y = o.y ?? 0.5;
        if (eyebrow) {
            s.addText(eyebrow.toUpperCase(), {
                x: M, y, w: 11, h: 0.3, isTextBox: true, margin: 0,
                fontFace: SANS, fontSize: 12, bold: true,
                color: o.eyebrowColor || C.AMB, charSpacing: 2
            });
        }
        s.addText(title, {
            x: M, y: y + 0.32, w: o.tw ?? 11.8, h: 0.75, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: o.size ?? 36, bold: true, color: C.TXT
        });
    };

    // The repeated motif: a filled circle carrying a number or glyph.
    d.badge = function (s, x, y, dia, fill, label, labelColor) {
        s.addShape(pres.ShapeType.ellipse, { x, y, w: dia, h: dia, fill: { color: fill } });
        s.addText(label, {
            x, y, w: dia, h: dia, isTextBox: true, margin: 0, align: 'center', valign: 'middle',
            fontFace: SANS, fontSize: dia > 0.55 ? 17 : 13, bold: true, color: labelColor || C.BG
        });
    };

    d.card = function (s, x, y, w, h, fill) {
        s.addShape(pres.ShapeType.roundRect, {
            x, y, w, h, rectRadius: 0.06, fill: { color: fill || C.PANEL }
        });
    };

    d.dot = function (s, x, y, color, dia) {
        s.addShape(pres.ShapeType.ellipse, {
            x, y, w: dia || 0.22, h: dia || 0.22, fill: { color }
        });
    };

    // --- composite layouts ---------------------------------------------------

    // A row of equal cards across the full content width.
    // items: [{ color, title, sub, body, foot }]
    d.cardRow = function (s, items, o = {}) {
        const y = o.y ?? 1.95, h = o.h ?? 4.05, gap = o.gap ?? 0.4;
        const w = (CONTENT_W - gap * (items.length - 1)) / items.length;
        items.forEach((it, i) => {
            const x = M + i * (w + gap);
            d.card(s, x, y, w, h);
            if (it.color) d.badge(s, x + 0.35, y + 0.35, 0.5, it.color, String(i + 1));
            s.addText(it.title, {
                x: x + 0.35, y: y + 1.05, w: w - 0.7, h: 0.4, isTextBox: true, margin: 0,
                fontFace: SANS, fontSize: 21, bold: true, color: C.TXT });
            if (it.sub) s.addText(it.sub, {
                x: x + 0.35, y: y + 1.55, w: w - 0.7, h: 0.6, isTextBox: true, margin: 0,
                valign: 'top', fontFace: SANS, fontSize: 15, color: it.color || C.MUT, italic: true });
            if (it.body) s.addText(it.body, {
                x: x + 0.35, y: y + 2.25, w: w - 0.7, h: 0.9, isTextBox: true, margin: 0,
                valign: 'top', fontFace: SANS, fontSize: 14, color: C.MUT });
            if (it.foot) s.addText(it.foot, {
                x: x + 0.35, y: y + h - 0.65, w: w - 0.7, h: 0.35, isTextBox: true, margin: 0,
                fontFace: SANS, fontSize: 13, bold: true, color: C.DIM });
        });
    };

    // Stacked full-width rows: badge, bold label, description.
    // items: [{ color, title, body, sub }]
    d.rows = function (s, items, o = {}) {
        const y0 = o.y ?? 1.95, h = o.h ?? 1.32, pitch = o.pitch ?? (h + 0.18);
        items.forEach((it, i) => {
            const y = y0 + i * pitch;
            d.card(s, M, y, CONTENT_W, h);
            d.badge(s, M + 0.32, y + (h - 0.52) / 2, 0.52, it.color || C.AMB, String(i + 1));
            s.addText(it.title, {
                x: M + 1.05, y: y + 0.2, w: o.titleW ?? 10.4, h: 0.42, isTextBox: true, margin: 0,
                fontFace: SANS, fontSize: 20, bold: true, color: C.TXT });
            if (it.body) s.addText(it.body, {
                x: M + 1.05, y: y + 0.66, w: o.titleW ?? 10.4, h: 0.5, isTextBox: true, margin: 0,
                fontFace: SANS, fontSize: 14, color: C.MUT });
        });
    };

    // A full-width callout band - use it for the one sentence that matters.
    d.callout = function (s, y, runs, o = {}) {
        const h = o.h ?? 1.0;
        d.card(s, M, y, CONTENT_W, h, C.PANEL2);
        s.addText(runs, {
            x: M + 0.3, y: y + 0.22, w: CONTENT_W - 0.6, h: h - 0.4, isTextBox: true, margin: 0,
            valign: 'top', fontFace: SANS, fontSize: o.size ?? 16 });
    };

    // Monospace machine output inside a panel. lines: [[time, sev, text]]
    d.logWall = function (s, lines, o = {}) {
        const y0 = o.y ?? 1.75, pitch = 0.325;
        const sev = { critical: C.RED, error: C.AMB, warning: C.DIM, info: C.BLU };
        d.card(s, M, y0, CONTENT_W, lines.length * pitch + 0.3);
        lines.forEach((ln, i) => {
            const y = y0 + 0.15 + i * pitch;
            s.addText(ln[0], { x: M + 0.25, y, w: 1.0, h: 0.3, isTextBox: true, margin: 0,
                fontFace: MONO, fontSize: 11, color: C.DIM });
            s.addText(ln[1], { x: M + 1.3, y, w: 0.85, h: 0.3, isTextBox: true, margin: 0,
                fontFace: MONO, fontSize: 11, bold: true, color: sev[ln[1]] || C.MUT });
            s.addText(ln[2], { x: M + 2.25, y, w: 9.5, h: 0.3, isTextBox: true, margin: 0,
                fontFace: MONO, fontSize: 11, color: C.MUT });
        });
    };

    // A code panel. lines: [[text, color?]]
    // o.size bumps the type: 12 is fine beside other content, 15-16 is what a
    // code-only slide needs to be readable from the back of a conference room.
    // Pass h = null to size the panel to its contents. Returns the height it
    // used, so the caller can place whatever comes next at panelY + height.
    // Guessing this by hand is how code slides end up clipped.
    d.codePanel = function (s, x, y, w, h, filename, lines, o = {}) {
        const size = o.size ?? 12;
        const pitch = o.pitch ?? size * 0.0242;   // ~0.29 at 12pt, ~0.36 at 15pt
        const top = filename ? 0.62 : 0.25;
        h = h || (top + lines.length * pitch + 0.2);
        d.card(s, x, y, w, h);
        if (filename) s.addText(filename, {
            x: x + 0.35, y: y + 0.18, w: w - 0.7, h: 0.3, isTextBox: true, margin: 0,
            fontFace: MONO, fontSize: Math.max(11, size - 2), color: C.MUT });
        lines.forEach((ln, i) => s.addText(Array.isArray(ln) ? ln[0] : ln, {
            x: x + 0.35, y: y + top + i * pitch, w: w - 0.7, h: pitch,
            isTextBox: true, margin: 0, fontFace: MONO, fontSize: size,
            color: (Array.isArray(ln) && ln[1]) || C.MUT }));
        return h;
    };

    // A demo marker: warm ground, big label, what is about to happen.
    d.demo = function (n, title, bullets, notes) {
        const s = d.slide(notes);
        s.addShape(pres.ShapeType.rect, { x: 0, y: 0, w: W, h: H, fill: { color: C.DEMO } });
        s.addText(`DEMO ${n}`, {
            x: M, y: 2.25, w: 6, h: 0.45, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 16, bold: true, color: C.AMB, charSpacing: 5 });
        s.addText(title, {
            x: M, y: 2.75, w: 11.5, h: 1.0, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 42, bold: true, color: C.WHT });
        s.addText(bullets.map((b, i) => ({
            text: b, options: { bullet: true, breakLine: i < bullets.length - 1 } })), {
            x: M + 0.05, y: 4.05, w: 10.5, h: 1.6, isTextBox: true, margin: 0, valign: 'top',
            fontFace: SANS, fontSize: 16, color: C.MUT, paraSpaceAfter: 8, bullet: { indent: 14 } });
        return s;
    };

    // An image slide with a placeholder well. Drop the image over the well,
    // then delete the well. The caption is the point and survives either way.
    d.imageSlide = function (o) {
        const s = d.slide(o.notes);
        if (o.eyebrow) s.addText(o.eyebrow.toUpperCase(), {
            x: M, y: 0.5, w: 11, h: 0.3, isTextBox: true, margin: 0,
            fontFace: SANS, fontSize: 12, bold: true, color: o.eyebrowColor || C.AMB, charSpacing: 2 });

        const ww = o.wellW ?? 7.0, wh = o.wellH ?? 3.94, wx = (W - ww) / 2, wy = 1.15;
        d.card(s, wx, wy, ww, wh);
        s.addText(o.wellLabel || 'DROP IMAGE HERE', {
            x: wx, y: wy + 1.35, w: ww, h: 0.45, isTextBox: true, margin: 0, align: 'center',
            fontFace: SANS, fontSize: 20, bold: true, color: C.AMB, charSpacing: 3 });
        if (o.hint) s.addText(o.hint, {
            x: wx + 0.6, y: wy + 1.9, w: ww - 1.2, h: 0.6, isTextBox: true, margin: 0,
            align: 'center', valign: 'top', fontFace: SANS, fontSize: 15, color: C.MUT });
        s.addText('about 1000 px wide  ·  under 3 MB  ·  cover this box, then delete it', {
            x: wx, y: wy + 2.75, w: ww, h: 0.35, isTextBox: true, margin: 0, align: 'center',
            fontFace: SANS, fontSize: 12, color: C.DIM, italic: true });

        if (o.caption) s.addText(o.caption, {
            x: M, y: 5.42, w: CONTENT_W, h: 0.95, isTextBox: true, margin: 0, align: 'center',
            valign: 'top', fontFace: SANS, fontSize: o.captionSize ?? 27, bold: true, color: C.WHT });
        if (o.sub) s.addText(o.sub, {
            x: M, y: 6.35, w: CONTENT_W, h: 0.4, isTextBox: true, margin: 0, align: 'center',
            fontFace: SANS, fontSize: 15, color: C.MUT, italic: true });
        return s;
    };

    // Arrows, built from a bar and a triangle. pptxgenjs line arrowheads are
    // inconsistent across renderers; two shapes always draw.
    // dir: 'right' | 'down' | 'up'
    d.arrow = function (s, x, y, len, dir, o = {}) {
        const col = o.color || C.DIM, t = o.thickness || 0.035, hw = o.headW || 0.15;
        const hl = o.headL || 0.13;
        if (dir === 'right') {
            s.addShape(pres.ShapeType.rect, {
                x, y: y - t / 2, w: Math.max(0.01, len - hl), h: t, fill: { color: col } });
            s.addShape(pres.ShapeType.triangle, {
                x: x + len - hl, y: y - hw / 2, w: hl, h: hw, rotate: 90, fill: { color: col } });
        } else {
            const down = dir === 'down';
            s.addShape(pres.ShapeType.rect, {
                x: x - t / 2, y: down ? y : y + hl, w: t, h: Math.max(0.01, len - hl),
                fill: { color: col } });
            s.addShape(pres.ShapeType.triangle, {
                x: x - hw / 2, y: down ? y + len - hl : y, w: hw, h: hl,
                rotate: down ? 180 : 0, fill: { color: col } });
        }
    };

    // A small uppercase chip - for LAYER 1 / LAYER 2 style tags on a diagram.
    d.chip = function (s, x, y, w, label, color) {
        s.addShape(pres.ShapeType.roundRect, {
            x, y, w, h: 0.22, rectRadius: 0.05, fill: { color: C.BG },
            line: { color, width: 1 } });
        s.addText(label.toUpperCase(), {
            x, y, w, h: 0.22, isTextBox: true, margin: 0, align: 'center', valign: 'middle',
            fontFace: SANS, fontSize: 9, bold: true, color, charSpacing: 1 });
    };

    d.save = function (fileName) {
        return pres.writeFile({ fileName });
    };

    return d;
}

module.exports = { createDeck, C, SANS, MONO, W, H, M, CONTENT_W };
