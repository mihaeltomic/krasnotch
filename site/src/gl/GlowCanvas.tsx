import { useEffect, useRef } from "react";
import { type GlowStyle, NotchGlowRenderer } from "./renderer";

type GlowCanvasProps = {
  config: GlowStyle;
  /** Notch width in CSS px, or as a fraction of the canvas width when below 1. */
  notchWidth: number;
  /** A CSS color, or "transparent" to let the page show through. */
  background?: string;
  /** Caps the backing resolution; the glow is soft, so large canvases can render at 1x. */
  maxDpr?: number;
  className?: string;
};

const prefersReducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/** Draws the app's notch glow. Animates only while on screen and holds a still frame for reduced motion. */
export const GlowCanvas = ({ config, notchWidth, background = "#07080a", maxDpr = 2, className }: GlowCanvasProps) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const state = useRef({ config, notchWidth, background, maxDpr, start: performance.now() });
  const drawRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current!;
    const renderer = new NotchGlowRenderer(canvas);
    const reduced = prefersReducedMotion();
    let frame = 0;
    let visible = false;

    const draw = () => {
      const s = state.current;
      const dpr = Math.min(window.devicePixelRatio || 1, s.maxDpr);
      const notch = s.notchWidth < 1 ? canvas.clientWidth * s.notchWidth : s.notchWidth;
      renderer.layout(canvas.clientWidth, canvas.clientHeight, dpr, notch);
      const local = reduced ? 1.2 : (performance.now() - s.start) / 1000;
      renderer.draw(local, s.config, s.background);
      if (visible && !reduced) frame = requestAnimationFrame(draw);
    };
    drawRef.current = draw;

    const observer = new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      cancelAnimationFrame(frame);
      if (visible) frame = requestAnimationFrame(draw);
    });
    observer.observe(canvas);
    // A running loop picks up the new size itself; only redraw when idle.
    const resize = new ResizeObserver(() => {
      if (!visible || reduced) draw();
    });
    resize.observe(canvas);

    return () => {
      observer.disconnect();
      resize.disconnect();
      cancelAnimationFrame(frame);
      drawRef.current = null;
    };
  }, []);

  useEffect(() => {
    const s = state.current;
    // The app restarts the animation when the look changes; size and brightness tweaks keep it running.
    const restyled = s.config.motion !== config.motion || s.config.magic !== config.magic || s.config.speed !== config.speed;
    if (restyled) s.start = performance.now();
    Object.assign(s, { config, notchWidth, background, maxDpr });
    if (prefersReducedMotion()) drawRef.current?.();
  }, [config, notchWidth, background, maxDpr]);

  return <canvas ref={canvasRef} className={className} style={{ background }} aria-hidden="true" />;
};
