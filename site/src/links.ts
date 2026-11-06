export const REPO = "https://github.com/mihaeltomic/krasnotch";
export const DOWNLOAD = `${REPO}/releases/latest/download/Krasnotch.dmg`;
export const RELEASES = `${REPO}/releases/latest`;

/** Default glow per agent state, matching the app's out-of-the-box settings. */
export const STATES = {
  working: { colors: ["#2EA8FF", "#8E5CFF", "#FF4FA3", "#FF9A3D"], motion: "flow" },
  needsInput: { colors: ["#FF9F0A", "#FF375F"], motion: "pulse" },
  done: { colors: ["#30D158", "#7CF5B0"], motion: "solid" },
} as const;
