import { REPO } from "../links";

export const Footer = () => (
  <footer className="px-4 md:px-6">
    <div className="mx-auto flex max-w-5xl flex-col gap-3 border-t border-white/[0.08] py-8 font-mono text-xs text-muted sm:flex-row sm:items-center sm:justify-between">
      <span>krasnoća (Croatian: beauty) + notch</span>
      <div className="flex gap-5">
        <a href={REPO} className="transition-colors duration-150 hover:text-ink">GitHub</a>
        <a href={`${REPO}/issues`} className="transition-colors duration-150 hover:text-ink">Issues</a>
        <span>MIT</span>
      </div>
    </div>
  </footer>
);
