import { DOWNLOAD, REPO } from "../links";
import { Button } from "./Button";

const steps = ["Open the DMG and drag Krasnotch to Applications.", "Choose Connect Claude Code from its menu bar icon.", "Run claude. Watch the notch."];

const facts = [
  { title: "No network", text: "Events arrive on a private Unix socket. Nothing leaves your Mac." },
  { title: "Your hooks stay", text: "It adds its own to settings.json and keeps a backup." },
  { title: "Any agent", text: "One curl call reports a state, from any script." },
];

export const Install = () => (
  <section id="install" className="px-4 py-24 md:px-6 md:py-36">
    <div className="mx-auto grid max-w-5xl gap-14 md:grid-cols-2 md:gap-20">
      <div className="min-w-0">
        <h2 className="font-display text-5xl font-semibold tracking-[-0.035em] md:text-7xl">Install</h2>
        <ol className="mt-10 flex flex-col gap-4">
          {steps.map((step, i) => (
            <li key={step} className="flex gap-4 text-lg text-pretty text-ink/85">
              <span className="pt-1 font-mono text-xs text-muted tabular-nums">0{i + 1}</span>
              {step}
            </li>
          ))}
        </ol>
        <div className="mt-10 flex flex-wrap items-center gap-3">
          <Button href={DOWNLOAD} size="lg">Download .dmg</Button>
          <Button href={REPO} size="lg" variant="ghost">Source on GitHub</Button>
        </div>
        <p className="mt-5 max-w-sm text-sm text-pretty text-muted">
          Not notarized yet. The first time, right-click Krasnotch in Applications and choose Open.
        </p>
      </div>
      <dl className="flex min-w-0 flex-col self-end">
        {facts.map(({ title, text }) => (
          <div key={title} className="border-t border-white/[0.08] py-5">
            <dt className="font-medium">{title}</dt>
            <dd className="mt-1 text-pretty text-muted">{text}</dd>
          </div>
        ))}
        <pre className="min-w-0 overflow-x-auto rounded-xl bg-white/[0.04] p-4 font-mono text-xs leading-relaxed text-ink/80 shadow-[inset_0_0_0_1px_rgb(255_255_255/0.07)]">
          {`curl --unix-socket "$HOME/Library/Application Support/Krasnotch/events.sock" \\\n  "http://localhost/state?session=me&value=working"`}
        </pre>
      </dl>
    </div>
  </section>
);
