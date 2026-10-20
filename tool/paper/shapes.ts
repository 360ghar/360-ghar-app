// Vendored from 360ghar-web-ui-2/src/lib/paper/shapes.ts on 2026-09-30.
/**
 * Tools for drawing hand-cut paper shapes in SVG. Every vertex gets a small
 * seeded jitter, so edges look cut by hand and stay the same on every render.
 */
import { rng } from './cut.ts';

export type Layer = {
  id: string;
  fill: string;
  /** How far the layer moves in parallax. 0 = fixed, 1 = most. */
  depth: number;
  /** Colour of the shadow this layer casts on the layer behind it. */
  shadow: string;
  /** Paths with fill-rule evenodd: cut-outs (windows) are holes. */
  cut: string[];
  /** Paths with fill-rule nonzero: overlapping solids (trees, vehicles). */
  solid: string[];
};

export type Pt = [number, number];

/** A cloud strip: `[share of the width, rise]` points from the left end to the right end, both ends on the flat base. */
export type CloudProfile = [number, number][];
export const CLOUD: CloudProfile = [[0, 12], [0.18, 3], [0.35, 6], [0.52, -5], [0.74, 2], [1, 12]];
/** The outline of a cloud at (x, y), `w` wide. For tools that place points themselves (mirror, rounding). */
export const cloudPts = (x: number, y: number, w: number, profile: CloudProfile = CLOUD): Pt[] => profile.map(([f, dy]) => [x + w * f, y + dy]);

/** A trunk that forks into branches: nine points, `dx` gives each one's sideways offset from `cx`; the foot sinks `foot` below `g`. */
export const trunkPts = (cx: number, g: number, h: number, dx: number[], foot = 0): Pt[] =>
  [0, 0.55, 0.72, 0.76, 0.62, 0.8, 0.78, 0.55, 0].map((f, i): Pt => [cx + dx[i]!, f ? g - h * f : g + foot]);

type TreeStyle = {
  trunk: number[];
  /** How far the trunk foot sinks below the ground line. */
  foot?: number;
  /** Canopy: centre offset from the top of the tree, vertical radius, points, roughness. */
  canopy: [dy: number, ry: number, n: number, rough: number];
  /** Leaf gaps: centre offset (share of `rx`, then pixels), radii, points, roughness. */
  gaps?: [fx: number, dy: number, rx: number, ry: number, n: number, rough: number][];
};

export function makeTools(seed: string, amp = 1.1) {
  const rand = rng(seed);
  const j = (v: number) => Math.round((v + (rand() - 0.5) * 2 * amp) * 10) / 10;
  const path = (pts: Pt[]) => `M${pts.map(([x, y]) => `${j(x)} ${j(y)}`).join('L')}Z`;
  const rect = (x: number, y: number, w: number, h: number) =>
    path([
      [x, y],
      [x + w, y],
      [x + w, y + h],
      [x, y + h],
    ]);
  /** Holes in a grid, like windows cut out with a craft knife. */
  const grid = (x: number, y: number, cols: number, rows: number, w: number, h: number, gx: number, gy: number, skip = 0) => {
    let d = '';
    for (let r = 0; r < rows; r += 1) {
      for (let c = 0; c < cols; c += 1) {
        if (skip > 0 && rand() < skip) continue;
        d += rect(x + c * (w + gx), y + r * (h + gy), w, h);
      }
    }
    return d;
  };
  /** A polygon around an ellipse with a rough edge (leaf canopy, bushes). */
  const blob = (cx: number, cy: number, rx: number, ry: number, n: number, rough: number) => {
    const pts: Pt[] = [];
    for (let i = 0; i < n; i += 1) {
      const a = (i / n) * Math.PI * 2;
      const k = 1 - rough / 2 + rand() * rough;
      pts.push([cx + Math.cos(a) * rx * k, cy + Math.sin(a) * ry * k]);
    }
    return path(pts);
  };
  const oct = (cx: number, cy: number, r: number) => {
    const pts: Pt[] = [];
    for (let k = 0; k < 8; k += 1) {
      const a = ((22.5 + 45 * k) * Math.PI) / 180;
      pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
    }
    return path(pts);
  };
  const cloud = (x: number, y: number, w: number, profile?: CloudProfile) => path(cloudPts(x, y, w, profile));
  /** A gulmohar: a forked trunk and a rough canopy with leaf gaps, both as solid paths. */
  const tree = (cx: number, g: number, h: number, rx: number, { trunk, foot, canopy: [cdy, ry, n, rough], gaps = [] }: TreeStyle) => {
    const stem = path(trunkPts(cx, g, h, trunk, foot));
    const top = g - h;
    const crown = blob(cx, top + cdy, rx, ry, n, rough) + gaps.map(([fx, dy, gx, gy, gn, gr]) => blob(cx + rx * fx, top + dy, gx, gy, gn, gr)).join('');
    return { trunk: stem, canopy: crown };
  };
  /** A row of far towers with window holes, from x = -6, each 22 to 38 wide, standing on `base` and running `drop` below it. */
  const skyline = (base: number, { heights, slant, drop, inset }: { heights: number[]; slant: boolean; drop: number; inset: number }) => {
    let x = -6;
    let d = '';
    for (const h of heights) {
      const w = 22 + rand() * 16;
      const crown = slant ? rand() : 0;
      d +=
        crown > 0.7
          ? path([
              [x, base - h + 8],
              [x + w, base - h],
              [x + w, base + drop],
              [x, base + drop],
            ])
          : rect(x, base - h, w, h + drop);
      d += grid(x + 5, base - h + inset, Math.max(1, Math.floor((w - 8) / 8)), Math.floor((h - inset - 4) / 12), 3, 5, 5, 7, 0.4);
      x += w + 3;
    }
    return d;
  };
  return { rand, j, path, rect, grid, blob, oct, cloud, tree, skyline };
}

