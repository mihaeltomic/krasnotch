import type { GlowConfig } from "./gl/glow";

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

const base: GlowConfig = { colors: PALETTES.siri, motion: "flow", cycle: 2.4, thickness: 1.3, intensity: 0.85, dither: false, magic: false };

/** The app's out-of-the-box look for each agent state. */
export const STATES = {
  working: base,
  needsInput: { ...base, colors: PALETTES.ember, motion: "pulse", cycle: 1.1 },
  done: { ...base, colors: PALETTES.mint, motion: "solid" },
} satisfies Record<string, GlowConfig>;

export type StateKey = keyof typeof STATES;
export { base as BASE_GLOW };
