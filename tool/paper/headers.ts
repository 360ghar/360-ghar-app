// App scenes (1 October 2026) for the scene headers of list screens.
/**
 * Wide, frameless paper scenes that sit behind a screen title on the sky
 * page. Same language as the onboarding diorama: one card stock per element,
 * hand-cut edges, one short shadow per layer from a top-left light.
 *
 * Box: 960 x 260, ground line y = 214. The header shows the full height and
 * crops the width, so the subject sits right of centre (x 480 to 760) and the
 * left half stays calm (sky, pale far towers, lawn): the title is set there.
 * The far skyline and the ground run past both edges (x -700 to 1660), so a
 * wide header shows more city instead of an empty edge.
 *
 * Depths for parallax: sun 0, clouds 0.05, far towers 0.2, blocks 0.5, the
 * subject 0.8, ground 1.
 */
import { rng } from './cut.ts';
import { gurugramLayers } from './gurugram.ts';
import { makeTools, type CloudProfile, type Layer, type Pt } from './shapes.ts';
import type { SceneLayer } from './scenes.ts';

export const HEADER_W = 960;
export const HEADER_H = 260;
const G = 214;
const LEFT = -700;
const RIGHT = 1660;

type Tools = ReturnType<typeof makeTools>;
type Tone = { fill: string; shadow: string };

const layer = (id: string, depth: number, tone: Tone, cut: string[], solid: string[] = [], lit: number[] = []): SceneLayer => ({
  id,
  depth,
  ...tone,
  cut,
  solid,
  lit,
});

const SUN: Tone = { fill: 'sun', shadow: '0.16' };
const CLOUD_T: Tone = { fill: 'cloud', shadow: '0.12' };
const FAR: Tone = { fill: 'far', shadow: '0.28' };
const MID: Tone = { fill: 'mid', shadow: '0.34' };
const MAIN: Tone = { fill: 'main', shadow: '0.4' };
const INK: Tone = { fill: 'deep', shadow: '0.35' };
const TREE: Tone = { fill: 'tree', shadow: '0.35' };
const TRUNK: Tone = { fill: 'trunk', shadow: '0.3' };
const LAWN: Tone = { fill: 'grass', shadow: '0.3' };
const SIGN: Tone = { fill: 'sign', shadow: '0.4' };
const WHITE: Tone = { fill: 'highlight', shadow: '0.35' };

const CLOUD: CloudProfile = [[0, 9], [0.18, 2], [0.36, 5], [0.54, -5], [0.76, 1], [1, 9]];

function sun(t: Tools, cx: number, cy: number, r: number): string {
  const pts: Pt[] = [];
  for (let i = 0; i < 24; i += 1) {
    const a = (i / 24) * Math.PI * 2;
    pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
  }
  return t.path(pts);
}

/** Far Cyber City towers across the whole run: flat, slanted, stepped, spired and notched crowns, with window strips. */
function farTowers(t: Tools, base: number, low: number, high: number): string {
  let x = LEFT;
  let d = '';
  const b = G + 6;
  while (x < RIGHT) {
    const w = 24 + t.rand() * 34;
    const h = low + t.rand() * (high - low);
    const top = base - h;
    const kind = t.rand();
    let outline: Pt[];
    let winTop = top + 10;
    if (kind < 0.16) {
      outline = [[x, top + 14], [x + w, top], [x + w, b], [x, b]];
      winTop = top + 22;
    } else if (kind < 0.32) {
      outline = [[x, top], [x + w, top + 12], [x + w, b], [x, b]];
      winTop = top + 20;
    } else if (kind < 0.46) {
      outline = [[x + w * 0.3, top - 12], [x + w * 0.7, top - 12], [x + w * 0.7, top], [x + w, top], [x + w, b], [x, b], [x, top], [x + w * 0.3, top]];
    } else if (kind < 0.56) {
      outline = [[x + w / 2 - 1, top - 26], [x + w / 2 + 1, top - 26], [x + w / 2 + 1.6, top - 7], [x + w, top], [x + w, b], [x, b], [x, top], [x + w / 2 - 1.6, top - 7]];
    } else if (kind < 0.66) {
      outline = [[x, top], [x + w * 0.38, top], [x + w * 0.5, top + 8], [x + w * 0.62, top], [x + w, top], [x + w, b], [x, b]];
    } else if (kind < 0.8) {
      outline = [[x + w * 0.62, top - 15], [x + w * 0.67, top - 15], [x + w * 0.67, top], [x + w, top], [x + w, b], [x, b], [x, top], [x + w * 0.62, top]];
    } else {
      outline = [[x, top], [x + w, top], [x + w, b], [x, b]];
    }
    const cols = Math.max(1, Math.floor((w - 10) / 8));
    d += t.path(outline) + t.grid(x + 6, winTop, cols, Math.max(1, Math.floor((base - winTop - 8) / 13)), 3, 7, 5, 6, 0.38);
    x += w + 3 + t.rand() * 9;
  }
  return d;
}

