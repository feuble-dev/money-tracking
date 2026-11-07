import React from 'react';

/**
 * Cadre de téléphone pour les écrans de l'application reproduits en HTML
 * (jamais de capture floue : le texte reste net et traduisible).
 */
export default function PhoneFrame({
  children,
  className = '',
  width = 270,
  height = 540,
  tilt = 0,
}: {
  children: React.ReactNode;
  className?: string;
  width?: number;
  height?: number;
  /** Légère rotation en degrés, pour composer plusieurs écrans. */
  tilt?: number;
}) {
  return (
    <div
      className={`relative ${className}`}
      style={{ width, transform: tilt ? `rotate(${tilt}deg)` : undefined }}
      aria-hidden="true"
    >
      <div className="rounded-[2.4rem] bg-[#0E1621] p-2.5 shadow-[0_28px_70px_-24px_rgba(11,37,69,0.55)] ring-1 ring-black/10">
        <div className="relative flex flex-col overflow-hidden rounded-[1.9rem] bg-[#F5F7FA]" style={{ height }}>
          <div className="flex items-center justify-between bg-primary px-5 pb-1.5 pt-2.5 text-[9px] font-medium text-white/80">
            <span>09:41</span>
            <span className="h-3.5 w-16 rounded-full bg-black/40" />
            <span>4G</span>
          </div>
          {children}
        </div>
      </div>
    </div>
  );
}

/** Barre de titre bleue d'un écran de l'app. */
export function AppBar({ title, children }: { title: string; children?: React.ReactNode }) {
  return (
    <div className="bg-primary px-4 pb-4 pt-2 text-white">
      <p className="font-display text-[13px] font-semibold">{title}</p>
      {children}
    </div>
  );
}

export const fcfa = (n: number) => `${Math.round(n).toLocaleString('fr-FR')} FCFA`;
