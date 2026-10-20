// Adapted from 360ghar-web-ui-2/src/features/home/diorama/gurugram.ts on 2026-09-30.
// Changes: fills are app tone names, shadows are alpha values, the sun and the kite
// move into the band a portrait phone shows (x 475 to 1125), and two onboarding
// layers are added: a map pin on the street (page 2) and a home with one lit window (page 3).
/**
 * The Gurugram street diorama, built as paper layers.
 *
 * Layers of card stock, far to near: sky, clouds, the Cyber City towers, a
 * kite, sector apartment blocks, the Rapid Metro line and its train, the
 * street, and the kerb with the road. Each layer is one flat tone (cool sage and
 * teal far away, warm clay and brown near, the train in brand kesar) and
 * is cut by hand (small jitter on every vertex). All shapes are made at build
 * time from fixed seeds, so the output is static SVG and the same on every
 * render. Clouds, kite and train have their own layers, so CSS can move them.
 *
 * Coordinate space: 1600 x 960. The street level is y = 800. The road below
 * the kerb gives the phone crop room: the street stays above the search sheet.
 * The chai stall, the auto and the cow sit in the middle third, the part a
 * 360 px screen shows.
 */

import { makeTools, type Pt } from './shapes.ts';

import type { Layer } from './shapes.ts';

export type { Layer };

export const W = 1600;
export const H = 960;

/* ------------------------------------------------------------------ */
/* Layer 0: sky with a cut-paper sun and two cloud strips.             */
/* ------------------------------------------------------------------ */

function sky(): Layer {
  const t = makeTools('sky', 0.6);
  const sun: Pt[] = [];
  for (let i = 0; i < 40; i += 1) {
    const a = (i / 40) * Math.PI * 2;
    sun.push([990 + Math.cos(a) * 104, 270 + Math.sin(a) * 104]);
  }
  return { id: 'sky', fill: 'sun', depth: 0, shadow: '0', cut: [t.path(sun)], solid: [] };
}

/** Paper clouds: a flat cut base and a top made of overlapping round bumps. */
function clouds(): Layer {
  const t = makeTools('clouds', 0.5);
  const cloud = (x0: number, base: number, bumps: [number, number][]) => {
    const start = x0 + Math.min(...bumps.map(([c, r]) => c - r));
    const end = x0 + Math.max(...bumps.map(([c, r]) => c + r));
    const pts: Pt[] = [];
    for (let x = start; x < end; x += 7) {
      let top = base;
      for (const [c, r] of bumps) {
        const dx = x - (x0 + c);
        if (Math.abs(dx) < r) top = Math.min(top, base - r * 0.3 - Math.sqrt(r * r - dx * dx));
      }
      pts.push([x, top]);
    }
    pts.push([end, base], [start, base]);
    return t.path(pts);
  };
  return {
    id: 'clouds',
    fill: 'cloud',
    depth: 0.05,
    shadow: '0.16',
    cut: [
      // In the gaps between towers: top right by the sun, and the open sky on the left.
      cloud(1430, 250, [[0, 22], [32, 32], [66, 24], [92, 14]]),
      cloud(600, 525, [[0, 18], [30, 28], [62, 20]]),
      cloud(236, 548, [[0, 20], [32, 30], [66, 24], [92, 14]]),
    ],
    solid: [],
  };
}

/* ------------------------------------------------------------------ */
/* Layer 1: Cyber City towers.                                         */
/* ------------------------------------------------------------------ */

type Tower = { x: number; w: number; top: number; crown: 'flat' | 'slantL' | 'slantR' | 'step' | 'spire' | 'notch' };

const TOWERS: Tower[] = [
  { x: 40, w: 84, top: 470, crown: 'flat' },
  { x: 150, w: 58, top: 430, crown: 'spire' },
  { x: 430, w: 92, top: 500, crown: 'slantL' },
  { x: 740, w: 74, top: 360, crown: 'slantR' },
  { x: 836, w: 100, top: 250, crown: 'step' },
  { x: 958, w: 62, top: 300, crown: 'spire' },
  { x: 1040, w: 118, top: 190, crown: 'slantL' },
  { x: 1180, w: 84, top: 290, crown: 'notch' },
  { x: 1285, w: 124, top: 360, crown: 'flat' },
  { x: 1430, w: 72, top: 270, crown: 'slantR' },
  { x: 1522, w: 96, top: 400, crown: 'step' },
];

