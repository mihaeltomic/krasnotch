const features = [
  {
    title: "Click the notch, land in the right tab",
    text: "Krasnotch follows the agent's process back to Terminal, iTerm2, VS Code, Cursor or the exact T3 Code thread, and brings it forward.",
  },
  {
    title: "Every setting, live",
    text: "Flow, pulse, comet, scanner, blink or solid. Pick palettes, thickness, intensity, a dithered look, or Magic? glitter, separately for each state.",
  },
  {
    title: "Private by design",
    text: "No network at all. Events arrive over a Unix socket only your user can open, so browsers, other accounts and other machines can't reach it.",
  },
  {
    title: "Not just Claude Code",
    text: "Anything that can run curl can light the notch: other agents, build scripts, long test runs.",
  },
];

const example = `curl --unix-socket "$HOME/Library/Application Support/Krasnotch/events.sock" \\
  "http://localhost/state?session=build&value=working"`;

export const Features = () => (
  <section className="border-y border-line bg-surface">
    <div className="mx-auto grid max-w-6xl gap-16 px-6 py-28 lg:grid-cols-[1fr_1.1fr]">
      <div className="min-w-0">
        <h2 className="font-display text-4xl font-semibold tracking-[-0.02em]">Small app. Sharp details.</h2>
        <pre className="mt-10 overflow-x-auto border border-line bg-ground p-5 font-mono text-[13px] leading-relaxed text-muted">
          <code>{example}</code>
        </pre>
      </div>
      <dl className="grid gap-10 sm:grid-cols-2">
        {features.map(({ title, text }) => (
          <div key={title}>
            <dt className="font-medium">
              <span className="mr-2 inline-block size-2 bg-volt align-middle" aria-hidden="true" />
              {title}
            </dt>
            <dd className="mt-2 text-sm leading-relaxed text-muted">{text}</dd>
          </div>
        ))}
      </dl>
    </div>
  </section>
);
