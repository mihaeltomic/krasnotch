import { useEffect, useRef } from "react";
import { type GlowConfig, GlowRenderer, type NotchSize } from "./glow";

type GlowCanvasProps = {
  config: GlowConfig;
  notch: NotchSize;
  background?: string;
  className?: string;
};

const prefersReducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/** A canvas that draws the notch glow. It renders only while on screen, and holds still for reduced motion. */
export const GlowCanvas = ({ config, notch, background = "#07080a", className }: GlowCanvasProps) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rendererRef = useRef<GlowRenderer | null>(null);
  const drawRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current!;
    let renderer: GlowRenderer;
    try {
      renderer = new GlowRenderer(canvas, config, notch, background);
    } catch {
      return; // No WebGL: the dark canvas background stays, which reads as a sleeping notch.
    }
    rendererRef.current = renderer;
    let frame = 0;
    let visible = false;
    const start = performance.now();
    const reduced = prefersReducedMotion();

    const draw = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      const width = Math.round(canvas.clientWidth * dpr);
      const height = Math.round(canvas.clientHeight * dpr);
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }
      renderer.render(reduced ? 0.8 : (performance.now() - start) / 1000, width, height, dpr);
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
      rendererRef.current = null;
      drawRef.current = null;
    };
    // The renderer is created once; config changes go through transitionTo below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const renderer = rendererRef.current;
    if (!renderer || renderer.config === config) return;
    if (prefersReducedMotion()) {
      renderer.config = config;
      drawRef.current?.();
    } else {
      renderer.transitionTo(config);
    }
  }, [config]);

  useEffect(() => {
    if (rendererRef.current) rendererRef.current.notch = notch;
  }, [notch]);

  return <canvas ref={canvasRef} className={className} style={{ background }} aria-hidden="true" />;
};