function towers(): Layer {
  const t = makeTools('towers');
  const cut: string[] = [];
  for (const tw of TOWERS) {
    const { x, w, top } = tw;
    const b = H + 10;
    let outline: Pt[];
    switch (tw.crown) {
      case 'slantL':
        outline = [[x, top + 40], [x + w, top], [x + w, b], [x, b]];
        break;
      case 'slantR':
        outline = [[x, top], [x + w, top + 36], [x + w, b], [x, b]];
        break;
      case 'step':
        outline = [
          [x + w * 0.3, top - 34],
          [x + w * 0.7, top - 34],
          [x + w * 0.7, top],
          [x + w, top],
          [x + w, b],
          [x, b],
          [x, top],
          [x + w * 0.3, top],
        ];
        break;
      case 'spire':
        outline = [
          [x + w / 2 - 2, top - 70],
          [x + w / 2 + 2, top - 70],
          [x + w / 2 + 3, top - 18],
          [x + w, top],
          [x + w, b],
          [x, b],
          [x, top],
          [x + w / 2 - 3, top - 18],
        ];
        break;
      case 'notch':
        outline = [
          [x, top],
          [x + w * 0.38, top],
          [x + w * 0.5, top + 22],
          [x + w * 0.62, top],
          [x + w, top],
          [x + w, b],
          [x, b],
        ];
        break;
      default:
        outline = [
          [x + w * 0.62, top - 44],
          [x + w * 0.66, top - 44],
          [x + w * 0.66, top],
          [x + w, top],
          [x + w, b],
          [x, b],
          [x, top],
          [x + w * 0.62, top],
        ];
    }
    const cols = Math.max(2, Math.floor((w - 18) / 17));
    const winTop = top + (tw.crown === 'slantL' || tw.crown === 'slantR' ? 52 : 22);
    const rows = Math.floor((640 - winTop) / 24);
    // Glass towers get tall, thin window strips.
    cut.push(t.path(outline) + t.grid(x + 10, winTop, cols, rows, 7, 12, 10, 12, 0.35));
  }
  return { id: 'towers', fill: 'far', depth: 0.15, shadow: '0.32', cut, solid: [], lit: cut.map((_, i) => i) } as Layer;
}

/* ------------------------------------------------------------------ */
/* Layer 2: sector apartment blocks with water tanks and balconies.    */
/* ------------------------------------------------------------------ */

type Block = { x: number; w: number; top: number; tanks: number };

const BLOCKS: Block[] = [
  { x: -20, w: 170, top: 610, tanks: 2 },
  { x: 170, w: 150, top: 560, tanks: 1 },
  { x: 340, w: 210, top: 600, tanks: 2 },
  { x: 575, w: 140, top: 540, tanks: 1 },
  { x: 735, w: 190, top: 590, tanks: 2 },
  { x: 950, w: 150, top: 555, tanks: 1 },
  { x: 1120, w: 220, top: 600, tanks: 3 },
  { x: 1360, w: 150, top: 545, tanks: 1 },
  { x: 1530, w: 110, top: 590, tanks: 1 },
];

