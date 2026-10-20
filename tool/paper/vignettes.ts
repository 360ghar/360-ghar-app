// Adapted from 360ghar-web-ui-2/src/lib/paper/vignettes.ts on 2026-10-01.
// Changes: only the themes the app uses (calculator, key, document, tower, home,
// plot, pg); fills are app tone names (see PaperTone in lib/core/design/paper/paper_art.dart)
// instead of the website's kesar ramp, so each element is its own card stock;
// shadows are alpha values; window holes are listed in `lit` for the night theme.
/**
 * Small paper-cut vignettes by theme, for tool cards and choices. Same
 * language as the diorama: flat layers, hand-cut edges, one short shadow per
 * layer from a top-left light.
 *
 * Every vignette is 160 x 100. The seed changes the hand-cut jitter (and the
 * far skyline), so two vignettes of one theme need not be twins.
 */
import { makeTools, type Pt } from './shapes.ts';
import type { SceneLayer } from './scenes.ts';

export const VIGNETTE_W = 160;
export const VIGNETTE_H = 100;

const W = VIGNETTE_W;
const H = VIGNETTE_H;
/** Street level. */
const G = 82;

type Tools = ReturnType<typeof makeTools>;
type Tone = { fill: string; shadow: string };

const FAR: Tone = { fill: 'far', shadow: '0.28' };
const MID: Tone = { fill: 'mid', shadow: '0.34' };
const MAIN: Tone = { fill: 'main', shadow: '0.4' };
const NEAR: Tone = { fill: 'near', shadow: '0.45' };
const SHEET: Tone = { fill: 'highlight', shadow: '0.3' };
const LEAF: Tone = { fill: 'tree', shadow: '0.35' };
const LAWN: Tone = { fill: 'grass', shadow: '0.3' };
const INK: Tone = { fill: 'deep', shadow: '0.4' };
const SIGN: Tone = { fill: 'sign', shadow: '0.4' };
const WOOD: Tone = { fill: 'trunk', shadow: '0.35' };
const GOLD: Tone = { fill: 'accent', shadow: '0.35' };

const layer = (id: string, tone: Tone, cut: string[], solid: string[] = [], lit: number[] = []): SceneLayer => ({ id, depth: 0, ...tone, cut, solid, lit });

/** Far towers with a few window holes. */
function far(t: Tools, base = 70): string {
  let d = '';
  let x = -4;
  while (x < W + 4) {
    const w = 9 + t.rand() * 9;
    const h = 10 + t.rand() * 26;
    d += t.rect(x, base - h, w, h + 40);
    if (w > 12 && h > 18) d += t.grid(x + 3, base - h + 4, 2, Math.floor((h - 8) / 6), 2, 3, w - 10, 3, 0.3);
    x += w + 1.5 + t.rand() * 3;
  }
  return d;
}

/** A ground sheet with a rough top edge. */
function ground(t: Tools, y = G, bump = 2): string {
  const pts: Pt[] = [[-4, y]];
  for (let x = 12; x < W; x += 16) pts.push([x, y - bump / 2 + t.rand() * bump]);
  pts.push([W + 4, y], [W + 4, H + 4], [-4, H + 4]);
  return t.path(pts);
}

/** A neem: trunk plus a wide, rough canopy, as [trunk, canopy]. */
function tree(t: Tools, cx: number, h: number, rx: number): [string, string] {
  return [t.rect(cx - 1.3, G - h * 0.7, 2.6, h * 0.7 + 1), t.blob(cx, G - h, rx, rx * 0.42, 14, 0.32)];
}

/** A hedge: a low, rough clump. */
function bush(t: Tools, cx: number, rx: number): string {
  return t.blob(cx, G - 4, rx, 7.5, 22, 0.34);
}

/** A roof water tank on legs, as on every Gurugram house. */
function tank(t: Tools, x: number, y: number): string {
  return t.path([
    [x, y - 8],
    [x + 11, y - 8],
    [x + 11, y - 3],
    [x + 9.5, y - 3],
    [x + 9.5, y + 0.5],
    [x + 1.5, y + 0.5],
    [x + 1.5, y - 3],
    [x, y - 3],
  ]);
}

