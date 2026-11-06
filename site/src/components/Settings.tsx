import { useMemo, useRef, useState } from "react";
import { GlowCanvas } from "../gl/GlowCanvas";
import type { GlowStyle } from "../gl/renderer";
import { BASE_GLOW, PALETTES } from "../links";
import { ScrollTrigger, gsap, useGSAP } from "../gsap";

const steps: { title: string; text: string; config: Partial<GlowStyle>; readout: string }[] = [
  { title: "Flow", text: "The default: your palette streams around the notch outline.", config: {}, readout: "Flow · Siri · 6 s" },
  { title: "Comet", text: "A bright head chases its tail around the edge.", config: { motion: "comet", colors: PALETTES.ocean, speed: 2 }, readout: "Comet · Ocean · 2 s" },
  { title: "Ping-pong", text: "Sweeps from side to side, like a status light thinking.", config: { motion: "scanner", colors: PALETTES.mint, speed: 2.4 }, readout: "Ping-pong · Mint · 2.4 s" },
  { title: "Thickness and intensity", text: "Go from a hairline to a full halo.", config: { colors: PALETTES.rainbow, speed: 3, th: 8, int: 1 }, readout: "Flow · Rainbow · 8 pt" },
  { title: "Dithered glow", text: "An ordered-dither finish with crisp pixel steps.", config: { colors: PALETTES.siri, speed: 4, th: 6, dither: true }, readout: "Flow · Siri · dithered" },
  { title: "Magic?", text: "A golden wand arcs around the notch and sheds glitter.", config: { colors: PALETTES.gold, speed: 2.2, th: 5, int: 1, magic: true }, readout: "Flow · Gold · Magic?" },
];


/** The glow stays pinned on the left and changes as each setting scrolls past on the right. */
export const Settings = () => {
  const ref = useRef<HTMLElement>(null);
  const [index, setIndex] = useState(0);
  const configs = useMemo(() => steps.map((step) => ({ ...BASE_GLOW, ...step.config })), []);

  useGSAP(
    () => {
      gsap.utils.toArray<HTMLElement>("[data-step]").forEach((el, i) => {
        // Each step owns the space down to the next one, so exactly one step is active at a time.
        const next = el.nextElementSibling as HTMLElement | null;
        ScrollTrigger.create({
          trigger: el,
          start: "top 60%",
          end: () => (next ? `+=${next.offsetTop - el.offsetTop}` : "bottom top"),
          onToggle: (self) => self.isActive && setIndex(i),
        });
      });
      gsap.matchMedia().add("(min-width: 1024px)", () => {
        ScrollTrigger.create({ trigger: "[data-steps]", start: "top 15%", end: "bottom 85%", pin: "[data-pinned]", pinSpacing: false });
      });
    },
    { scope: ref },
  );

  return (
    <section id="settings" ref={ref} className="px-6 py-32 md:py-48">
      <div className="mx-auto grid max-w-7xl gap-12 lg:grid-cols-[1.15fr_1fr] lg:gap-20">
        <div data-pinned className="sticky top-20 z-10 self-start lg:static">
          <h2 className="font-display text-[clamp(2.25rem,4.4vw,4rem)] leading-[1.05] font-semibold tracking-[-0.03em]">Every setting, live.</h2>
          <div className="mt-10 overflow-hidden rounded-[20px] bg-[#1a1d22] p-3 shadow-[inset_0_0_0_1px_rgb(255_255_255/0.08)]">
            <div className="relative overflow-hidden rounded-[8px]">
              <GlowCanvas config={configs[index]} notchWidth={250} className="block aspect-[16/10] w-full" />
              <span className="absolute bottom-4 left-4 rounded-full bg-white/[0.06] px-3 py-1.5 font-mono text-xs text-ink shadow-[inset_0_0_0_1px_rgb(255_255_255/0.08)]">
                {steps[index].readout}
              </span>
            </div>
          </div>
        </div>
        <ol data-steps className="flex flex-col gap-[28vh] pt-[8vh] pb-[20vh] lg:pt-[30vh]">
          {steps.map((step, i) => (
            <li key={step.title} data-step className={`transition-[opacity] duration-300 ${i === index ? "opacity-100" : "opacity-35"}`}>
              <h3 className="font-display text-3xl font-semibold tracking-[-0.02em]">{step.title}</h3>
              <p className="mt-3 max-w-md text-lg leading-relaxed text-muted">{step.text}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
};