function blocks(): Layer {
  const t = makeTools('blocks');
  const cut: string[] = [];
  for (const bl of BLOCKS) {
    const { x, w, top } = bl;
    let d = t.rect(x, top, w, H + 10 - top);
    // Water tanks on the roof, on short legs.
    for (let i = 0; i < bl.tanks; i += 1) {
      const tx = x + 16 + i * ((w - 50) / Math.max(1, bl.tanks));
      d += t.path([
        [tx, top - 26],
        [tx + 30, top - 26],
        [tx + 30, top - 8],
        [tx + 26, top - 8],
        [tx + 26, top + 1],
        [tx + 4, top + 1],
        [tx + 4, top - 8],
        [tx, top - 8],
      ]);
    }
    // A stair head on wider blocks.
    if (w > 180) d += t.rect(x + w - 54, top - 18, 34, 19);
    // Balcony bands: long slits, with a few windows between.
    const rows = Math.floor((800 - top - 20) / 30);
    for (let r = 0; r < rows; r += 1) {
      const y = top + 18 + r * 30;
      d += t.rect(x + 12, y, w - 24, 5);
      d += t.grid(x + 18, y + 11, Math.floor((w - 30) / 26), 1, 12, 10, 14, 0, 0.3);
    }
    cut.push(d);
  }
  return { id: 'blocks', fill: 'mid', depth: 0.3, shadow: '0.34', cut, solid: [], lit: cut.map((_, i) => i) } as Layer;
}

/* ------------------------------------------------------------------ */
/* Layer 3: the Rapid Metro viaduct and a three-coach train.           */
/* ------------------------------------------------------------------ */

function metro(): Layer {
  const t = makeTools('metro');
  const beamTop = 612;
  const cut: string[] = [];
  // Viaduct beam with a lower lip.
  let beam = t.path([
    [-20, beamTop],
    [W + 20, beamTop - 8],
    [W + 20, beamTop + 22],
    [W - 10, beamTop + 30],
    [-20, beamTop + 38],
  ]);
  // Parapet posts along the top of the beam.
  for (let x = 10; x < W; x += 46) beam += t.rect(x, beamTop - 12 - (x / W) * 8, 5, 12);
  cut.push(beam);
  // T-shaped piers.
  for (const c of [110, 520, 930, 1340]) {
    const y0 = beamTop + 34 - (c / W) * 8;
    cut.push(
      t.path([
        [c - 58, y0],
        [c + 58, y0],
        [c + 26, y0 + 28],
        [c + 20, H + 10],
        [c - 20, H + 10],
        [c - 26, y0 + 28],
      ]),
    );
  }
  return { id: 'metro', fill: 'concrete', depth: 0.5, shadow: '0.4', cut, solid: [] };
}

/** The Rapid Metro train: three coaches, the front one with a sloped nose. Its own layer, so it can run. */
function train(): Layer {
  const t = makeTools('train');
  const trainY = 612 - 70;
  const coach = (x: number, w: number, nose: boolean) => {
    const y = trainY - (x / W) * 8;
    const outline: Pt[] = nose
      ? [
          [x, y],
          [x + w - 34, y],
          [x + w - 6, y + 22],
          [x + w, y + 56],
          [x, y + 56],
        ]
      : [
          [x, y + 4],
          [x + 4, y],
          [x + w - 4, y],
          [x + w, y + 4],
          [x + w, y + 56],
          [x, y + 56],
        ];
    let d = t.path(outline);
    d += t.grid(x + 16, y + 12, Math.floor((w - (nose ? 60 : 30)) / 30), 1, 20, 18, 10, 0);
    // Doors.
    d += t.rect(x + w * 0.32, y + 10, 12, 38);
    if (!nose) d += t.rect(x + w * 0.7, y + 10, 12, 38);
    // Stripe under the windows.
    d += t.rect(x + 8, y + 40, w - (nose ? 30 : 16), 3);
    return d;
  };
  return {
    id: 'train',
    fill: 'accent',
    depth: 0.5,
    shadow: '0.4',
    cut: [coach(380, 200, false) + coach(588, 200, false) + coach(796, 214, true)],
    solid: [],
  };
}

/* ------------------------------------------------------------------ */
/* A kite over the sector, between the towers and the blocks.         */
/* ------------------------------------------------------------------ */

