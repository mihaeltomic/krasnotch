import type { StateKey } from "../links";

const lines: Record<StateKey, { text: string; tone?: "muted" | "accent" | "warn" | "ok" }[]> = {
  working: [
    { text: "> refactor the session tracker and add tests", tone: "muted" },
    { text: "Read Sources/KrasnotchKit/SessionTracker.swift" },
    { text: "Edit SessionTracker.swift  +18 -6" },
    { text: "Running swift test…", tone: "accent" },
  ],
  needsInput: [
    { text: "> refactor the session tracker and add tests", tone: "muted" },
    { text: "Edit SessionTracker.swift  +18 -6" },
    { text: "Allow Bash(swift test --parallel)?", tone: "warn" },
    { text: "1. Yes   2. Yes, always   3. No", tone: "muted" },
  ],
  done: [
    { text: "> refactor the session tracker and add tests", tone: "muted" },
    { text: "Edit SessionTracker.swift  +18 -6" },
    { text: "36 tests passed", tone: "ok" },
    { text: "Done. Sessions are capped at 64.", tone: "ok" },
  ],
};

const tones = { muted: "text-white/40", accent: "text-[#8E5CFF]", warn: "text-[#FF9F0A]", ok: "text-[#30D158]" };

/** A small Claude Code transcript that matches what the notch is showing. */
export const Terminal = ({ state }: { state: StateKey }) => (
  <div className="w-full max-w-md overflow-hidden rounded-[10px] bg-[#0d0f12]/90 shadow-[0_0_0_1px_rgb(255_255_255/0.08),0_24px_60px_-20px_rgb(0_0_0/0.9)] backdrop-blur">
    <div className="flex items-center gap-1.5 border-b border-white/[0.06] px-3.5 py-2.5">
      {["#ff5f57", "#febc2e", "#28c840"].map((c) => (
        <span key={c} className="size-2.5 rounded-full opacity-80" style={{ background: c }} />
      ))}
      <span className="ml-2 font-mono text-[11px] text-white/40">claude — krasnotch</span>
    </div>
    <div className="space-y-1.5 p-4 font-mono text-[12px] leading-5">
      {lines[state].map((line) => (
        <p key={line.text} className={`truncate ${line.tone ? tones[line.tone] : "text-white/75"}`}>
          {line.text}
        </p>
      ))}
    </div>
  </div>
);