/** Grass tuft: three quick cuts. */
function tuft(t: Tools, x: number, y = G + 1): string {
  return t.path([
    [x, y],
    [x + 2, y - 7],
    [x + 4, y - 1.5],
    [x + 6, y - 9],
    [x + 7.5, y - 1.5],
    [x + 10, y - 6],
    [x + 11, y],
  ]);
}

function home(seed: string): SceneLayer[] {
  const t = makeTools(`v-home-${seed}`, 0.5);
  const bx = 46;
  const bw = 62;
  const top = 38;
  const body = t.rect(bx, top, bw, G + 1 - top) + t.grid(bx + 7, top + 8, 3, 2, 10, 8, 8, 8);
  const [trunk, crown] = tree(t, 132, 36, 17);
  return [
    layer('far', FAR, [far(t)]),
    layer('lawn', LAWN, [ground(t)]),
    layer('rooms', { fill: 'deep', shadow: '0' }, [], [t.rect(bx + 4, top + 4, bw - 8, 36)]),
    layer('home', { fill: 'home', shadow: '0.45' }, [body], [], [0]),
    layer('parapet', MAIN, [], [t.rect(bx - 2, top - 3, bw + 4, 4), t.rect(bx - 3, top + 18, bw + 6, 2.6)]),
    layer('trunk', WOOD, [], [trunk]),
    layer('leaf', LEAF, [], [crown, bush(t, 22, 16)]),
    // Front wall with a jali of small holes, and a pillar at the gate.
    layer('wall', MAIN, [t.rect(112, 74, 40, 9) + t.grid(116, 77, 6, 1, 3, 3, 3.2, 0)], [t.rect(109, 70, 5, 13)]),
    layer('near', INK, [], [tank(t, bx + 44, top - 3), t.rect(bx + 26, 71, 10, 12)]),
  ];
}

function tower(seed: string): SceneLayer[] {
  const t = makeTools(`v-tower-${seed}`, 0.5);
  const x = 64;
  const w = 34;
  const top = 10;
  const main =
    t.path([
      [x, top + 10],
      [x + w, top],
      [x + w, G + 1],
      [x, G + 1],
    ]) + t.grid(x + 5, top + 18, 4, 7, 3, 4, 4, 2.6);
  const side = t.rect(102, 34, 24, 50) + t.grid(106, 40, 3, 5, 3, 3, 3.5, 4);
  const left = t.rect(30, 44, 26, 40) + t.grid(34, 50, 3, 4, 3, 3, 4, 4);
  return [
    layer('far', FAR, [far(t, 64)]),
    layer('lawn', LAWN, [ground(t)]),
    layer('blocks', MID, [side, left], [], [0, 1]),
    layer('main', SIGN, [main], [], [0]),
    layer('near', MAIN, [t.rect(56, 73, 50, 10) + t.grid(60, 76, 6, 1, 5, 4, 2.6, 0)]),
    layer('leaf', LEAF, [], [bush(t, 20, 16), bush(t, 140, 18)]),
  ];
}

/** Maps (u, v) in 0..1 onto a tilted sheet with corners a (top left), b (top right) and d (bottom left). */
function sheet(a: Pt, b: Pt, d: Pt) {
  const at = (u: number, v: number): Pt => [a[0] + u * (b[0] - a[0]) + v * (d[0] - a[0]), a[1] + u * (b[1] - a[1]) + v * (d[1] - a[1])];
  const slit = (u1: number, u2: number, v: number, h: number): Pt[] => [at(u1, v), at(u2, v), at(u2, v + h), at(u1, v + h)];
  return { at, slit, outline: [at(0, 0), at(1, 0), at(1, 1), at(0, 1)] as Pt[] };
}

