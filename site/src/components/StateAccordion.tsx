import { useState } from "react";
import { GlowCanvas } from "../gl/GlowCanvas";
import { STATES, type StateKey } from "../links";

const slices: { key: StateKey; title: string; text: string }[] = [
  { key: "working", title: "Working", text: "Colors flow around the notch while the agent thinks, edits and runs tools." },
  { key: "needsInput", title: "Needs you", text: "A warm pulse when it asks a question or waits on a permission prompt." },
  { key: "done", title: "Done", text: "A calm green glow when it finishes, then the notch goes dark again." },
];


/** Three vertical slices; the active one widens to show its glow and explanation. */
export const StateAccordion = () => {
  const [active, setActive] = useState<StateKey>("working");

  return (
    <section id="states" className="px-6 py-32 md:py-48">
      <div className="mx-auto max-w-7xl">
        <h2 className="max-w-4xl font-display text-[clamp(2.25rem,4.4vw,4rem)] leading-[1.05] font-semibold tracking-[-0.03em] text-balance">
          Three states you can read from across the room.
        </h2>
        <div className="mt-16 flex flex-col gap-3 md:h-[26rem] md:flex-row">
          {slices.map(({ key, title, text }) => {
            const isActive = key === active;
            return (
              <button
                key={key}
                type="button"
                onMouseEnter={() => setActive(key)}
                onFocus={() => setActive(key)}
                onClick={() => setActive(key)}
                aria-pressed={isActive}
                className={`group relative h-72 overflow-hidden rounded-[20px] text-left shadow-[inset_0_0_0_1px_rgb(255_255_255/0.07)] transition-[flex-grow] duration-500 ease-[cubic-bezier(0.2,0,0,1)] md:h-auto ${isActive ? "md:grow-[2.6]" : "md:grow"} md:basis-0`}
              >
                <GlowCanvas config={STATES[key]} notchWidth={190} className="absolute inset-0 size-full" />
                <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-[#07080a] via-[#07080a]/80 to-transparent p-7 pt-24">
                  <h3 className="font-display text-2xl font-semibold tracking-[-0.02em]">{title}</h3>
                  <p className={`mt-2 max-w-sm text-sm leading-relaxed text-muted transition-[opacity] duration-300 ${isActive ? "opacity-100" : "md:opacity-0"}`}>{text}</p>
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </section>
  );
};