function kite(): Layer {
  const t = makeTools('kite', 0.4);
  // Left of centre: the centred headline sits over the middle of the sky.
  const kx = 640;
  const ky = 300;
  // Diamond with the spine and the bow cut as thin slits.
  const body =
    t.path([
      [kx, ky - 44],
      [kx + 32, ky - 6],
      [kx, ky + 40],
      [kx - 32, ky - 6],
    ]) +
    t.rect(kx - 1, ky - 34, 2, 64) +
    t.rect(kx - 24, ky - 7, 48, 2);
  // A thin strip of paper along points, `w` wide.
  const strip = (pts: Pt[], w: number) => t.path([...pts, ...pts.map(([x, y]) => [x + w, y] as Pt).reverse()]);
  const bow = (bx: number, by: number) =>
    t.path([
      [bx - 9, by - 5],
      [bx, by],
      [bx - 9, by + 5],
    ]) +
    t.path([
      [bx + 9, by - 5],
      [bx, by],
      [bx + 9, by + 5],
    ]);
  return {
    id: 'kite',
    fill: 'accent',
    depth: 0.2,
    shadow: '0.3',
    cut: [body],
    solid: [
      // Tail with three bows, and the string down to a roof out of sight.
      strip([[kx - 0.7, ky + 38], [kx + 5, ky + 62], [kx - 2, ky + 86], [kx + 6, ky + 108]], 1.4),
      bow(kx + 5, ky + 64),
      bow(kx - 2, ky + 88),
      bow(kx + 6, ky + 110),
      strip([[kx + 2, ky + 4], [kx + 60, ky + 70], [kx + 130, ky + 150], [kx + 210, ky + 250], [kx + 280, ky + 360]], 1.5),
    ],
  };
}

/* ------------------------------------------------------------------ */
/* Layer 4: the street. Shops, gulmohar trees, lamps, an auto.         */
/* The chai stall, the auto and the cow stay in the middle third.      */
/* ------------------------------------------------------------------ */

