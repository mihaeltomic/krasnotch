import type { ReactNode } from "react";

type ButtonProps = { href: string; children: ReactNode; variant?: "primary" | "ghost"; size?: "md" | "lg" };

const sizes = { md: "h-11 px-5 text-sm", lg: "h-14 px-7 text-base" };
const variants = {
  primary: "bg-volt text-ground shadow-[0_0_0_1px_rgb(196_255_58/0.4),0_8px_32px_-8px_rgb(196_255_58/0.5)] hover:bg-[#d4ff6a]",
  ghost: "bg-white/[0.04] text-ink shadow-[inset_0_0_0_1px_rgb(255_255_255/0.12)] hover:bg-white/[0.08]",
};

/** Link styled as a button, with the 0.96 press scale. */
export const Button = ({ href, children, variant = "primary", size = "md" }: ButtonProps) => (
  <a
    href={href}
    className={`inline-flex items-center justify-center gap-2 rounded-full font-medium transition-[scale,background-color] duration-150 ease-out active:scale-[0.96] ${sizes[size]} ${variants[variant]}`}
  >
    {children}
  </a>
);
