import { DOWNLOAD, RELEASES } from "../links";

const steps = [
  { title: "Download", text: "Open the DMG and drag Krasnotch to Applications." },
  { title: "Open", text: "The first time, right-click Krasnotch and choose Open." },
  { title: "Connect", text: "Choose Connect Claude Code from the menu bar. Your other hooks stay untouched." },
];

export const Install = () => (
  <section className="mx-auto max-w-6xl px-6 py-28">
    <h2 className="font-display text-4xl font-semibold tracking-[-0.02em]">Set up in a minute.</h2>
    <ol className="mt-12 grid gap-10 sm:grid-cols-3">
      {steps.map(({ title, text }, index) => (
        <li key={title} className="border-t border-line pt-6">
          <span className="font-mono text-sm text-volt">0{index + 1}</span>
          <h3 className="mt-3 font-medium">{title}</h3>
          <p className="mt-2 text-sm text-muted">{text}</p>
        </li>
      ))}
    </ol>
    <div className="mt-14 flex flex-wrap items-center gap-x-6 gap-y-3">
      <a href={DOWNLOAD} className="inline-flex h-12 items-center bg-volt px-6 font-medium text-ground">
        Download Krasnotch
      </a>
      <a href={RELEASES} className="text-sm text-muted underline-offset-4 hover:text-ink hover:underline">
        All releases and checksums
      </a>
    </div>
  </section>
);
