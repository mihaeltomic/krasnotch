import { STATES } from "../links";
import { Notch } from "./Notch";

const items = [
  { key: "working", title: "Working", text: "A flowing glow while the agent thinks, edits and runs tools." },
  { key: "needsInput", title: "Needs you", text: "A pulse when it asks a question or waits for a permission." },
  { key: "done", title: "Done", text: "A short green glow when it finishes, then the notch goes dark." },
] as const;

export const States = () => (
  <section className="mx-auto max-w-6xl px-6 py-28">
    <h2 className="max-w-xl font-display text-4xl font-semibold tracking-[-0.02em]">Glance up. Know where it's at.</h2>
    <div className="mt-12 grid gap-px border border-line bg-line sm:grid-cols-3">
      {items.map(({ key, title, text }) => (
        <div key={key} className="bg-ground p-8">
          <div className="flex h-28 items-start justify-center pt-2">
            <Notch colors={[...STATES[key].colors]} motion={STATES[key].motion} width={160} blur={11} />
          </div>
          <h3 className="mt-4 font-medium">{title}</h3>
          <p className="mt-2 text-sm text-muted">{text}</p>
        </div>
      ))}
    </div>
  </section>
);
