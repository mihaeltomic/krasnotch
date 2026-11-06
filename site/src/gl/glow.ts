import { fragmentSource, vertexSource } from "./shader";

export type Motion = "flow" | "pulse" | "comet" | "scanner" | "blink" | "solid";

export type GlowConfig = {
  colors: readonly string[];
  motion: Motion;
  cycle: number;
  thickness: number;
  intensity: number;
  dither: boolean;
  magic: boolean;
};

export type NotchSize = { width: number; height: number; radius: number };

const MOTIONS: Motion[] = ["flow", "pulse", "comet", "scanner", "blink", "solid"];

const hexToRgb = (hex: string): [number, number, number] => {
  const n = parseInt(hex.replace("#", ""), 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
};

const compile = (gl: WebGLRenderingContext, type: number, source: string) => {
  const shader = gl.createShader(type)!;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader) ?? "shader");
  return shader;
};

/** Owns one WebGL context and draws the glow; the caller drives frames. */
export class GlowRenderer {
  private gl: WebGLRenderingContext;
  private uniforms: Record<string, WebGLUniformLocation | null> = {};
  private fade = 1;
  private fadeTarget = 1;
  private pending: GlowConfig | null = null;
  config: GlowConfig;
  notch: NotchSize;
  background: [number, number, number];

  constructor(canvas: HTMLCanvasElement, config: GlowConfig, notch: NotchSize, background: string) {
    const gl = canvas.getContext("webgl", { antialias: false, premultipliedAlpha: false, powerPreference: "low-power" });
    if (!gl) throw new Error("WebGL unavailable");
    this.gl = gl;
    this.config = config;
    this.notch = notch;
    this.background = hexToRgb(background);

    const program = gl.createProgram()!;
    gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, vertexSource));
    gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, fragmentSource));
    gl.linkProgram(program);
    gl.useProgram(program);

    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    const position = gl.getAttribLocation(program, "aPos");
    gl.enableVertexAttribArray(position);
    gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

    for (const name of ["uRes", "uTime", "uDpr", "uNotch", "uColors", "uCount", "uMotion", "uCycle", "uThickness", "uIntensity", "uDither", "uMagic", "uFade", "uBg"]) {
      this.uniforms[name] = gl.getUniformLocation(program, name);
    }
  }

  /** Swaps to a new look with a short fade through dark, like the app does between states. */
  transitionTo(config: GlowConfig) {
    this.pending = config;
    this.fadeTarget = 0;
  }

  render(time: number, width: number, height: number, dpr: number) {
    const { gl, uniforms: u } = this;
    this.fade += (this.fadeTarget - this.fade) * 0.18;
    if (this.pending && this.fade < 0.04) {
      this.config = this.pending;
      this.pending = null;
      this.fadeTarget = 1;
    }
    const c = this.config;
    const colors = new Float32Array(18);
    c.colors.slice(0, 6).forEach((hex, i) => colors.set(hexToRgb(hex), i * 3));

    gl.viewport(0, 0, width, height);
    gl.uniform2f(u.uRes, width, height);
    gl.uniform1f(u.uTime, time);
    gl.uniform1f(u.uDpr, dpr);
    gl.uniform3f(u.uNotch, this.notch.width, this.notch.height, this.notch.radius);
    gl.uniform3fv(u.uColors, colors);
    gl.uniform1f(u.uCount, Math.min(c.colors.length, 6));
    gl.uniform1f(u.uMotion, MOTIONS.indexOf(c.motion));
    gl.uniform1f(u.uCycle, c.cycle);
    gl.uniform1f(u.uThickness, c.thickness);
    gl.uniform1f(u.uIntensity, c.intensity);
    gl.uniform1f(u.uDither, c.dither ? 1 : 0);
    gl.uniform1f(u.uMagic, c.magic ? 1 : 0);
    gl.uniform1f(u.uFade, this.fade);
    gl.uniform3f(u.uBg, ...this.background);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }
}
