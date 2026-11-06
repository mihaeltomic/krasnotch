/**
 * Draws the notch glow exactly the way the Krasnotch app (GlowLayerView + MagicLayer) does:
 * three blurred bands (haze, glow, core) stroked along the notch outline with rotating conic gradients,
 * a travelling head for Comet and Ping-pong, the 8×8 Bayer dither, and Magic's wand plus glitter.
 * Ported from the film renderer, which was checked against the app frame by frame.
 */
export type Motion = "flow" | "pulse" | "comet" | "scanner" | "blink" | "solid";

export type GlowStyle = {
  motion: Motion;
  colors: readonly string[];
  /** Cycle length in seconds. */
  speed: number;
  /** Thickness in points, as in the app. */
  th: number;
  int: number;
  dither: boolean;
  magic: boolean;
};

const TAU = Math.PI * 2;
const BAYER8 = [0,32,8,40,2,34,10,42,48,16,56,24,50,18,58,26,12,44,4,36,14,46,6,38,60,28,52,20,62,30,54,22,3,35,11,43,1,33,9,41,51,19,59,27,49,17,57,25,15,47,7,39,13,45,5,37,63,31,55,23,61,29,53,21];
const rand = (n: number) => {
  const x = Math.sin(n * 12.9898 + 78.233) * 43758.5453;
  return x - Math.floor(x);
};
const easeIO = (f: number) => (f < 0.5 ? 2 * f * f : 1 - Math.pow(-2 * f + 2, 2) / 2);

const makeCanvas = () => document.createElement("canvas");

export class NotchGlowRenderer {
  private ctx: CanvasRenderingContext2D;
  private off = makeCanvas().getContext("2d")!;
  private full = makeCanvas().getContext("2d")!;
  private low = makeCanvas().getContext("2d", { willReadFrequently: true })!;
  private W = 0;
  private H = 0;
  // Geometry in device pixels; the notch hangs from the top edge, centered.
  private CX = 0;
  private NW = 0;
  private NH = 0;
  private R = 0;
  private PT = 1;
  private CELL = 2;
  private outline = new Path2D();
  private body = new Path2D();
  private PATH_LEN = 0;

  constructor(private canvas: HTMLCanvasElement) {
    this.ctx = canvas.getContext("2d")!;
  }

  /** Sizes the canvas and notch. `notchWidth` is in CSS px; the real notch is 185 × 32 pt. */
  layout(width: number, height: number, dpr: number, notchWidth: number) {
    const W = Math.round(width * dpr), H = Math.round(height * dpr);
    if (W !== this.W || H !== this.H) {
      for (const c of [this.canvas, this.off.canvas, this.full.canvas]) { c.width = W; c.height = H; }
      this.W = W;
      this.H = H;
    }
    this.NW = notchWidth * dpr;
    this.NH = (this.NW * 32) / 185;
    this.R = this.NH * (27 / 110);
    this.PT = this.NH / 32;
    this.CX = W / 2;
    this.CELL = Math.max(2, Math.round(2 * this.PT));
    this.low.canvas.width = Math.ceil(W / this.CELL);
    this.low.canvas.height = Math.ceil(H / this.CELL);

    const { CX, NW, NH, R } = this, L = CX - NW / 2, RX = CX + NW / 2;
    const o = new Path2D();
    o.moveTo(L, -20); o.lineTo(L, NH - R); o.arcTo(L, NH, L + R, NH, R);
    o.lineTo(RX - R, NH); o.arcTo(RX, NH, RX, NH - R, R); o.lineTo(RX, -20);
    this.outline = o;
    this.body = new Path2D(o);
    this.body.closePath();
    this.PATH_LEN = 2 * (NH - R + 20) + Math.PI * R + (NW - 2 * R);
  }

  private conic(angle: number, colors: readonly string[], c: CanvasRenderingContext2D) {
    const g = c.createConicGradient(angle - Math.PI / 2, this.CX, this.NH / 2);
    const loop = [...colors, colors[0]];
    loop.forEach((col, i) => g.addColorStop(i / (loop.length - 1), col));
    return g;
  }

  private pointAt(d: number): [number, number] {
    const { NW, NH, R, CX } = this, L = CX - NW / 2, RX = CX + NW / 2;
    const side = NH - R + 20, arc = (Math.PI * R) / 2, bottom = NW - 2 * R;
    d = Math.min(Math.max(d, 0), this.PATH_LEN);
    if (d < side) return [L, -20 + d];
    d -= side;
    if (d < arc) { const a = Math.PI - (d / arc) * (Math.PI / 2); return [L + R + R * Math.cos(a), NH - R + R * Math.sin(a)]; }
    d -= arc;
    if (d < bottom) return [L + R + d, NH];
    d -= bottom;
    if (d < arc) { const a = Math.PI / 2 - (d / arc) * (Math.PI / 2); return [RX - R + R * Math.cos(a), NH - R + R * Math.sin(a)]; }
    d -= arc;
    return [RX, NH - R - d];
  }