/** Ground from LEFT to RIGHT with a slightly rough top edge. */
function ground(t: Tools, y: number, bump = 2.4): string {
  const pts: Pt[] = [[LEFT, y]];
  for (let x = LEFT + 40; x < RIGHT; x += 40) pts.push([x, y - bump / 2 + t.rand() * bump]);
  pts.push([RIGHT, y], [RIGHT, HEADER_H + 6], [LEFT, HEADER_H + 6]);
  return t.path(pts);
}

/** A neem: a forked trunk and a rough canopy with leaf gaps. */
function neem(t: Tools, cx: number, h: number, rx: number) {
  return t.tree(cx, G, h, rx, {
    trunk: [-3, -2.4, -12, -10, -0.6, 1.6, 4, 2.6, 3],
    foot: 1,
    canopy: [12, rx * 0.62, 18, 0.34],
    gaps: [
      [-0.4, 10, 4, 3, 6, 0.3],
      [0.34, 16, 5, 3, 6, 0.3],
    ],
  });
}

/** A low hedge: a rough clump on the ground line. */
const hedge = (t: Tools, cx: number, rx: number, ry = 6) => t.blob(cx, G - 2, rx, ry, 18, 0.36);

/** Grass tuft: three quick cuts. */
const tuft = (t: Tools, x: number, y: number) =>
  t.path([
    [x, y],
    [x + 2.4, y - 8],
    [x + 4.6, y - 1.6],
    [x + 7, y - 10],
    [x + 8.6, y - 1.6],
    [x + 11.4, y - 7],
    [x + 12.6, y],
  ]);

/** A black water tank on a short stand. */
const tank = (t: Tools, x: number, y: number, w = 20, h = 13) =>
  t.path([
    [x, y - 3],
    [x, y - h + 2],
    [x + 2, y - h],
    [x + w - 2, y - h],
    [x + w, y - h + 2],
    [x + w, y - 3],
    [x + w - 3, y - 3],
    [x + w - 3, y + 1],
    [x + 3, y + 1],
    [x + 3, y - 3],
  ]);

/** A sector block: balcony slits with windows between, a tank on the roof. */
function block(t: Tools, x: number, w: number, top: number): { body: string; tank: string } {
  let d = t.rect(x, top, w, G + 2 - top);
  for (let y = top + 9; y < G - 12; y += 16) {
    d += t.rect(x + 6, y, w - 12, 3);
    d += t.grid(x + 10, y + 6, Math.floor((w - 16) / 12), 1, 6, 5, 6, 0, 0.3);
  }
  return { body: d, tank: tank(t, x + w - 30, top, 18, 11) };
}

/* ------------------------------------------------------------------ */
/* Saved: a society facade. Each saved home lights one window.         */
/* ------------------------------------------------------------------ */

const FX = 520;
const FW = 196;
const FTOP = 92;