function street(): Layer[] {
  const t = makeTools('street');
  const g = 800;
  // App change: each part of the street is its own card stock, so the street
  // reads in colour (gulmohar blooms, a green CNG auto, a teal chai awning).
  const pavement: string[] = [];
  const shopsCut: string[] = [];
  const stallCut: string[] = [];
  const posts: string[] = [];
  const canopies: string[] = [];
  const trunks: string[] = [];
  const autoCut: string[] = [];
  const cowCut: string[] = [];
  const cartCut: string[] = [];
  const veg: string[] = [];
  const umbrella: string[] = [];

  // Pavement and road, one sheet with a rough top edge.
  const ground: Pt[] = [[-20, g]];
  for (let x = 40; x < W; x += 80) ground.push([x, g - 2 + t.rand() * 4]);
  ground.push([W + 20, g], [W + 20, H + 10], [-20, H + 10]);
  pavement.push(t.path(ground));

  // A row of shops on the left: shutters and signboards.
  let shops = '';
  for (const sx of [0, 118, 236]) {
    shops += t.rect(sx, g - 96, 112, 97);
    for (let k = 0; k < 6; k += 1) shops += t.rect(sx + 12, g - 70 + k * 10, 88, 3);
    shops += t.rect(sx + 14, g - 88, 84, 12);
  }
  shopsCut.push(shops);

  // The chai stall under the first tree: awning with a scalloped edge, counter, kettle.
  const cx0 = 526;
  const aw: Pt[] = [
    [cx0 + 16, g - 108],
    [cx0 + 134, g - 108],
    [cx0 + 150, g - 80],
  ];
  for (let x = cx0 + 150; x > cx0; x -= 15) aw.push([x, g - 80], [x - 7.5, g - 72]);
  aw.push([cx0, g - 80]);
  let stall = t.path(aw);
  stall += t.rect(cx0 + 24, g - 44, 112, 45);
  stall += t.path([
    [cx0 + 56, g - 44],
    [cx0 + 58, g - 58],
    [cx0 + 74, g - 62],
    [cx0 + 90, g - 58],
    [cx0 + 92, g - 44],
  ]);
  stall += t.rect(cx0 + 42, g - 36, 76, 4);
  stallCut.push(stall);
  // Awning poles.
  posts.push(t.rect(cx0 + 4, g - 80, 4, 80), t.rect(cx0 + 142, g - 80, 4, 80));

  // Street lamps.
  for (const lx of [1100, 1500]) {
    posts.push(
      t.path([
        [lx - 3, g],
        [lx - 3, g - 190],
        [lx + 44, g - 204],
        [lx + 52, g - 196],
        [lx + 52, g - 188],
        [lx + 30, g - 188],
        [lx + 30, g - 192],
        [lx + 3, g - 184],
        [lx + 3, g],
      ]),
    );
  }

  // Gulmohar trees: trunk plus a wide, rough canopy with leaf gaps.
  const tree = (cx: number, h: number, rx: number) => {
    const { trunk, canopy } = t.tree(cx, g, h, rx, {
      trunk: [-7, -5, -34, -30, -2, 4, 9, 6, 8],
      canopy: [26, 44, 26, 0.34],
      gaps: [[-0.42, 18, 8, 6, 6, 0.3], [0.36, 30, 10, 6, 6, 0.3], [0.05, 8, 7, 5, 6, 0.3]],
    });
    trunks.push(trunk);
    canopies.push(canopy);
  };
  tree(470, 250, 112);
  tree(1250, 270, 128);

  // Auto-rickshaw, facing left: canopy, windscreen, passenger opening.
  // The wheels are on the kerb layer, so they read darker and nearer.
  const ax = 700;
  const ay = g + 34;
  autoCut.push(
    t.path([
      [ax + 4, ay - 18],
      [ax, ay - 34],
      [ax + 8, ay - 58],
      [ax + 18, ay - 62],
      [ax + 34, ay - 104],
      [ax + 64, ay - 114],
      [ax + 150, ay - 112],
      [ax + 166, ay - 104],
      [ax + 170, ay - 44],
      [ax + 166, ay - 18],
      [ax + 156, ay - 18],
      [ax + 152, ay - 30],
      [ax + 128, ay - 30],
      [ax + 124, ay - 18],
      [ax + 46, ay - 18],
      [ax + 42, ay - 30],
      [ax + 18, ay - 30],
      [ax + 14, ay - 18],
    ]) +
      // Driver opening, then passenger opening, with a pillar between.
      t.path([
        [ax + 38, ay - 96],
        [ax + 66, ay - 102],
        [ax + 68, ay - 60],
        [ax + 26, ay - 60],
      ]) +
      t.path([
        [ax + 78, ay - 102],
        [ax + 152, ay - 100],
        [ax + 154, ay - 54],
        [ax + 78, ay - 54],
      ]) +
      // Roof seam.
      t.rect(ax + 50, ay - 108, 100, 2.5),
  );

  // A zebu cow by the lamp, a Gurugram street constant: the hump over the
  // shoulders, short curved horns, a low head and the dewlap under the throat.
  // Drawn facing right in local units (y is height above the street), then placed.
  const cow: Pt[] = [
    [10, 62],
    [40, 66],
    [70, 67],
    [86, 72],
    [94, 81],
    [102, 82],
    [108, 74],
    [114, 67],
    [118, 66],
    [110, 59],
    [121, 61],
    // Two short horns that curve forward.
    [124, 65],
    [122, 71],
    [124, 76],
    [127, 72],
    [128, 66],
    [130, 66],
    [131, 71],
    [134, 73],
    [134, 67],
    [135, 63],
    [137, 60],
    [143, 50],
    [150, 40],
    [149, 33],
    [141, 32],
    [133, 39],
    [125, 34],
    [117, 25],
    [109, 25],
    [106, 29],
    [106, 0],
    [99, 0],
    [98, 18],
    [95, 18],
    [94, 0],
    [87, 0],
    [86, 24],
    [66, 22],
    [44, 24],
    [40, 18],
    [39, 0],
    [32, 0],
    [31, 16],
    [28, 16],
    [27, 0],
    [20, 0],
    [17, 27],
    [12, 40],
    [10, 50],
    [7, 52],
    [4, 40],
    [3, 24],
    [0, 16],
    [6, 14],
    [6, 23],
    [7, 40],
    [9, 56],
  ];
  const cowAt = (x: number, y: number): Pt => [888 + x * 1.1, g - y * 1.1];
  cowCut.push(t.path(cow.map(([x, y]) => cowAt(x, y))) + t.rect(cowAt(137, 55)[0], cowAt(137, 55)[1], 3, 3));

  // A sabzi cart under the second tree: tray on two wheels, a heap of vegetables, an umbrella.
  const kx = 1318;
  cartCut.push(
    t.rect(kx, g - 58, 144, 10) +
      t.path([
        [kx + 4, g - 48],
        [kx + 140, g - 48],
        [kx + 134, g - 34],
        [kx + 10, g - 34],
      ]),
    t.oct(kx + 34, g - 20, 20) + t.oct(kx + 34, g - 20, 7),
    t.oct(kx + 112, g - 20, 20) + t.oct(kx + 112, g - 20, 7),
  );
  const dome: Pt[] = [];
  for (let i = 0; i <= 12; i += 1) {
    const a = Math.PI + (i / 12) * Math.PI;
    dome.push([kx + 72 + Math.cos(a) * 64, g - 148 + Math.sin(a) * 30]);
  }
  for (let x = kx + 136; x > kx + 8; x -= 16) dome.push([x, g - 148], [x - 8, g - 141]);
  cartCut.push(t.rect(kx - 50, g - 55, 52, 4));
  veg.push(
    t.blob(kx + 32, g - 62, 20, 9, 9, 0.3),
    t.blob(kx + 70, g - 66, 22, 11, 9, 0.3),
    t.blob(kx + 108, g - 62, 20, 9, 9, 0.3),
  );
  umbrella.push(t.rect(kx + 70, g - 146, 3, 88), t.path(dome));

  const part = (id: string, fill: string, cut: string[], solid: string[] = [], shadow = '0.45'): Layer =>
    ({ id, fill, depth: 0.75, shadow, cut, solid });
  return [
    part('street', 'pavement', pavement, [], '0.3'),
    part('shops', 'shop', shopsCut),
    part('posts', 'deep', [], posts, '0.35'),
    part('stall', 'sign', stallCut),
    part('trunks', 'trunk', [], trunks, '0.35'),
    part('trees', 'bloom', canopies),
    part('auto', 'auto', autoCut),
    part('cow', 'cow', cowCut),
    part('umbrella', 'main', [], umbrella),
    part('cart', 'trunk', cartCut),
    part('veg', 'tree', [], veg, '0.3'),
  ];
}

