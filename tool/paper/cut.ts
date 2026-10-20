// Vendored from 360ghar-web-ui-2/src/lib/paper/cut.ts on 2026-09-30. Keep in sync with
// lib/core/design/paper/paper_cut.dart; test/fixtures/paper_fixtures.json checks the port.
/**
 * Hand-cut paper edges.
 *
 * `cutPolygon` returns a CSS `clip-path: polygon(...)` value. Points sit at
 * percentages along each edge, and each point moves inward by a few pixels.
 * The result scales with the element but the wobble stays the same size in
 * pixels, like a sheet cut with scissors. The same seed always gives the same
 * edge, so server and client render the same shape.
 *
 * Content inside a cut sheet needs padding larger than `amp` (see "clear the cut").
 */

type CutOptions = {
  /** Largest inward offset in px. Default 2. */
  amp?: number;
  /** Points on the top and bottom edges. Default 9. */
  across?: number;
  /** Points on the left and right edges. Default 5. */
  down?: number;
};

/** mulberry32: small, fast, deterministic. */
export function rng(seed: number | string): () => number {
  let a = typeof seed === 'number' ? seed : hash(seed);
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function hash(input: string): number {
  let h = 2166136261;
  for (let i = 0; i < input.length; i += 1) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

const r2 = (n: number) => Math.round(n * 100) / 100;

export function cutPolygon(seed: number | string, options: CutOptions = {}): string {
  const { amp = 2, across = 9, down = 5 } = options;
  const rand = rng(seed);
  const off = () => r2(rand() * amp);
  // Spread points unevenly along an edge, as a hand cut would.
  const stops = (n: number) => {
    const out: number[] = [];
    for (let i = 1; i < n; i += 1) {
      const jitter = (rand() - 0.5) * (100 / n) * 0.6;
      out.push(r2((i * 100) / n + jitter));
    }
    return out;
  };

  const pts: string[] = [];
  // Top edge, left to right. Corners are cut slightly off square.
  pts.push(`${off()}px ${off()}px`);
  for (const p of stops(across)) pts.push(`${p}% ${off()}px`);
  pts.push(`calc(100% - ${off()}px) ${off()}px`);
  // Right edge, top to bottom.
  for (const p of stops(down)) pts.push(`calc(100% - ${off()}px) ${p}%`);
  pts.push(`calc(100% - ${off()}px) calc(100% - ${off()}px)`);
  // Bottom edge, right to left.
  for (const p of stops(across).reverse()) pts.push(`${p}% calc(100% - ${off()}px)`);
  pts.push(`${off()}px calc(100% - ${off()}px)`);
  // Left edge, bottom to top.
  for (const p of stops(down).reverse()) pts.push(`${off()}px ${p}%`);

  return `polygon(${pts.join(', ')})`;
}

/**
 * A torn or cut top edge for a full-width band, as an SVG path in a
 * `width` x `height` box. The band is filled below the edge.
 */
export function cutBandPath(seed: number | string, width = 1440, height = 24, segments = 36): string {
  const rand = rng(seed);
  const step = width / segments;
  let d = `M0 ${height}`;
  for (let i = 0; i <= segments; i += 1) {
    const x = r2(Math.min(width, i * step + (i > 0 && i < segments ? (rand() - 0.5) * step * 0.5 : 0)));
    const y = r2(height * 0.25 + rand() * height * 0.55);
    d += ` L${x} ${y}`;
  }
  d += ` L${width} ${height} Z`;
  return d;
}

/**
 * App addition (1 October 2026): a low Gurugram roofline for the top edge of a
 * full-width strip (the navigation bar), as an SVG path in a `width` x `height`
 * box, filled below the roofline. Flat roofs at varied heights, a black water
 * tank on a short stand on some roofs, a stair room now and then, a parapet
 * step, and a narrow gap between some blocks. Every point is inside the box.
 */
export function rooflineBandPath(seed: number | string, width = 390, height = 18): string {
  const rand = rng(seed);
  const h = height;
  let d = `M0 ${height}`;
  const at = (x: number, y: number) => {
    d += ` L${r2(Math.min(width, x))} ${r2(y)}`;
  };
  let x = 0;
  while (x < width) {
    const end = Math.min(width, x + h * (1.4 + rand() * 1.9));
    let y = h * (0.32 + rand() * 0.48);
    const kind = rand();
    const lead = rand();
    const room = end - x;
    at(x, y);
    if (kind < 0.42 && room > h * 1.3) {
      // A water tank on a short stand; the top corners are cut off.
      const tw = h * 0.42;
      const tx = x + h * 0.25 + lead * (room - tw - h * 0.5);
      const stand = y - h * 0.08;
      const top = stand - h * 0.22;
      const c = h * 0.06;
      at(tx + tw * 0.25, y);
      at(tx + tw * 0.25, stand);
      at(tx, stand);
      at(tx, top + c);
      at(tx + c, top);
      at(tx + tw - c, top);
      at(tx + tw, top + c);
      at(tx + tw, stand);
      at(tx + tw * 0.75, stand);
      at(tx + tw * 0.75, y);
    } else if (kind < 0.62 && room > h * 1.6) {
      // A stair room with a slab that overhangs it a little.
      const sw = h * 0.62;
      const sx = x + h * 0.2 + lead * (room - sw - h * 0.4);
      const top = y - h * 0.26;
      const lip = h * 0.06;
      at(sx, y);
      at(sx, top + lip);
      at(sx - lip, top + lip);
      at(sx - lip, top);
      at(sx + sw + lip, top);
      at(sx + sw + lip, top + lip);
      at(sx + sw, top + lip);
      at(sx + sw, y);
    } else if (kind < 0.82) {
      // A parapet step: the far end of the roof stands a little higher.
      const px = x + room * (0.55 + lead * 0.25);
      at(px, y);
      y -= h * 0.12;
      at(px, y);
    }
    at(end, y);
    if (end < width && rand() < 0.28) {
      // A narrow gap between two blocks.
      const gap = h * (0.08 + rand() * 0.1);
      at(end, h * 0.86);
      at(end + gap, h * 0.86);
      x = end + gap;
    } else {
      x = end;
    }
  }
  d += ` L${width} ${height} Z`;
  return d;
}

/**
 * App addition (1 October 2026): the torn bottom edge of a receipt, from x = 0 to
 * `width`, as an open M/L path. Teeth are about `tooth` wide and `depth` deep
 * with a little seeded jitter: valleys sit near y = 0 and tips near y = depth,
 * so the paper hangs below the line. Both ends sit on y = 0.
 */
export function zigzagEdge(seed: number | string, width: number, tooth = 8, depth = 5): string {
  const rand = rng(seed);
  const n = Math.max(2, Math.round(width / tooth));
  const step = width / n;
  let d = 'M0 0';
  for (let i = 0; i < n; i += 1) {
    const tip = r2(i * step + step * (0.5 + (rand() - 0.5) * 0.3));
    d += ` L${tip} ${r2(depth * (0.78 + rand() * 0.22))}`;
    d += i + 1 < n ? ` L${r2((i + 1) * step)} ${r2(rand() * depth * 0.18)}` : ` L${width} 0`;
  }
  return d;
}