function documentScene(seed: string): SceneLayer[] {
  const t = makeTools(`v-doc-${seed}`, 0.5);
  const back = sheet([30, 20], [90, 12], [38, 88]);
  const front = sheet([52, 14], [112, 10], [56, 90]);
  let page = t.path(front.outline) + t.path(front.slit(0.12, 0.66, 0.1, 0.05));
  for (const [v, u2] of [
    [0.26, 0.86],
    [0.34, 0.8],
    [0.42, 0.88],
    [0.5, 0.62],
  ] as const)
    page += t.path(front.slit(0.12, u2, v, 0.03));
  page += t.path(front.slit(0.12, 0.44, 0.84, 0.025));
  return [
    layer('desk', MID, [
      t.path([
        [-4, 64],
        [W + 4, 56],
        [W + 4, H + 4],
        [-4, H + 4],
      ]),
    ]),
    layer('back', { fill: 'concrete', shadow: '0.3' }, [t.path(back.outline)]),
    layer('page', SHEET, [page]),
    // A round office stamp on the page, in sindoor ink.
    layer('stamp', { fill: 'pin', shadow: '0' }, [
      t.oct(94, 66, 11) + t.oct(94, 66, 8.4) + t.path([[88.6, 66.4], [90.6, 64.4], [92.6, 66.4], [97.6, 61.4], [99.6, 63.4], [92.6, 70.4]]),
    ]),
    // A pen beside it.
    layer('pen', INK, [], [
      t.path([
        [124, 26],
        [129, 24],
        [146, 76],
        [143, 82],
        [141, 78],
      ]),
    ]),
  ];
}

function calculator(seed: string): SceneLayer[] {
  const t = makeTools(`v-calc-${seed}`, 0.5);
  const paper = sheet([14, 22], [60, 16], [20, 90]);
  let loan = t.path(paper.outline);
  for (const v of [0.14, 0.26, 0.38, 0.5, 0.62]) loan += t.path(paper.slit(0.14, 0.82, v, 0.04));
  const coin = (x: number, y: number) =>
    t.path([
      [x + 3, y],
      [x + 21, y],
      [x + 24, y + 2],
      [x + 24, y + 4],
      [x + 21, y + 6],
      [x + 3, y + 6],
      [x, y + 4],
      [x, y + 2],
    ]);
  let coins = '';
  for (let k = 0; k < 5; k += 1) coins += coin(114 + (k % 2) * 1.2, 76 - k * 6.4);
  const body = t.rect(62, 12, 42, 72) + t.rect(67, 18, 32, 13) + t.grid(67, 36, 4, 5, 6, 6, 2.7, 3);
  return [
    layer('desk', MID, [
      t.path([
        [-4, 70],
        [W + 4, 64],
        [W + 4, H + 4],
        [-4, H + 4],
      ]),
    ]),
    layer('paper', SHEET, [loan]),
    layer('coins', GOLD, [], [coins]),
    // The display glows teal behind its window; the keys show the desk.
    layer('display', SIGN, [], [t.rect(68, 19, 30, 11)]),
    layer('body', INK, [body]),
    layer('digits', { fill: 'highlight', shadow: '0' }, [], [t.rect(84, 22, 12, 5)]),
  ];
}

function key(seed: string): SceneLayer[] {
  const t = makeTools(`v-key-${seed}`, 0.5);
  // A wall with a doorway; the door stands a little open.
  const wall = t.rect(-4, 4, W + 8, G - 3) + t.rect(60, 16, 42, G - 15);
  const door =
    t.path([
      [62, 17],
      [92, 22],
      [92, 78],
      [62, G + 1],
    ]) +
    t.path([
      [67, 25],
      [87, 28],
      [87, 46],
      [67, 45],
    ]) +
    t.path([
      [67, 52],
      [87, 52],
      [87, 72],
      [67, 75],
    ]);
  const bow = t.oct(40, 70, 10) + t.oct(40, 70, 4.6);
  const blade = t.path([
    [49, 67],
    [110, 67],
    [110, 74],
    [106, 74],
    [106, 78],
    [101, 78],
    [101, 74],
    [95, 74],
    [95, 77],
    [90, 77],
    [90, 74],
    [49, 74],
  ]);
  return [
    layer('wall', MID, [wall]),
    // The room beyond the open door.
    layer('room', { fill: 'deep', shadow: '0' }, [], [t.rect(62, 17, 39, G - 15)]),
    layer('floor', MAIN, [ground(t, G + 1, 1)]),
    layer('door', SIGN, [door], [t.rect(84, 50, 4, 2.6)]),
    layer('pot', MAIN, [], [
      t.path([
        [126, 70],
        [142, 70],
        [140, G + 1],
        [128, G + 1],
      ]),
    ]),
    layer('plant', LEAF, [], [t.blob(134, 60, 12, 10, 12, 0.35)]),
    layer('key', GOLD, [bow, blade]),
  ];
}

