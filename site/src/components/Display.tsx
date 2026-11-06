import { useEffect, useState } from "react";
import { GlowCanvas } from "../gl/GlowCanvas";
import { STATES, type StateKey } from "../links";
import { Terminal } from "./Terminal";

const sequence: { key: StateKey; label: string; ms: number; dot: string }[] = [
  { key: "working", label: "Claude is working", ms: 5200, dot: "#8E5CFF" },
  { key: "needsInput", label: "Claude needs your input", ms: 3600, dot: "#FF9F0A" },
  { key: "done", label: "Done", ms: 2600, dot: "#30D158" },
];


/** A MacBook display edge whose notch cycles through the three agent states. */
export const Display = () => {
  const [index, setIndex] = useState(0);
  const step = sequence[index];

  useEffect(() => {
    const timer = window.setTimeout(() => setIndex((i) => (i + 1) % sequence.length), step.ms);
    return () => window.clearTimeout(timer);
  }, [step.ms]);

  return (
    <div className="relative rounded-[28px] bg-[#1a1d22] p-3 shadow-[inset_0_0_0_1px_rgb(255_255_255/0.08),0_40px_120px_-30px_rgb(0_0_0/0.9)]">
      <div className="relative overflow-hidden rounded-[16px] shadow-[0_0_0_1px_rgb(255_255_255/0.06)]">
        <GlowCanvas config={STATES[step.key]} notchWidth={236} className="block aspect-[16/10] w-full" />
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(70%_60%_at_50%_120%,rgb(142_92_255/0.16),transparent)]" />
        <div className="absolute inset-x-0 top-[28%] flex justify-center px-6">
          <Terminal state={step.key} />
        </div>
        <div className="absolute bottom-5 left-5 flex items-center gap-2.5 rounded-full bg-white/[0.06] px-3.5 py-2 text-sm shadow-[inset_0_0_0_1px_rgb(255_255_255/0.08)] backdrop-blur" aria-live="polite">
          <span className="size-2 rounded-full transition-[background-color] duration-300" style={{ background: step.dot }} />
          {step.label}
        </div>
      </div>
    </div>
  );
};
