import { GlowCanvas } from "../gl/GlowCanvas";
import { STATES } from "../links";

// At heading size the notch is tiny, so the glow needs more weight to read.
const pillGlow = { ...STATES.working, speed: 4, th: 10, int: 1 };

/**
 * Inline media for display headings, sized to the cap height and set on the baseline
 * so they sit level with the letters.
 */
export const GlowPill = () => (
  <span className="mr-[0.06em] ml-[0.14em] inline-block h-[0.72em] w-[2.1em] overflow-hidden rounded-[0.14em] align-baseline shadow-[0_0_0_1px_rgb(255_255_255/0.12)]">
    <GlowCanvas config={pillGlow} notchWidth={0.46} className="block size-full" />
  </span>
);

export const BlockPill = () => (
  <img src="/favicon.svg" alt="" className="mx-[0.12em] inline-block h-[0.56em] w-auto align-[0.07em]" />
);