/* ------------------------------------------------------------------ */
/* Layer 5: the near kerb and the road, a parked scooter, and a hedge.  */
/* ------------------------------------------------------------------ */

function kerb(): Layer {
  const t = makeTools('kerb');
  const k = 858;
  const cut: string[] = [];
  const solid: string[] = [];
  const edge: Pt[] = [[-20, k]];
  for (let x = 60; x < W; x += 120) edge.push([x, k - 2 + t.rand() * 5]);
  edge.push([W + 20, k], [W + 20, H + 10], [-20, H + 10]);
  // Lane dashes cut out of the road, in the middle of the carriageway.
  let d = t.path(edge);
  for (let x = 30; x < W; x += 180) d += t.rect(x, k + 52, 64, 7);
  cut.push(d);

  // Parked scooter on the left, facing left, with hub holes in the wheels.
  cut.push(
    t.path([
      [104, k - 12],
      [100, k - 30],
      [106, k - 62],
      [112, k - 76],
      [104, k - 80],
      [106, k - 86],
      [130, k - 88],
      [132, k - 82],
      [120, k - 78],
      [122, k - 44],
      [152, k - 30],
      [160, k - 44],
      [156, k - 52],
      [210, k - 56],
      [222, k - 48],
      [226, k - 24],
      [218, k - 12],
      [208, k - 20],
      [196, k - 20],
      [188, k - 12],
      [132, k - 12],
      [124, k - 20],
      [112, k - 20],
    ]),
  );
  // Each wheel is its own path, so it joins the body instead of cutting it.
  cut.push(t.oct(118, k - 12, 13) + t.oct(118, k - 12, 5), t.oct(202, k - 12, 13) + t.oct(202, k - 12, 5));
  // Wheels of the auto-rickshaw on the street behind.
  cut.push(t.oct(730, 822, 16) + t.oct(730, 822, 6), t.oct(840, 822, 16) + t.oct(840, 822, 6));

  // Hedge on the right, and two bollards.
  solid.push(t.blob(1520, k - 6, 110, 34, 22, 0.3));
  solid.push(t.rect(1146, k - 38, 12, 40), t.rect(1196, k - 38, 12, 40));
  return { id: 'kerb', fill: 'kerb', depth: 1, shadow: '0.5', cut, solid };
}

