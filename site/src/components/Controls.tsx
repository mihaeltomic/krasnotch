import type { ReactNode } from "react";
import type { GlowStyle } from "../gl/renderer";
import { MOTIONS, PALETTES, type PaletteKey, STATES, STATE_COPY, STATE_ORDER, type StateKey } from "../links";

type ControlsProps = {
  state: StateKey;
  style: GlowStyle;
  onState: (state: StateKey) => void;
  onStyle: (patch: Partial<GlowStyle>) => void;
};

const chip = (on: boolean) =>
  `h-9 rounded-full px-3.5 text-sm transition-[background-color,color,scale] duration-150 ease-out active:scale-[0.96] ${
    on ? "bg-ink text-ground" : "bg-white/[0.05] text-ink/80 hover:bg-white/[0.1] hover:text-ink"
  }`;

const gradient = (colors: readonly string[]) => `conic-gradient(from 210deg, ${[...colors, colors[0]].join(", ")})`;

const Row = ({ label, children }: { label: string; children: ReactNode }) => (
  <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-4">
    <span className="w-14 shrink-0 font-mono text-[11px] tracking-wide text-muted uppercase">{label}</span>
    <div className="flex min-w-0 flex-1 flex-wrap items-center gap-1.5">{children}</div>
  </div>
);

const Key = ({ children }: { children: ReactNode }) => (
  <kbd className="rounded-[5px] px-1.5 py-0.5 font-mono text-[10px] text-muted shadow-[inset_0_0_0_1px_rgb(255_255_255/0.14)]">{children}</kbd>
);

/** The app's settings, working on the page: pick a state, then restyle the notch above. */
export const Controls = ({ state, style, onState, onStyle }: ControlsProps) => {
  const palette = (Object.keys(PALETTES) as PaletteKey[]).find((key) => PALETTES[key] === style.colors);

  return (
    <section aria-label="Try it" className="rounded-[24px] bg-white/[0.03] shadow-[inset_0_0_0_1px_rgb(255_255_255/0.08)] backdrop-blur-sm">
      <div className="grid md:grid-cols-[1fr_1.25fr]">
        <div className="flex flex-col gap-4 p-5 md:p-7">
          <div className="grid grid-cols-3 gap-1.5">
            {STATE_ORDER.map((key, i) => {
              const on = key === state;
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => onState(key)}
                  aria-pressed={on}
                  className={`flex h-[4.5rem] flex-col justify-between rounded-2xl p-3 text-left transition-[background-color,scale,box-shadow] duration-150 ease-out active:scale-[0.96] ${
                    on ? "bg-white/[0.1] shadow-[inset_0_0_0_1px_rgb(255_255_255/0.22)]" : "bg-white/[0.04] hover:bg-white/[0.07]"
                  }`}
                >
                  <span className="flex items-center justify-between">
                    <span className="size-3 rounded-full" style={{ background: gradient(STATES[key].colors) }} />
                    <span className="hidden md:inline"><Key>{i + 1}</Key></span>
                  </span>
                  <span className="text-sm font-medium">{STATE_COPY[key].title}</span>
                </button>
              );
            })}
          </div>
          <p className="min-h-[2.75rem] text-[15px] leading-snug text-pretty text-ink/75" aria-live="polite">
            {STATE_COPY[state].line}
          </p>
        </div>

        <div className="flex flex-col gap-3.5 border-t border-white/[0.07] p-5 md:border-t-0 md:border-l md:p-7">
          <Row label="Motion">
            {MOTIONS.map(({ key, label, speed }) => (
              <button key={key} type="button" aria-pressed={style.motion === key} onClick={() => onStyle({ motion: key, speed })} className={chip(style.motion === key)}>
                {label}
              </button>
            ))}
          </Row>
          <Row label="Colors">
            {(Object.keys(PALETTES) as PaletteKey[]).map((key) => (
              <button
                key={key}
                type="button"
                aria-label={key}
                aria-pressed={palette === key}
                onClick={() => onStyle({ colors: PALETTES[key] })}
                className={`grid size-9 place-items-center rounded-full transition-[scale,box-shadow] duration-150 ease-out active:scale-[0.96] ${
                  palette === key ? "shadow-[inset_0_0_0_2px_var(--color-ink)]" : "hover:shadow-[inset_0_0_0_1px_rgb(255_255_255/0.3)]"
                }`}
              >
                <span className="size-5 rounded-full" style={{ background: gradient(PALETTES[key]) }} />
              </button>
            ))}
          </Row>
          <Row label="Size">
            <input type="range" aria-label="Thickness" min={2} max={8} step={0.5} value={style.th} onChange={(e) => onStyle({ th: Number(e.target.value) })} className="slider min-w-0 flex-1" />
            <span className="w-12 text-right font-mono text-xs text-muted tabular-nums">{style.th} pt</span>
          </Row>
          <Row label="Glow">
            <input type="range" aria-label="Intensity" min={0.3} max={1} step={0.05} value={style.int} onChange={(e) => onStyle({ int: Number(e.target.value) })} className="slider min-w-0 flex-1" />
            <span className="w-12 text-right font-mono text-xs text-muted tabular-nums">{Math.round(style.int * 100)}%</span>
          </Row>
          <Row label="Finish">
            <button type="button" aria-pressed={style.dither} onClick={() => onStyle({ dither: !style.dither })} className={chip(style.dither)}>Dither</button>
            <button type="button" aria-pressed={style.magic} onClick={() => onStyle({ magic: !style.magic })} className={chip(style.magic)}>Magic?</button>
            <span className="ml-auto hidden items-center gap-1.5 font-mono text-[11px] text-muted lg:flex">
              <Key>D</Key><Key>M</Key> or click the notch
            </span>
          </Row>
        </div>
      </div>
    </section>
  );
};
