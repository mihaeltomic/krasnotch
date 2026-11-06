import type { CSSProperties } from "react";


type Motion = "flow" | "pulse" | "solid";

type NotchProps = {
  colors: string[];
  motion: Motion;
  /** Notch width in px; height follows the MacBook proportions. */
  width?: number;
  blur?: number;
};

/** A MacBook notch with the glow Krasnotch draws around it. */
export const Notch = ({ colors, motion, width = 220, blur = 14 }: NotchProps) => {
  const glow = [...colors, colors[0]].join(", ");
  const height = Math.round(width * 0.17);

  return (
    <div className="relative" style={{ width, height }} aria-hidden="true">
      <div
        className={`notch-glow ${motion}`}
        style={{ "--glow": glow, "--blur": `${blur}px` } as CSSProperties}
      />
      <div className="absolute inset-0 rounded-b-[18px] bg-black" />
    </div>
  );
};