/* ------------------------------------------------------------------ */
/* Onboarding page 2: a map pin dropped on the street.                  */
/* ------------------------------------------------------------------ */

function pin(): Layer {
  const t = makeTools('pin', 0.9);
  const cx = 800;
  const tip = 796;
  // The listing-map teardrop at 3x, with an octagonal hole.
  const pts: Pt[] = [
    [cx, tip],
    [cx - 57, tip - 90],
    [cx - 66, tip - 138],
    [cx - 45, tip - 183],
    [cx, tip - 204],
    [cx + 45, tip - 183],
    [cx + 66, tip - 138],
    [cx + 57, tip - 90],
  ];
  return { id: 'pin', fill: 'pin', depth: 0.85, shadow: '0.45', cut: [t.path(pts) + t.oct(cx, tip - 138, 24)], solid: [] };
}

/* ------------------------------------------------------------------ */
/* Onboarding page 3: a two-storey home, and the gold behind one window. */
/* ------------------------------------------------------------------ */

const HOME_X = 650;
const HOME_TOP = 560;

function home(): Layer {
  const t = makeTools('home', 0.9);
  const x = HOME_X;
  const g = 800;
  let d = t.rect(x, HOME_TOP, 300, g - HOME_TOP + 2);
  // Four windows and a door, a balcony slit between the floors.
  for (const [wx, wy] of [
    [30, 40],
    [210, 40],
    [30, 140],
    [210, 140],
  ]) {
    d += t.rect(x + wx, HOME_TOP + wy, 60, 50);
  }
  d += t.rect(x + 12, HOME_TOP + 104, 276, 8);
  d += t.rect(x + 128, HOME_TOP + 146, 44, g - HOME_TOP - 146);
  return { id: 'home', fill: 'home', depth: 0.9, shadow: '0.45', cut: [d], solid: [] };
}

/** App change: a terracotta parapet and a black water tank crown the home. */
function roof(): Layer[] {
  const t = makeTools('home', 0.9);
  const x = HOME_X;
  const parapet = t.rect(x - 10, HOME_TOP - 14, 320, 16);
  const tank = [
    t.path([
      [x + 30, HOME_TOP - 58],
      [x + 84, HOME_TOP - 58],
      [x + 84, HOME_TOP - 26],
      [x + 78, HOME_TOP - 26],
      [x + 78, HOME_TOP - 12],
      [x + 36, HOME_TOP - 12],
      [x + 36, HOME_TOP - 26],
      [x + 30, HOME_TOP - 26],
    ]),
  ];
  return [
    { id: 'hometank', fill: 'deep', depth: 0.9, shadow: '0.4', cut: [], solid: tank },
    { id: 'parapet', fill: 'main', depth: 0.9, shadow: '0.4', cut: [], solid: [parapet] },
  ];
}

/** App change: the rooms behind the walls, so windows read as glass, not holes. */
function rooms(): Layer {
  const t = makeTools('rooms', 0.5);
  return { id: 'rooms', fill: 'deep', depth: 0.9, shadow: '0', cut: [], solid: [t.rect(HOME_X + 6, HOME_TOP + 6, 288, 800 - HOME_TOP - 4)] };
}

/** Gold card behind the upper right window, so the window reads as lit. */
function lit(): Layer {
  const t = makeTools('lit', 0.5);
  return { id: 'lit', fill: 'lit', depth: 0.9, shadow: '0', cut: [], solid: [t.rect(HOME_X + 204, HOME_TOP + 34, 72, 62)] };
}

let cache: Layer[] | undefined;

export function gurugramLayers(): Layer[] {
  cache ??= [sky(), clouds(), towers(), kite(), blocks(), metro(), train(), ...street(), kerb(), pin(), rooms(), lit(), home(), ...roof()];
  return cache;
}