function saved(): SceneLayer[] {
  const t = makeTools('header-saved', 0.6);
  const cols = 5;
  const rows = 4;
  const ww = 21;
  const wh = 13;
  const gap = (FW - 28 - cols * ww) / (cols - 1);
  const floor = 23;
  // Windows in a scattered order, so the first lit windows read as a lived-in building.
  const order: [number, number][] = [];
  for (let r = 0; r < rows; r += 1) for (let c = 0; c < cols; c += 1) order.push([c, r]);
  const shuffle = rng('header-saved-windows');
  for (let i = order.length - 1; i > 0; i -= 1) {
    const k = Math.floor(shuffle() * (i + 1));
    [order[i], order[k]] = [order[k]!, order[i]!];
  }
  const winX = (c: number) => FX + 14 + c * (ww + gap);
  const winY = (r: number) => FTOP + 8 + r * floor;
  const stilt = FTOP + 8 + rows * floor;
  // The floors with their windows; the lit path, so its holes are the windows.
  let facade = t.rect(FX, FTOP, FW, stilt + 3 - FTOP);
  for (const [c, r] of order) facade += t.rect(winX(c), winY(r), ww, wh);
  // Stilt floor: the entrance in the middle and two parking bays.
  const ground_ =
    t.rect(FX, stilt, FW, G + 2 - stilt) +
    t.rect(FX + 82, stilt + 10, 32, G - stilt - 10) +
    t.rect(FX + 16, stilt + 12, 54, G - stilt - 12) +
    t.rect(FX + 126, stilt + 12, 54, G - stilt - 12);
  // Balcony slabs under each row of windows, the parapet, the entrance canopy.
  const slabs = [t.rect(FX - 8, FTOP - 7, FW + 16, 8)];
  for (let r = 0; r < rows; r += 1) slabs.push(t.rect(FX - 5, winY(r) + wh + 2, FW + 10, 4));
  // A stair room on the roof, with its door cut out.
  const stair = t.rect(FX + 132, FTOP - 31, 40, 25) + t.rect(FX + 140, FTOP - 23, 10, 17);
  const stairSlab = t.rect(FX + 128, FTOP - 35, 48, 5);
  // Potted plants on some balconies, in the gaps between windows.
  const pots: string[] = [];
  const leaves: string[] = [];
  for (const [c, r] of [
    [0, 0],
    [2, 1],
    [3, 0],
    [1, 2],
    [3, 3],
    [0, 3],
  ] as const) {
    const px = winX(c) + ww + gap / 2;
    const py = winY(r) + wh + 2;
    pots.push(t.rect(px - 3.6, py - 5, 7.2, 5));
    leaves.push(t.blob(px, py - 8, 6, 4.6, 10, 0.4));
  }
  const left = neem(t, 470, 62, 28);
  const right = neem(t, 752, 84, 36);
  const sideL = neem(t, 140, 70, 30);
  const sideR = neem(t, 1060, 66, 30);
  // Two more towers of the society behind the facade, and blocks along the sides.
  const back = [block(t, 424, 84, 54), block(t, 730, 76, 104), block(t, -120, 120, 120), block(t, 1120, 130, 112)];
  return [
    layer('sun', 0, SUN, [], [sun(t, 612, 34, 21)]),
    layer('clouds', 0.05, CLOUD_T, [], [t.cloud(690, 84, 74, CLOUD), t.cloud(60, 66, 64, CLOUD), t.cloud(1180, 58, 70, CLOUD)]),
    layer('far', 0.2, FAR, [farTowers(t, 196, 50, 132)], [], [0]),
    layer('society', 0.5, { fill: 'home', shadow: '0.32' }, back.map((k) => k.body), [], [0, 1, 2, 3]),
    layer('societytanks', 0.5, INK, [], back.map((k) => k.tank)),
    layer('rooms', 0.8, { fill: 'deep', shadow: '0' }, [], [t.rect(FX + 6, FTOP + 4, FW - 12, G - FTOP - 4)]),
    { ...layer('facade', 0.8, MID, [facade, stair, ground_], [], [0]), counted: true },
    layer('roof', 0.8, INK, [], [tank(t, FX + 18, FTOP - 7), tank(t, FX + 46, FTOP - 7), tank(t, FX + 76, FTOP - 7, 16, 11)]),
    layer('slabs', 0.8, MAIN, [], [...slabs, stairSlab]),
    layer('canopy', 0.8, SIGN, [], [t.rect(FX + 76, stilt + 5, 44, 5)]),
    layer('pots', 0.8, MAIN, [], pots),
    layer('leaves', 0.8, TREE, [], leaves),
    layer('trunks', 0.8, TRUNK, [], [left.trunk, right.trunk, sideL.trunk, sideR.trunk]),
    layer('trees', 0.8, TREE, [], [left.canopy, right.canopy, sideL.canopy, sideR.canopy]),
    layer('lawn', 1, LAWN, [ground(t, G)]),
    layer('path', 1, { fill: 'pavement', shadow: '0.2' }, [
      t.path([
        [FX + 84, G],
        [FX + 112, G],
        [FX + 150, HEADER_H + 6],
        [FX + 46, HEADER_H + 6],
      ]),
    ]),
    layer('hedges', 1, TREE, [], [hedge(t, FX + 36, 34), hedge(t, FX + 160, 34), hedge(t, 840, 40, 8)]),
    layer('tufts', 1, { fill: 'tree', shadow: '0.25' }, [], [tuft(t, 380, G + 14), tuft(t, 880, G + 18), tuft(t, 300, G + 24)]),
  ];
}

