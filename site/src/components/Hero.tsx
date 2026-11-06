import { DOWNLOAD, REPO, STATES } from "../links";
import { Notch } from "./Notch";

export const Hero = () => (
  <header className="relative overflow-hidden">
    <div className="flex justify-center">
      <Notch colors={[...STATES.working.colors]} motion="flow" width={300} blur={22} />
    </div>

    <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 pt-6">
      <img src="/lockup.svg" alt="Krasnotch" className="h-6 w-auto" />
      <a href={REPO} className="text-sm text-muted transition-colors hover:text-ink">
        GitHub
      </a>
    </nav>

    <div className="mx-auto max-w-4xl px-6 pt-24 pb-16 text-center sm:pt-32">
      <p className="font-mono text-xs tracking-[0.2em] text-volt uppercase">Free · Open source · macOS 15+</p>
      <h1 className="mt-6 font-display text-5xl leading-[1.02] font-semibold tracking-[-0.03em] text-balance sm:text-7xl">
        Your notch knows when your agent needs you.
      </h1>
      <p className="mx-auto mt-6 max-w-2xl text-lg text-pretty text-muted">
        Krasnotch lights up the MacBook notch while Claude Code works, changes its glow when it needs your
        input, and takes you back to the right tab with one click.
      </p>
      <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
        <a
          href={DOWNLOAD}
          className="inline-flex h-12 items-center gap-2 bg-volt px-6 font-medium text-ground transition-transform hover:-translate-y-0.5 active:translate-y-0"
        >
          Download for Mac
        </a>
        <a
          href={REPO}
          className="inline-flex h-12 items-center border border-line px-6 font-medium text-ink transition-colors hover:border-muted"
        >
          View source
        </a>
      </div>
      <p className="mt-4 text-xs text-muted">Universal app for Apple silicon and Intel · under 1 MB</p>
    </div>
  </header>
);
