import { GlowPill, IconPill } from "./Pill";

const card = "group relative overflow-hidden rounded-[20px] bg-surface p-3 shadow-[inset_0_0_0_1px_rgb(255_255_255/0.07)]";

const privacy = [
  ["Krasnotch/", "0700"],
  ["events.sock", "0600"],
  ["peer uid", "checked"],
];

export const Bento = () => (
  <section className="px-6 pb-32 md:pb-48">
    <div className="mx-auto max-w-7xl">
      <h2 className="max-w-5xl font-display text-[clamp(2.25rem,4.4vw,4rem)] leading-[1.05] font-semibold tracking-[-0.03em] text-balance">
        Look up <GlowPill />, click the block <IconPill /> and you're back in the right tab.
      </h2>

      <div className="mt-16 grid grid-flow-dense grid-cols-1 gap-3 md:grid-cols-6">
        <article className={`${card} flex flex-col md:col-span-4 md:row-span-2`}>
          <div className="flex-1 overflow-hidden rounded-[8px] bg-black shadow-[0_0_0_1px_rgb(255_255_255/0.1)]">
            <video className="block aspect-video size-full object-cover transition-[scale] duration-700 ease-out group-hover:scale-105" src="/krasnotch.mp4" poster="/poster.jpg" autoPlay muted loop playsInline preload="metadata" aria-label="Krasnotch demo film" />
          </div>
          <div className="px-3 pt-5 pb-3">
            <h3 className="font-medium">Click the notch, land in the right tab</h3>
            <p className="mt-1.5 max-w-xl text-sm leading-relaxed text-muted">It follows the agent's process back to Terminal, iTerm2, VS Code, Cursor or the exact T3 Code thread.</p>
          </div>
        </article>

        <article className={`${card} flex flex-col md:col-span-2`}>
          <div className="flex flex-1 flex-col justify-between gap-8 rounded-[8px] bg-ground p-5 shadow-[0_0_0_1px_rgb(255_255_255/0.06)]">
            <div>
              <span className="block font-display text-7xl leading-none font-semibold tracking-[-0.05em] text-volt tabular-nums">0</span>
              <span className="mt-3 block font-mono text-xs text-muted">network connections, ever</span>
            </div>
            <div className="font-mono text-[12px] leading-7">
              {privacy.map(([key, value]) => (
                <div key={key} className="flex justify-between gap-4 border-t border-white/[0.06]">
                  <span className="truncate text-muted">{key}</span>
                  <span className="text-volt">{value}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="px-3 pt-8 pb-3">
            <h3 className="font-medium">Private by design</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-muted">Events arrive over a socket only your user can open. Browsers, other accounts and other machines can't reach it, and the app never touches the network.</p>
          </div>
        </article>

        <article className={`${card} md:col-span-2`}>
          <pre className="overflow-x-auto rounded-[8px] bg-ground p-5 font-mono text-[12px] leading-6 text-muted shadow-[0_0_0_1px_rgb(255_255_255/0.06)]">
            <code>{`curl --unix-socket \\\n  "$HOME/…/Krasnotch/events.sock" \\\n  "http://localhost/state?\\\n  session=build&value=working"`}</code>
          </pre>
          <div className="px-3 pt-5 pb-3">
            <h3 className="font-medium">Any agent, any script</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-muted">Long builds and test runs can light the notch too.</p>
          </div>
        </article>

        <article className={`${card} md:col-span-6`}>
          <div className="flex flex-col gap-6 rounded-[8px] bg-ground p-6 shadow-[0_0_0_1px_rgb(255_255_255/0.06)] md:flex-row md:items-end md:justify-between md:p-8">
            <span className="font-display text-7xl leading-none font-semibold tracking-[-0.045em] text-volt tabular-nums md:text-8xl">&lt;1 MB</span>
            <div className="max-w-md md:text-right">
              <h3 className="font-medium">Native and tiny</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-muted">Swift and Core Animation in one universal binary for Apple silicon and Intel, with no dependencies.</p>
            </div>
          </div>
        </article>
      </div>
    </div>
  </section>
);