/* ------------------------------------------------------------------ */
/* Visits: the society gate, with a guard booth and a boom barrier.     */
/* ------------------------------------------------------------------ */

function visits(): SceneLayer[] {
  const t = makeTools('header-visits', 0.6);
  const lx = 540;
  const rx = 692;
  const pw = 22;
  const ptop = 112;
  // Pillars with caps; the beam over them; a lamp on each cap.
  const pillars = [t.rect(lx, ptop, pw, G + 2 - ptop), t.rect(rx, ptop, pw, G + 2 - ptop)];
  const caps = [t.rect(lx - 4, ptop - 6, pw + 8, 7), t.rect(rx - 4, ptop - 6, pw + 8, 7), t.rect(lx - 2, ptop - 20, rx + pw - lx + 4, 13)];
  const lamp = (x: number) =>
    t.path([
      [x - 1.6, ptop - 20],
      [x - 1.6, ptop - 26],
      [x - 5, ptop - 28],
      [x - 4, ptop - 38],
      [x + 4, ptop - 38],
      [x + 5, ptop - 28],
      [x + 1.6, ptop - 26],
      [x + 1.6, ptop - 20],
    ]);
  // The blank sign board stands on the beam on two short legs.
  const board = t.rect(lx + 16, ptop - 52, rx + pw - lx - 32, 26);
  const legs = [t.rect(lx + 34, ptop - 27, 4, 8), t.rect(rx + pw - 38, ptop - 27, 4, 8)];
  // The boundary wall runs off both ways, with a coping and piers.
  const wall = t.rect(LEFT, 178, lx - LEFT, G + 2 - 178) + t.rect(rx + pw, 178, RIGHT - rx - pw, G + 2 - 178);
  const coping = [t.rect(LEFT, 173, lx - LEFT + 2, 6), t.rect(rx + pw - 2, 173, RIGHT - rx - pw, 6)];
  for (let x = lx - 70; x > LEFT; x -= 72) coping.push(t.rect(x, 168, 10, 11));
  for (let x = rx + pw + 120; x < RIGHT; x += 72) coping.push(t.rect(x, 168, 10, 11));
  // The guard booth beside the right pillar: a window, a door, a flat roof.
  const bx = rx + pw + 8;
  const booth = t.rect(bx, 146, 46, G + 2 - 146) + t.rect(bx + 7, 156, 20, 15) + t.rect(bx + 31, 168, 10, G - 168);
  const boothRoof = t.rect(bx - 5, 139, 56, 8);
  // The boom barrier: a post at the right pillar, a striped arm across the gate.
  const post = t.rect(rx - 12, 166, 10, G + 2 - 166);
  let arm = t.rect(lx + pw + 2, 168, rx - 12 - lx - pw, 8);
  for (let x = lx + pw + 12; x < rx - 24; x += 22) arm += t.rect(x, 169.6, 10, 4.8);
  // Society blocks beyond the gate, and trees over the wall.
  const towers = [block(t, 470, 118, 70), block(t, 616, 136, 52), block(t, 776, 104, 96), block(t, 60, 110, 108), block(t, 1080, 120, 98)];
  const left = neem(t, 420, 66, 30);
  const right = neem(t, 900, 72, 32);
  return [
    layer('sun', 0, SUN, [], [sun(t, 470, 42, 21)]),
    layer('clouds', 0.05, CLOUD_T, [], [t.cloud(760, 80, 70, CLOUD), t.cloud(150, 56, 60, CLOUD), t.cloud(1200, 70, 66, CLOUD)]),
    layer('far', 0.2, FAR, [farTowers(t, 188, 40, 112)], [], [0]),
    layer('blocks', 0.5, { fill: 'home', shadow: '0.32' }, towers.map((k) => k.body), [], [0, 1, 2, 3, 4]),
    layer('tanks', 0.5, INK, [], towers.map((k) => k.tank)),
    layer('trunks', 0.8, TRUNK, [], [left.trunk, right.trunk]),
    layer('trees', 0.8, TREE, [], [left.canopy, right.canopy]),
    layer('lane', 0.8, { fill: 'pavement', shadow: '0.2' }, [
      t.path([
        [lx + pw, G - 30],
        [rx, G - 30],
        [rx, G + 2],
        [lx + pw, G + 2],
      ]),
    ]),
    layer('wall', 0.8, MID, [wall]),
    layer('coping', 0.8, MAIN, [], coping),
    layer('lit', 0.8, { fill: 'lit', shadow: '0' }, [], [t.rect(bx + 5, 154, 24, 19)]),
    layer('booth', 0.8, SIGN, [booth]),
    layer('boothroof', 0.8, MAIN, [], [boothRoof]),
    layer('pillars', 0.8, MAIN, [], [...pillars, ...caps]),
    layer('board', 0.8, SIGN, [], [board]),
    layer('lamps', 0.8, INK, [], [lamp(lx + pw / 2), lamp(rx + pw / 2), ...legs, post]),
    layer('stripes', 0.8, { fill: 'bloom', shadow: '0' }, [], [t.rect(lx + pw + 8, 170.4, rx - 26 - lx - pw, 3.2)]),
    layer('arm', 0.8, WHITE, [arm]),
    layer('lawn', 1, LAWN, [ground(t, G)]),
    layer('path', 1, { fill: 'pavement', shadow: '0.2' }, [
      t.path([
        [lx + pw, G],
        [rx, G],
        [rx + 46, HEADER_H + 6],
        [lx - 24, HEADER_H + 6],
      ]),
    ]),
    layer('hedges', 1, TREE, [], [hedge(t, 470, 40), hedge(t, 812, 46, 7)]),
    layer('tufts', 1, { fill: 'tree', shadow: '0.25' }, [], [tuft(t, 330, G + 16), tuft(t, 880, G + 20), tuft(t, 250, G + 26)]),
  ];
}

