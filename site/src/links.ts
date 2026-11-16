import type { GlowStyle, Motion } from "./gl/renderer";

export const REPO = "https://github.com/mihaeltomic/krasnotch";
export const DOWNLOAD = `${REPO}/releases/latest/download/Krasnotch.dmg`;

export const PALETTES = {
  siri: ["#2EA8FF", "#8E5CFF", "#FF4FA3", "#FF9A3D"],
  ocean: ["#00C6FF", "#0072FF", "#7B61FF"],
  ember: ["#FF9F0A", "#FF375F"],
  mint: ["#30D158", "#7CF5B0"],
  gold: ["#FFD36E", "#FFF1B8", "#FFB347", "#FFE08A"],
  rainbow: ["#FF5F6D", "#FFC371", "#7CF5B0", "#64D2FF", "#8E5CFF", "#FF4FA3"],
  volt: ["#C4FF3A", "#E8FFB0"],
} as const;

export type PaletteKey = keyof typeof PALETTES;

/** The app's out-of-the-box look for each agent state (GlowStyle.defaultStyle). */
export const STATES = {
  working: { motion: "flow", colors: PALETTES.siri, speed: 6, th: 4, int: 0.8, dither: false, magic: false },
  needsInput: { motion: "pulse", colors: PALETTES.ember, speed: 1.4, th: 5, int: 0.9, dither: false, magic: false },
  done: { motion: "solid", colors: PALETTES.mint, speed: 2, th: 4, int: 0.7, dither: false, magic: false },
} satisfies Record<string, GlowStyle>;

export type StateKey = keyof typeof STATES;

export const STATE_COPY: Record<StateKey, { title: string; line: string; pill: string; ms: number }> = {
  working: { title: "Working", line: "Claude is thinking, editing and running tools. The notch flows.", pill: "", ms: 5200 },
  needsInput: { title: "Needs you", line: "A question or a permission prompt. The notch pulses until you look.", pill: "Allow swift test?", ms: 3800 },
  done: { title: "Done", line: "Finished. A calm glow, then the notch goes dark again.", pill: "Done · 41 tests passed", ms: 3000 },
};

export const STATE_ORDER: StateKey[] = ["working", "needsInput", "done"];

/** Each animation with the cycle length it reads best at. */
export const MOTIONS: { key: Motion; label: string; speed: number }[] = [
  { key: "flow", label: "Flow", speed: 6 },
  { key: "pulse", label: "Pulse", speed: 1.4 },
  { key: "comet", label: "Comet", speed: 2 },
  { key: "scanner", label: "Ping-pong", speed: 2.4 },
  { key: "blink", label: "Blink", speed: 1.6 },
  { key: "solid", label: "Solid", speed: 2 },
];
