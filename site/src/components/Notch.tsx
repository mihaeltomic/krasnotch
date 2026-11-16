import { useEffect, useRef, useState } from "react";
import { GlowCanvas } from "../gl/GlowCanvas";
import type { GlowStyle } from "../gl/renderer";
import { STATE_COPY, type StateKey } from "../links";

type NotchProps = { state: StateKey; style: GlowStyle; onReturn: () => void };

const measure = () => Math.round(Math.min(600, Math.max(210, window.innerWidth * 0.38)));

/** Notch width in CSS px, kept in step with the viewport and mirrored to CSS as --notch-h. */
const useNotchWidth = () => {
  const [width, setWidth] = useState(measure);
  useEffect(() => {
    const onResize = () => setWidth(measure());
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);
  useEffect(() => {
    document.documentElement.style.setProperty("--notch-h", `${(width * 32) / 185}px`);
  }, [width]);
  return width;
};

/**
 * The page's notch, fixed to the top edge like the real one. It glows with the current state,
 * its eyes follow the pointer, and clicking it plays the app's jump back to the agent.
 */
export const Notch = ({ state, style, onReturn }: NotchProps) => {
  const width = useNotchWidth();
  const height = (width * 32) / 185;
  const eyes = useRef<HTMLSpanElement>(null);
  const [returned, setReturned] = useState(false);

  useEffect(() => {
    const onMove = (event: PointerEvent) => {
      const dx = (event.clientX - window.innerWidth / 2) / (window.innerWidth / 2);
      const dy = Math.min(event.clientY / window.innerHeight, 1);
      eyes.current?.style.setProperty("translate", `${dx * width * 0.16}px ${(dy - 0.3) * height * 0.22}px`);
    };
    window.addEventListener("pointermove", onMove);
    return () => window.removeEventListener("pointermove", onMove);
  }, [width, height]);

  useEffect(() => {
    if (!returned) return;
    const timer = window.setTimeout(() => {
      setReturned(false);
      onReturn();
    }, 1700);
    return () => window.clearTimeout(timer);
  }, [returned, onReturn]);

  const pill = returned ? "Back in Terminal, tab 2" : STATE_COPY[state].pill;
  const eye = height * 0.24;

  return (
    <>
      <div className="notch-fade pointer-events-none fixed inset-x-0 top-0 z-30" style={{ height: Math.max(width * 0.95, 300) }}>
        <GlowCanvas config={style} notchWidth={width} background="transparent" maxDpr={1} className="block size-full" />
      </div>
      <button
        type="button"
        onClick={() => setReturned(true)}
        aria-label="Notch. Click to jump back to the agent's terminal tab."
        className="fixed top-0 left-1/2 z-40 -translate-x-1/2 cursor-pointer bg-black"
        style={{ width, height, borderRadius: `0 0 ${height * 0.245}px ${height * 0.245}px` }}
      >
        <span ref={eyes} className="absolute inset-0 flex items-center justify-center transition-[translate] duration-200 ease-out" style={{ gap: eye * 0.85 }}>
          <span className="eye bg-ink" style={{ width: eye, height: eye }} />
          <span className="eye bg-ink" style={{ width: eye, height: eye }} />
        </span>
      </button>
      <div className="pointer-events-none fixed inset-x-0 z-40 flex justify-center" style={{ top: height + 12 }} aria-live="polite">
        <button
          type="button"
          onClick={() => setReturned(true)}
          tabIndex={pill ? 0 : -1}
          className={`flex items-center gap-2 rounded-full bg-black px-3.5 py-2 text-[13px] font-semibold shadow-[inset_0_0_0_1px_rgb(255_255_255/0.14),0_10px_30px_-8px_rgb(0_0_0/0.8)] transition-[opacity,translate,scale] duration-300 ease-[cubic-bezier(0.2,0,0,1)] active:scale-[0.96] ${pill ? "pointer-events-auto opacity-100" : "-translate-y-2 opacity-0"}`}
        >
          <span className="size-2 rounded-full bg-(--accent)" />
          {pill || "Back in Terminal, tab 2"}
          {!returned && <span className="font-normal text-muted">click to return</span>}
        </button>
      </div>
    </>
  );
};
