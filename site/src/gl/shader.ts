/**
 * Fragment shader for the Krasnotch glow. It mirrors the app: the glow hugs the notch outline
 * (sides and bottom), colors travel along that outline, and each motion mode matches one in the app.
 * Coordinates are device pixels with y up; the notch hangs from the top edge of the canvas.
 */
export const vertexSource = `
attribute vec2 aPos;
void main() { gl_Position = vec4(aPos, 0.0, 1.0); }
`;

export const fragmentSource = `
precision highp float;

uniform vec2 uRes;
uniform float uTime;
uniform float uDpr;
uniform vec3 uNotch;      // width, height, bottom corner radius (CSS px)
uniform vec3 uColors[6];
uniform float uCount;
uniform float uMotion;    // 0 flow, 1 pulse, 2 comet, 3 scanner, 4 blink, 5 solid
uniform float uCycle;
uniform float uThickness;
uniform float uIntensity;
uniform float uDither;
uniform float uMagic;
uniform float uFade;
uniform vec3 uBg;

const float TAU = 6.2831853;

float sdBottomRoundedBox(vec2 p, vec2 b, float r) {
  float rr = p.y > 0.0 ? 0.0 : r;
  vec2 q = abs(p) - b + rr;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rr;
}

vec3 palette(float x) {
  float n = max(uCount, 1.0);
  float s = fract(x) * n;
  float i = floor(s);
  float j = mod(i + 1.0, n);
  vec3 a = uColors[0];
  vec3 b = uColors[0];
  for (int k = 0; k < 6; k++) {
    if (float(k) == i) a = uColors[k];
    if (float(k) == j) b = uColors[k];
  }
  float f = fract(s);
  return mix(a, b, f * f * (3.0 - 2.0 * f));
}

float bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
  vec2 p = gl_FragCoord.xy;
  float px = uDpr;
  float nw = uNotch.x * px;
  float nh = uNotch.y * px;
  float nr = uNotch.z * px;
  vec2 center = vec2(uRes.x * 0.5, uRes.y - nh * 0.5 + 40.0 * px);
  float d = sdBottomRoundedBox(p - center, vec2(nw * 0.5, nh * 0.5 + 40.0 * px), nr);
  float dist = max(d, 0.0) / px;   // distance outside the notch in CSS px

  // Position along the outline: 0 at the top-left, 0.5 at the bottom middle, 1 at the top-right.
  vec2 rel = p - vec2(center.x, uRes.y - nh * 0.55);
  float along = atan(rel.x, -rel.y) / TAU + 0.5;
  float across = clamp((p.x - (center.x - nw * 0.5)) / nw, 0.0, 1.0);

  float t = uTime / max(uCycle, 0.2);
  float mask = 1.0;
  float shift = 0.0;
  if (uMotion < 0.5) {
    shift = -t;
  } else if (uMotion < 1.5) {
    mask = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * TAU));
    shift = -t * 0.15;
  } else if (uMotion < 2.5) {
    float head = fract(t);
    float gap = abs(fract(along - head + 0.5) - 0.5);
    mask = 0.12 + exp(-gap * gap / 0.004);
    shift = -head;
  } else if (uMotion < 3.5) {
    float head = 0.5 + 0.5 * sin(t * TAU * 0.5);
    float gap = across - head;
    mask = 0.1 + exp(-gap * gap / 0.01);
  } else if (uMotion < 4.5) {
    mask = smoothstep(0.42, 0.5, fract(t)) * (1.0 - smoothstep(0.92, 1.0, fract(t)));
  }

  float th = max(uThickness, 0.3) * 2.2;
  float core = exp(-pow(dist / th, 1.5));
  float halo = exp(-dist / (th * 9.0)) * 0.75;
  float bloom = exp(-dist / 70.0) * 0.24;
  float v = (core + (halo + bloom) * uIntensity) * mask * uFade;

  vec3 tint = palette(along * 1.0 + shift);
  if (uDither > 0.5) {
    float cell = 2.0 * px;
    float q = floor(clamp(v, 0.0, 1.0) * 3.0 + bayer8(p / cell)) / 3.0;
    v = q;
  }
  vec3 col = tint * v + vec3(1.0) * core * 0.12 * mask * uFade;

  if (uMagic > 0.5) {
    vec2 cell = floor(p / (5.0 * px));
    float h = hash(cell);
    float twinkle = pow(max(0.0, sin(uTime * 2.6 + h * 60.0)), 24.0) * step(0.9, h);
    float band = exp(-dist / 34.0) * step(0.5, dist);
    float wandHead = fract(uTime / max(uCycle, 1.6));
    float wandGap = abs(fract(along - wandHead + 0.5) - 0.5);
    float wand = exp(-wandGap * wandGap / 0.0015) * exp(-pow(dist / 3.0, 1.4));
    vec3 gold = mix(vec3(1.0, 0.83, 0.43), vec3(1.0, 0.95, 0.75), h);
    col = col * 0.6 + gold * (twinkle * band * 1.6 + wand * 1.2) * uFade;
  }

  float inside = smoothstep(0.5 * px, -0.5 * px, d);
  vec3 outColor = mix(uBg + col, vec3(0.0), inside);
  gl_FragColor = vec4(outColor, 1.0);
}
`;
