// Vendored from 360ghar-web-ui-2/src/ui/paper/compact.ts on 2026-09-30.
/**
 * Shortens an SVG path made of absolute M, L and Z commands (the output of the
 * paper tools): relative commands, no repeated command letters, no leading
 * zeros. Relative steps are short numbers that repeat (a row of windows is the
 * same few steps again), so the HTML and its gzip get much smaller.
 *
 * The shape is exact at `decimals` places. Without `decimals` the input's own
 * precision is kept, so the result draws the same pixels. Any other path (with
 * curves, arcs or relative commands) comes back unchanged.
 */
export function compactPath(d: string, decimals?: number): string {
  if (!/^[MLZ\d\s.,-]*$/.test(d)) return d;
  const tokens = d.match(/[MLZ]|-?(?:\d+\.?\d*|\.\d+)/g) ?? [];
  const places = decimals ?? Math.max(0, ...tokens.map((n) => n.split('.')[1]?.length ?? 0));
  const k = 10 ** places;

  // Integer units (value x 10^places) to the shortest decimal text.
  const text = (v: number) => {
    const abs = Math.abs(v);
    const int = Math.floor(abs / k);
    const frac = places ? String(abs % k).padStart(places, '0').replace(/0+$/, '') : '';
    const body = frac ? `${int || ''}.${frac}` : String(int);
    return v < 0 ? `-${body}` : body;
  };

  let out = '';
  let cmd = '';
  let last = '';
  let prev = '';
  let sx = 0;
  let sy = 0;
  let cx = 0;
  let cy = 0;
  const put = (n: string) => {
    // A separator is needed unless the number starts with "-", or starts with "." after a number that has one.
    if (prev && !(n.startsWith('-') || (n.startsWith('.') && prev.includes('.')))) out += ' ';
    out += n;
    prev = n;
  };
  const emit = (c: string, a: number, b: number) => {
    // After "l" or "m" further pairs are relative lines, so a repeated "l" can be left out. A
    // repeated "m" must keep its letter: without it the pair would read as a line.
    if (!(c === 'l' && (last === 'l' || last === 'm'))) {
      out += c;
      prev = '';
    }
    last = c;
    put(text(a));
    put(text(b));
  };

  for (let i = 0; i < tokens.length; ) {
    const tok = tokens[i]!;
    if (tok === 'M' || tok === 'L') {
      cmd = tok;
      i += 1;
      continue;
    }
    if (tok === 'Z') {
      out += 'z';
      last = 'z';
      prev = '';
      cx = sx;
      cy = sy;
      i += 1;
      continue;
    }
    const next = tokens[i + 1];
    if (!cmd || next === undefined || /[MLZ]/.test(next)) return d;
    const x = Math.round(Number(tok) * k);
    const y = Math.round(Number(next) * k);
    i += 2;
    if (cmd === 'M') {
      if (out) emit('m', x - cx, y - cy);
      else emit('M', x, y);
      sx = x;
      sy = y;
      cmd = 'L';
    } else {
      emit('l', x - cx, y - cy);
    }
    cx = x;
    cy = y;
  }
  return out;
}
