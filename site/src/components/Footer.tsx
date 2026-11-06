import { REPO } from "../links";

export const Footer = () => (
  <footer className="border-t border-line">
    <div className="mx-auto flex max-w-6xl flex-col gap-4 px-6 py-10 text-sm text-muted sm:flex-row sm:items-center sm:justify-between">
      <p>Krasnotch, from krasnoća (Croatian for beauty) plus notch. MIT licensed.</p>
      <div className="flex gap-6">
        <a href={REPO} className="hover:text-ink">GitHub</a>
        <a href={`${REPO}/issues`} className="hover:text-ink">Issues</a>
      </div>
    </div>
  </footer>
);
