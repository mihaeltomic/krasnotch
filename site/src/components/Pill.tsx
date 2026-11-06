import { GlowCanvas } from "../gl/GlowCanvas";
import { STATES } from "../links";

const notch = { width: 44, height: 9, radius: 4 };

/** A tiny live notch, sized to sit inside a line of display type. */
export const GlowPill = () => (
  <span className="mx-[0.15em] inline-block h-[0.82em] w-[2.3em] overflow-hidden rounded-full align-[-0.08em] shadow-[0_0_0_1px_rgb(255_255_255/0.12)]">
    <GlowCanvas config={STATES.working} notch={notch} className="block size-full" />
  </span>
);

export const IconPill = () => (
  <span className="mx-[0.15em] inline-flex h-[0.82em] w-[1.6em] items-center justify-center rounded-full bg-volt align-[-0.08em]">
    <span className="flex gap-[0.09em] pl-[0.25em]">
      <span className="size-[0.13em] bg-ground" />
      <span className="size-[0.13em] bg-ground" />
    </span>
  </span>
);
