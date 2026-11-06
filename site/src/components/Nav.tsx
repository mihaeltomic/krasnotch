import { DOWNLOAD, REPO } from "../links";
import { Button } from "./Button";

const links = [
  { href: "#states", label: "States" },
  { href: "#settings", label: "Settings" },
  { href: "#install", label: "Install" },
  { href: REPO, label: "GitHub" },
];

export const Nav = () => (
  <nav className="fixed inset-x-0 top-4 z-50 flex justify-center px-4">
    <div className="flex w-full max-w-3xl items-center justify-between gap-4 rounded-full bg-[#0c0e11]/70 py-2 pr-2 pl-5 shadow-[inset_0_0_0_1px_rgb(255_255_255/0.08),0_12px_40px_-12px_rgb(0_0_0/0.8)] backdrop-blur-xl">
      <a href="#top" className="shrink-0" aria-label="Krasnotch home">
        <img src="/lockup.svg" alt="" className="h-5 w-auto" />
      </a>
      <div className="hidden items-center gap-1 sm:flex">
        {links.map(({ href, label }) => (
          <a key={label} href={href} className="rounded-full px-3 py-2 text-sm text-muted transition-colors duration-150 hover:text-ink">
            {label}
          </a>
        ))}
      </div>
      <Button href={DOWNLOAD}>Download</Button>
    </div>
  </nav>
);