function plot(seed: string): SceneLayer[] {
  const t = makeTools(`v-plot-${seed}`, 0.5);
  // Corner stones of the plot and a rope between them, seen from the road.
  const stone = (x: number, y: number) =>
    t.path([
      [x, y],
      [x + 2, y - 3],
      [x + 5, y - 3],
      [x + 7, y],
      [x + 7, y + 7],
      [x, y + 7],
    ]);
  const rope = (x1: number, y1: number, x2: number, y2: number) =>
    t.path([
      [x1, y1],
      [x2, y2],
      [x2, y2 + 1.2],
      [x1, y1 + 1.2],
    ]);
  return [
    layer('far', FAR, [far(t, 66)]),
    layer('blocks', MID, [t.rect(-4, 40, 26, 32) + t.grid(2, 46, 2, 2, 5, 5, 6, 6), t.rect(136, 36, 28, 36) + t.grid(142, 42, 2, 3, 5, 5, 6, 4)], [], [0, 1]),
    layer('lawn', LAWN, [ground(t, 70, 1.5)]),
    layer('posts', INK, [], [t.rect(95, 51, 3, 26), t.rect(121, 50, 3, 27)]),
    layer(
      'board',
      SIGN,
      [
        // A blank board on two posts, with slits where the words would go.
        t.path([
          [88, 30],
          [130, 28],
          [131, 50],
          [89, 52],
        ]) +
          t.rect(95, 35, 28, 2.6) +
          t.rect(95, 41, 18, 2.6),
      ],
    ),
    layer('leaf', LEAF, [], [tuft(t, 40), tuft(t, 70, 90), tuft(t, 134, 88), bush(t, 150, 10)]),
    layer('rope', WOOD, [], [rope(28, 77.5, 63, 71.5), rope(68, 71.5, 127, 71.5), rope(132, 72, 147, 87)]),
    layer('stones', SHEET, [], [stone(22, 76), stone(62, 70), stone(126, 70), stone(146, 86)]),
  ];
}

function pg(seed: string): SceneLayer[] {
  const t = makeTools(`v-pg-${seed}`, 0.4);
  // A shared room: two beds, a window with bars, a desk and a cupboard.
  const bed = (x: number) =>
    t.path([
      [x, 60],
      [x + 3, 60],
      [x + 3, 66],
      [x + 44, 66],
      [x + 44, 62],
      [x + 47, 62],
      [x + 47, 84],
      [x + 44, 84],
      [x + 44, 78],
      [x + 3, 78],
      [x + 3, 84],
      [x, 84],
    ]);
  return [
    layer('wall', MID, [t.rect(-4, 74, W + 8, 30), t.rect(58, 14, 44, 32) + t.grid(61, 17, 4, 1, 8.5, 26, 1.8, 0)]),
    layer('floor', MAIN, [ground(t, 84, 0.6)]),
    layer('beds', WOOD, [bed(8), bed(105)], [t.rect(58, 58, 44, 3), t.rect(60, 61, 2.4, 22), t.rect(97.6, 61, 2.4, 22)]),
    layer('sheets', SHEET, [], [t.rect(12, 60, 12, 5), t.rect(136, 62, 12, 5)]),
    layer('blankets', SIGN, [], [t.rect(26, 67, 20, 10), t.rect(108, 67, 26, 10)]),
    layer('cupboard', MAIN, [t.rect(134, 30, 22, 54) + t.rect(144.4, 34, 1.2, 46)]),
    layer('lamp', INK, [], [t.rect(72, 52, 16, 6), t.rect(78, 44, 3, 8)]),
  ];
}

const builders = { calculator, key, document: documentScene, tower, home, plot, pg };
export type VignetteTheme = keyof typeof builders;

export function vignetteLayers(theme: VignetteTheme, seed = '1'): SceneLayer[] {
  return builders[theme](seed);
}

/** The hand-cut card a vignette is printed on, as the website cuts it. */
export function vignetteFrame(theme: VignetteTheme, seed: string): string {
  return makeTools(`edge-${theme}-${seed}`, 0.9).rect(1.2, 1.2, W - 2.4, H - 2.4);
}