/* ------------------------------------------------------------------ */
/* Diorama pieces reused in headers: the page-2 home and the kite.     */
/* ------------------------------------------------------------------ */

/** Scales an absolute M/L/Z path by `k` and moves it by (dx, dy). */
function moved(d: string, k: number, dx: number, dy: number): string {
  let i = 0;
  return d.replace(/-?\d+(?:\.\d+)?/g, (n) => {
    const v = Number(n) * k + (i % 2 === 0 ? dx : dy);
    i += 1;
    return String(Math.round(v * 100) / 100);
  });
}

/** Diorama layers by id, scaled into the header box, with a header depth. */
function diorama(ids: string[], k: number, dx: number, dy: number, depth: number): SceneLayer[] {
  return gurugramLayers()
    .filter((l) => ids.includes(l.id))
    .map((l: Layer & { lit?: number[] }) => ({
      ...l,
      depth,
      cut: l.cut.map((d) => moved(d, k, dx, dy)),
      solid: l.solid.map((d) => moved(d, k, dx, dy)),
      ...(l.lit ? { lit: l.lit } : {}),
    }));
}

/** A row of sector blocks with tanks, from LEFT to RIGHT, tops between `low` and `high`. */
function blockRow(t: Tools, low: number, high: number) {
  const bodies: string[] = [];
  const tanks: string[] = [];
  for (let x = LEFT; x < RIGHT; ) {
    const w = 70 + t.rand() * 60;
    const b = block(t, x, w, low + t.rand() * (high - low));
    bodies.push(b.body);
    tanks.push(b.tank);
    x += w + 8 + t.rand() * 20;
  }
  return { bodies, tanks };
}

