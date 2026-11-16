import { useCallback, useEffect, useState } from "react";
import { Controls } from "./components/Controls";
import { Footer } from "./components/Footer";
import { Hero } from "./components/Hero";
import { Install } from "./components/Install";
import { MenuBar } from "./components/MenuBar";
import { Notch } from "./components/Notch";
import type { GlowStyle } from "./gl/renderer";
import { STATES, STATE_COPY, STATE_ORDER, type StateKey } from "./links";

const isTyping = (target: EventTarget | null) => target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement;

export const App = () => {
  const [state, setState] = useState<StateKey>("working");
  const [styles, setStyles] = useState<Record<StateKey, GlowStyle>>(STATES);
  // The page plays through the three states on its own until the visitor takes over.
  const [auto, setAuto] = useState(true);
  const style = styles[state];

  const pickState = useCallback((next: StateKey) => {
    setAuto(false);
    setState(next);
  }, []);

  const patchStyle = useCallback(
    (patch: Partial<GlowStyle>) => {
      setAuto(false);
      setStyles((all) => ({ ...all, [state]: { ...all[state], ...patch } }));
    },
    [state],
  );

  useEffect(() => {
    if (!auto) return;
    const timer = window.setTimeout(
      () => setState((s) => STATE_ORDER[(STATE_ORDER.indexOf(s) + 1) % STATE_ORDER.length]),
      STATE_COPY[state].ms,
    );
    return () => window.clearTimeout(timer);
  }, [auto, state]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.metaKey || event.ctrlKey || event.altKey || isTyping(event.target)) return;
      const index = ["1", "2", "3"].indexOf(event.key);
      if (index >= 0) pickState(STATE_ORDER[index]);
      if (event.key === "d") patchStyle({ dither: !style.dither });
      if (event.key === "m") patchStyle({ magic: !style.magic });
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [pickState, patchStyle, style.dither, style.magic]);

  useEffect(() => {
    document.documentElement.style.setProperty("--accent", style.colors[0]);
  }, [style.colors]);

  return (
    <>
      <MenuBar />
      <Notch state={state} style={style} onReturn={() => pickState("working")} />
      <main>
        <Hero>
          <Controls state={state} style={style} onState={pickState} onStyle={patchStyle} />
        </Hero>
        <Install />
      </main>
      <Footer />
    </>
  );
};