  /** Strokes a lit head (fading dashes) onto `c`; `start` is where its tail begins along the outline. */
  private strokeHead(c: CanvasRenderingContext2D, width: number, style: string | CanvasGradient, len: number, start: number, n: number) {
    c.clearRect(0, 0, this.W, this.H);
    c.lineWidth = width; c.lineJoin = "round"; c.strokeStyle = style;
    for (let i = 0; i < n; i++) {
      c.lineCap = i === n - 1 ? "round" : "butt";
      c.setLineDash([len / n + 0.5, this.PATH_LEN * 4]);
      c.lineDashOffset = -(start + (len * i) / n);
      c.globalAlpha = (i + 1) / n;
      c.stroke(this.outline);
    }
    c.setLineDash([]); c.globalAlpha = 1;
  }

  private ditheredHaze(band: { w: number; blur: number }, colors: readonly string[], angle: number, alpha: number, head: { len: number; start: number; n: number } | null) {
    const { low, full, ctx, CELL } = this, W = low.canvas.width, H = low.canvas.height;
    low.setTransform(1, 0, 0, 1, 0, 0); low.clearRect(0, 0, W, H);
    low.setTransform(1 / CELL, 0, 0, 1 / CELL, 0, 0);
    low.filter = `blur(${(band.blur / CELL).toFixed(2)}px)`;
    low.lineWidth = band.w; low.lineJoin = "round"; low.lineCap = "round"; low.strokeStyle = "#fff";
    if (head) {
      for (let i = 0; i < head.n; i++) {
        low.lineCap = i === head.n - 1 ? "round" : "butt";
        low.setLineDash([head.len / head.n + 0.5, this.PATH_LEN * 4]);
        low.lineDashOffset = -(head.start + (head.len * i) / head.n);
        low.globalAlpha = (i + 1) / head.n; low.stroke(this.outline);
      }
      low.setLineDash([]); low.globalAlpha = 1;
    } else {
      low.stroke(this.outline);
    }
    low.filter = "none";
    const img = low.getImageData(0, 0, W, H), px = img.data;
    let peak = 0;
    for (let i = 3; i < px.length; i += 4) peak = Math.max(peak, px[i]);
    if (peak > 0) for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const i = (y * W + x) * 4 + 3, v = (px[i] / peak) * 2, base = Math.floor(v);
      const level = Math.min(base + (v - base > (BAYER8[(y & 7) * 8 + (x & 7)] + 0.5) / 64 ? 1 : 0), 2);
      px[i] = Math.round((level / 2) * 255); px[i - 3] = px[i - 2] = px[i - 1] = 255;
    }
    low.putImageData(img, 0, 0);
    full.globalCompositeOperation = "source-over"; full.clearRect(0, 0, this.W, this.H);
    full.imageSmoothingEnabled = false;
    full.drawImage(low.canvas, 0, 0, W * CELL, H * CELL);
    full.globalCompositeOperation = "source-in"; full.fillStyle = this.conic(angle, colors, full); full.fillRect(0, 0, this.W, this.H);
    ctx.save(); ctx.globalAlpha = alpha; ctx.drawImage(full.canvas, 0, 0); ctx.restore();
  }

  private starPath(x: number, y: number, r: number, spin: number) {
    const c = this.ctx;
    c.beginPath();
    for (let k = 0; k < 4; k++) {
      const a = spin + (k * Math.PI) / 2, b = a + Math.PI / 4;
      const tip = [x + Math.cos(a) * r, y + Math.sin(a) * r], waist = [x + Math.cos(b) * r * 0.16, y + Math.sin(b) * r * 0.16];
      if (k === 0) c.moveTo(tip[0], tip[1]); else c.lineTo(tip[0], tip[1]);
      c.quadraticCurveTo(waist[0], waist[1], x + Math.cos(a + Math.PI / 2) * r, y + Math.sin(a + Math.PI / 2) * r);
    }
    c.closePath();
  }

  private magic(local: number, s: GlowStyle) {
    const { ctx, NW, NH, CX, PATH_LEN } = this, L = CX - NW / 2;
    const cycle = Math.max(s.speed, 1.6), travel = cycle * 0.72, T = s.th * this.PT, colors = s.colors;
    const headAt = (time: number) => {
      if (time < 0) return null;
      const into = time % cycle;
      return into < travel ? easeIO(into / travel) : null;
    };
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    const LIFE = 1.3, N = 140;
    for (let i = 0; i < N; i++) {
      const age = ((i + 0.5) / N) * LIFE + (rand(i) - 0.5) * (LIFE / N);
      const born = local - age, f = headAt(born);
      if (f === null) continue;
      const seed = i * 131 + Math.floor(born / cycle) * 977;
      const [x0, y0] = this.pointAt(f * PATH_LEN);
      const vx = (rand(seed) - 0.5) * 16 * T, vy = (rand(seed + 1) - 0.65) * 12 * T, g = 18 * T;
      const x = x0 + vx * age, y = y0 + vy * age + 0.5 * g * age * age;
      const life = 1 - age / LIFE, twinkle = 0.6 + 0.4 * Math.sin(age * 26 + seed);
      ctx.globalAlpha = Math.max(life, 0) * twinkle;
      ctx.fillStyle = colors[i % colors.length];
      if (i % 3 === 0) { this.starPath(x, y, T * (0.5 + rand(seed + 2) * 0.9) * (0.4 + life * 0.6), age * 5 + seed); ctx.fill(); }
      else { ctx.beginPath(); ctx.arc(x, y, T * 0.22 * (0.4 + life), 0, TAU); ctx.fill(); }
    }
    for (let i = 0; i < 14; i++) {
      const ph = (local * 0.7 + rand(i * 7)) % 1, x = L - 3 * T + rand(i * 7 + 1) * (NW + 6 * T), y = NH + T + rand(i * 7 + 2) * 7 * T + ph * 3 * T;
      ctx.globalAlpha = Math.sin(ph * Math.PI) * 0.8; ctx.fillStyle = colors[i % colors.length];
      this.starPath(x, y, T * 0.55, ph * 3); ctx.fill();
    }
    ctx.restore();
    const f = headAt(local);
    if (f === null) return;
    const len = PATH_LEN * 0.16, end = f * PATH_LEN;
    for (const [w, blur, color, a] of [[2 * T * 2.2, 1.4 * T, colors[0], 0.95], [2 * T * 0.9, 0.15 * T, "#ffffff", 1]] as const) {
      this.strokeHead(this.off, w, color, len, end - len, 16);
      ctx.save(); ctx.filter = `blur(${blur.toFixed(1)}px)`; ctx.globalAlpha = a; ctx.drawImage(this.off.canvas, 0, 0); ctx.restore();
    }
  }

  /** Renders one frame. `local` is seconds since this style was applied (the app restarts on every change). */
  draw(local: number, s: GlowStyle, background: string) {
    const { ctx, W, H, PATH_LEN } = this;
    const ph = local / Math.max(s.speed, 0.2);
    let a1 = 0, a2 = 0, root = 1, haze = 1, second = true, travel: number | null = null;
    switch (s.motion) {
      case "flow": a1 = ph * TAU; a2 = -(ph / 1.7) * TAU; haze = 0.875 - 0.125 * Math.cos(ph * 3 * Math.PI); break;
      case "pulse": a1 = (ph / 4) * TAU; a2 = -(ph / 6.8) * TAU; root = 0.75 - 0.25 * Math.cos(ph * TAU); break;
      case "comet": a1 = ph * TAU * 0.5; travel = ph % 1; second = false; break;
      case "scanner": {
        const u = ph * 2, k = Math.floor(u); let f = u - k; if (k % 2) f = 1 - f;
        travel = 0.5 - 0.5 * Math.cos(Math.PI * f); second = false; break;
      }
      case "blink": { const f = ph % 1; root = f < 0.08 || (f > 0.16 && f < 0.24) ? 1 : 0.35; break; }
      case "solid": break;
    }
    if (s.magic) root *= 0.6;
    const T = s.th * this.PT, I = s.int;
    const g1 = this.conic(a1, s.colors, ctx), g2 = second ? this.conic(a2, [...s.colors].reverse(), ctx) : null;
    const bands = [
      { w: 2 * T * 6 * Math.max(I, 0.2), blur: 4 * T, a: 0.6 * I * haze },
      { w: 2 * T * 2.5, blur: 1.4 * T, a: 0.85 * I },
      { w: 2 * T, blur: 0.15 * T, a: 1 },
    ];
    ctx.globalCompositeOperation = "source-over";
    ctx.fillStyle = background;
    ctx.fillRect(0, 0, W, H);
    ctx.lineJoin = "round";
    bands.forEach((b, bi) => {
      if (bi === 0 && s.dither) {
        const head = travel === null ? null : { len: PATH_LEN * 0.38, start: travel * (PATH_LEN * 1.38) - PATH_LEN * 0.38, n: 24 };
        this.ditheredHaze(b, s.colors, a1, b.a * root * 0.95, head);
        return;
      }
      ctx.save();
      ctx.filter = `blur(${b.blur.toFixed(1)}px)`;
      ctx.lineWidth = b.w;
      ctx.lineCap = "round";
      if (travel !== null) {
        const len = PATH_LEN * 0.38;
        this.strokeHead(this.off, b.w, this.conic(a1, s.colors, this.off), len, travel * (PATH_LEN + len) - len, 24);
        ctx.globalAlpha = b.a * root;
        ctx.drawImage(this.off.canvas, 0, 0);
      } else {
        ctx.globalAlpha = b.a * root; ctx.strokeStyle = g1; ctx.stroke(this.outline);
        if (g2) { ctx.globalAlpha = b.a * root * 0.5; ctx.strokeStyle = g2; ctx.stroke(this.outline); }
      }
      ctx.restore();
    });
    if (s.magic) this.magic(local, s);
    ctx.globalAlpha = 1;
    ctx.fillStyle = "#000";
    ctx.fill(this.body);
  }
}
