import { useRef } from "react";
import { gsap, useGSAP } from "../gsap";

const text =
  "Agents run for minutes now. You drift to a browser, a doc, a chat, and miss the moment they stop to ask. Krasnotch puts the answer where your eyes already go: the top of the screen.";

/** Words brighten one by one as the paragraph scrolls through the viewport. */
export const Manifesto = () => {
  const ref = useRef<HTMLParagraphElement>(null);

  useGSAP(
    () => {
      gsap.fromTo(
        "[data-word]",
        { opacity: 0.1 },
        { opacity: 1, ease: "none", stagger: 0.1, scrollTrigger: { trigger: ref.current, start: "top 78%", end: "bottom 45%", scrub: true } },
      );
    },
    { scope: ref },
  );

  return (
    <section className="px-6 py-32 md:py-48">
      <p ref={ref} className="mx-auto max-w-5xl font-display text-[clamp(1.75rem,3.6vw,3.25rem)] leading-[1.15] font-medium tracking-[-0.02em] text-balance">
        {text.split(" ").map((word, i) => (
          <span key={i} data-word className="inline-block opacity-10 motion-reduce:opacity-100">
            {word}&nbsp;
          </span>
        ))}
      </p>
    </section>
  );
};