/* ------------------------------------------------------------------ */
/* Profile: the onboarding home, its window lit, with the city behind.  */
/* ------------------------------------------------------------------ */

function profile(): SceneLayer[] {
  const t = makeTools('header-profile', 0.6);
  // The diorama home stands on the street at y = 800 and spans x 640 to 960.
  const k = 0.42;
  const home = diorama(['rooms', 'lit', 'home', 'hometank', 'parapet'], k, 640 - 800 * k, G - 800 * k, 0.8);
  const row = blockRow(t, 128, 160);
  const left = neem(t, 520, 70, 30);
  const right = neem(t, 760, 60, 26);
  return [
    layer('sun', 0, SUN, [], [sun(t, 740, 52, 22)]),
    layer('clouds', 0.05, CLOUD_T, [], [t.cloud(560, 70, 70, CLOUD), t.cloud(140, 60, 60, CLOUD), t.cloud(1160, 64, 66, CLOUD)]),
    layer('far', 0.2, FAR, [farTowers(t, 180, 44, 118)], [], [0]),
    layer('blocks', 0.5, MID, row.bodies, [], row.bodies.map((_, i) => i)),
    layer('tanks', 0.5, INK, [], row.tanks),
    layer('trunks', 0.8, TRUNK, [], [left.trunk, right.trunk]),
    layer('trees', 0.8, TREE, [], [left.canopy, right.canopy]),
    ...home,
    layer('lawn', 1, LAWN, [ground(t, G)]),
    layer('path', 1, { fill: 'pavement', shadow: '0.2' }, [
      t.path([
        [628, G],
        [652, G],
        [690, HEADER_H + 6],
        [596, HEADER_H + 6],
      ]),
    ]),
    layer('hedges', 1, TREE, [], [hedge(t, 560, 30), hedge(t, 730, 34), hedge(t, 900, 40, 7)]),
    layer('tufts', 1, { fill: 'tree', shadow: '0.25' }, [], [tuft(t, 330, G + 16), tuft(t, 860, G + 20)]),
  ];
}

/* ------------------------------------------------------------------ */
/* Assistant: the onboarding kite over the towers and the blocks.       */
/* ------------------------------------------------------------------ */

function assistant(): SceneLayer[] {
  const t = makeTools('header-assistant', 0.6);
  // The diorama kite flies at (640, 300); its string runs down behind the blocks.
  const k = 0.8;
  const kite = diorama(['kite'], k, 600 - 640 * k, 78 - 300 * k, 0.2);
  const row = blockRow(t, 150, 178);
  return [
    layer('sun', 0, SUN, [], [sun(t, 760, 62, 30)]),
    layer('clouds', 0.05, CLOUD_T, [], [t.cloud(420, 76, 72, CLOUD), t.cloud(840, 104, 60, CLOUD), t.cloud(1180, 60, 66, CLOUD)]),
    layer('far', 0.2, FAR, [farTowers(t, 190, 56, 136)], [], [0]),
    ...kite,
    layer('blocks', 0.5, MID, row.bodies, [], row.bodies.map((_, i) => i)),
    layer('tanks', 0.5, INK, [], row.tanks),
    layer('lawn', 1, LAWN, [ground(t, G)]),
  ];
}

/* ------------------------------------------------------------------ */
/* Skyline: a slim strip of far towers and sector blocks.               */
/* ------------------------------------------------------------------ */

function skyline(): SceneLayer[] {
  const t = makeTools('header-skyline', 0.6);
  const row = blockRow(t, 132, 170);
  return [
    layer('clouds', 0.05, CLOUD_T, [], [t.cloud(300, 70, 70, CLOUD), t.cloud(980, 60, 64, CLOUD)]),
    layer('far', 0.2, FAR, [farTowers(t, 186, 60, 140)], [], [0]),
    layer('blocks', 0.5, MID, row.bodies, [], row.bodies.map((_, i) => i)),
    layer('tanks', 0.5, INK, [], row.tanks),
    layer('lawn', 1, LAWN, [ground(t, G)]),
  ];
}

export const headerLayers = { saved, visits, profile, assistant, skyline };
export type HeaderName = keyof typeof headerLayers;
