const hosts = ["Claude Code", "Terminal", "iTerm2", "VS Code", "Cursor", "T3 Code", "Any script with curl"];

/** Hosts Krasnotch can take you back to, as a slow, endless row of type. */
export const Marquee = () => (
  <section className="overflow-hidden border-y border-white/[0.06] py-10" aria-label="Works with">
    <div className="flex w-max animate-[marquee_40s_linear_infinite] motion-reduce:animate-none">
      {[0, 1].map((copy) => (
        <ul key={copy} className="flex shrink-0 items-center" aria-hidden={copy === 1}>
          {hosts.map((host) => (
            <li key={host} className="flex items-center font-display text-[clamp(2rem,4vw,3.5rem)] font-semibold tracking-[-0.03em] text-white/80">
              <span className="px-8">{host}</span>
              <span className="size-3 bg-volt" aria-hidden="true" />
            </li>
          ))}
        </ul>
      ))}
    </div>
  </section>
);
