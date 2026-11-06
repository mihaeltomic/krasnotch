import { DOWNLOAD, REPO } from "../links";
import { gsap, useGSAP } from "../gsap";
import { Button } from "./Button";
import { Display } from "./Display";
import { useRef } from "react";

export const Hero = () => {
  const ref = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      gsap.from("[data-hero-chunk]", { y: 24, opacity: 0, duration: 0.8, ease: "power3.out", stagger: 0.1 });
      gsap.from("[data-hero-display]", { y: 80, opacity: 0, duration: 1.2, ease: "power3.out", delay: 0.35 });
    },
    { scope: ref },
  );

  return (
    <header id="top" ref={ref} className="relative px-6 pt-40 md:pt-52">
      <div className="mx-auto max-w-7xl">
        <div className="relative z-10">
          <h1 data-hero-chunk className="max-w-6xl font-display text-[clamp(3rem,6vw,6rem)] leading-[0.98] font-semibold tracking-[-0.035em] text-balance">
            Your notch knows when your agent needs you.
          </h1>
          <div className="mt-10 flex max-w-xl flex-col gap-8">
            <p data-hero-chunk className="text-lg leading-relaxed text-pretty text-muted md:text-xl">
              Krasnotch lights up the MacBook notch while Claude Code works, shifts its glow the moment it needs
              you, and takes you back to the right tab in one click.
            </p>
            <div data-hero-chunk className="flex flex-wrap items-center gap-3">
              <Button href={DOWNLOAD} size="lg">Download for Mac</Button>
              <Button href={REPO} size="lg" variant="ghost">Read the source</Button>
            </div>
            <p data-hero-chunk className="text-sm text-muted">Free and open source. macOS 15 or later, Apple silicon and Intel.</p>
          </div>
        </div>
        <div data-hero-display className="relative -mt-4 ml-auto w-full max-w-4xl md:-mt-24 lg:w-[68%]">
          <Display />
        </div>
      </div>
    </header>
  );
};
