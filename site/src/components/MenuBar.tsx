import { DOWNLOAD, REPO } from "../links";

const link = "rounded-md px-2 py-1.5 transition-colors duration-150 hover:text-ink";

/** The page's own menu bar: the notch hangs from the middle of it. */
export const MenuBar = () => (
  <>
    {/* Scrolled content fades out before it reaches the bar and the notch. */}
    <div className="pointer-events-none fixed inset-x-0 top-0 z-20 h-[calc(var(--notch-h)+2rem)] bg-gradient-to-b from-ground from-35% to-transparent" aria-hidden="true" />
  <nav className="fixed inset-x-0 top-0 z-40 flex items-start justify-between px-3 pt-2 font-mono text-xs text-muted md:px-5 md:pt-3">
    <a href="#top" className="flex items-center gap-2 rounded-md px-2 py-1.5 text-ink" aria-label="Krasnotch home">
      <img src="/favicon.svg" alt="" className="h-3.5 w-auto" />
      <span className="hidden sm:inline">krasnotch</span>
    </a>
    <div className="flex items-center gap-1">
      <a href="#install" className={`${link} hidden sm:inline`}>Install</a>
      <a href={REPO} className={link}>GitHub</a>
      <a href={DOWNLOAD} className={`${link} hidden text-ink sm:inline`}>Download</a>
    </div>
  </nav>
  </>
);
