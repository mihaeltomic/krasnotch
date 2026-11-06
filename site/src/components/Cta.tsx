import { DOWNLOAD, RELEASES } from "../links";
import { Button } from "./Button";

const steps = [
  "Open the DMG and drag Krasnotch to Applications.",
  "The first time, right-click Krasnotch and choose Open.",
  "Pick Connect Claude Code in the menu bar. Your other hooks stay untouched.",
];

export const Cta = () => (
  <section id="install" className="relative overflow-hidden px-6 py-32 md:py-48">
    <div className="pointer-events-none absolute inset-x-0 bottom-0 h-[70%] bg-[radial-gradient(60%_60%_at_50%_100%,rgb(196_255_58/0.14),transparent)]" />
    <div className="relative mx-auto max-w-7xl">
      <h2 className="max-w-6xl font-display text-[clamp(3.5rem,9vw,9rem)] leading-[0.92] font-semibold tracking-[-0.045em]">
        Light up your notch.
      </h2>
      <div className="mt-14 flex flex-wrap items-center gap-3">
        <Button href={DOWNLOAD} size="lg">Download for Mac</Button>
        <Button href={RELEASES} size="lg" variant="ghost">Releases and checksums</Button>
      </div>
      <ol className="mt-24 grid gap-10 border-t border-white/[0.08] pt-10 md:grid-cols-3">
        {steps.map((text, i) => (
          <li key={text} className="flex gap-4 text-muted">
            <span className="font-mono text-sm text-volt tabular-nums">{i + 1}</span>
            <span className="leading-relaxed">{text}</span>
          </li>
        ))}
      </ol>
    </div>
  </section>
);
