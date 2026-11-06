import { REPO } from "../links";

export const Footer = () => (
  <footer className="border-t border-white/[0.06] px-6">
    <div className="mx-auto flex max-w-7xl flex-col gap-6 py-10 text-sm text-muted sm:flex-row sm:items-center sm:justify-between">
      <div className="flex items-center gap-4">
        <img src="/lockup.svg" alt="Krasnotch" className="h-4 w-auto opacity-80" />
        <span>From krasnoća, Croatian for beauty, plus notch. MIT licensed.</span>
      </div>
      <div className="flex gap-6">
        <a href={REPO} className="transition-colors duration-150 hover:text-ink">GitHub</a>
        <a href={`${REPO}/issues`} className="transition-colors duration-150 hover:text-ink">Issues</a>
        <a href={`${REPO}/security`} className="transition-colors duration-150 hover:text-ink">Security</a>
      </div>
    </div>
  </footer>
);
