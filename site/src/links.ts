import type { GlowStyle } from "./gl/renderer";

export const REPO = "https://github.com/mihaeltomic/krasnotch";
export const DOWNLOAD = `${REPO}/releases/latest/download/Krasnotch.dmg`;
export const RELEASES = `${REPO}/releases/latest`;

export const PALETTES = {
  siri: ["#2EA8FF", "#8E5CFF", "#FF4FA3", "#FF9A3D"],
  ocean: ["#00C6FF", "#0072FF", "#7B61FF"],
  ember: ["#FF9F0A", "#FF375F"],
  mint: ["#30D158", "#7CF5B0"],
  gold: ["#FFD36E", "#FFF1B8", "#FFB347", "#FFE08A"],
  rainbow: ["#FF5F6D", "#FFC371", "#7CF5B0", "#64D2FF", "#8E5CFF", "#FF4FA3"],
  volt: ["#C4FF3A", "#E8FFB0"],
} as const;

/** The app's out-of-the-box look for each agent state (GlowStyle.defaultStyle). */
export const STATES = {
  working: { motion: "flow", colors: PALETTES.siri, speed: 6, th: 4, int: 0.8, dither: false, magic: false },
  needsInput: { motion: "pulse", colors: PALETTES.ember, speed: 1.4, th: 5, int: 0.9, dither: false, magic: false },
  done: { motion: "solid", colors: PALETTES.mint, speed: 2, th: 4, int: 0.7, dither: false, magic: false },
} satisfies Record<string, GlowStyle>;

export type StateKey = keyof typeof STATES;
export const BASE_GLOW: GlowStyle = STATES.working;
