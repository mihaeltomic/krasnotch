import type { ReactNode } from "react";
import { DOWNLOAD } from "../links";
import { Button } from "./Button";

/** One screen: the wordmark, one line, the download, and the controls that drive the notch above. */
export const Hero = ({ children }: { children: ReactNode }) => (
  <header id="top" className="flex min-h-svh flex-col items-center justify-center px-4 pt-[calc(var(--notch-h)+3rem)] pb-10 md:px-6">
    <h1 className="rise font-display text-[clamp(4.25rem,17.5vw,17rem)] leading-[0.82] font-semibold tracking-[-0.045em] select-none">
      krasnotch
    </h1>
    <p className="rise mt-6 max-w-xl text-center text-xl text-pretty text-ink/85 [animation-delay:80ms] md:mt-8 md:text-2xl">
      Your notch knows when your agent needs you.
    </p>
    <div className="rise mt-7 flex flex-col items-center gap-3 [animation-delay:160ms] sm:flex-row sm:gap-5">
      <Button href={DOWNLOAD} size="lg">Download for Mac</Button>
      <p className="font-mono text-xs text-muted">Free · open source · macOS 15+</p>
    </div>
    <div className="rise mt-12 w-full max-w-5xl [animation-delay:240ms] md:mt-14">{children}</div>
  </header>
);
