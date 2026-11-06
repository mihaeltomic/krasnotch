import { useEffect, useRef } from "react";
import { type GlowStyle, NotchGlowRenderer } from "./renderer";

type GlowCanvasProps = {
  config: GlowStyle;
  /** Notch width in CSS px, or as a fraction of the canvas width when below 1. */
  notchWidth: number;
  background?: string;
  className?: string;
};

const prefersReducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/** Draws the app's notch glow. Animates only while on screen and holds a still frame for reduced motion. */
export const GlowCanvas = ({ config, notchWidth, background = "#07080a", className }: GlowCanvasProps) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const state = useRef({ config, notchWidth, background, start: performance.now() });
  const drawRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current!;
    const renderer = new NotchGlowRenderer(canvas);
    const reduced = prefersReducedMotion();
    let frame = 0;
    let visible = false;

    const draw = () => {
      const s = state.current;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
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
    if (s.config !== config) s.start = performance.now(); // the app restarts the animation on every change
    Object.assign(s, { config, notchWidth, background });
    if (prefersReducedMotion()) drawRef.current?.();
  }, [config, notchWidth, background]);

  return <canvas ref={canvasRef} className={className} style={{ background }} aria-hidden="true" />;
};
