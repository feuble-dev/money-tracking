import React from 'react';

/**
 * Flèche tracée à la main + petite note, pour commenter un écran comme on
 * le ferait au stylo sur une capture. Une seule couleur (argile).
 */
export default function Annotation({
  children,
  direction = 'left',
  className = '',
}: {
  children: React.ReactNode;
  /** Côté vers lequel pointe la flèche. */
  direction?: 'left' | 'right' | 'down';
  className?: string;
}) {
  const path =
    direction === 'down'
      ? 'M10 4 C 26 18, 30 34, 22 54 M22 54 l-9 -7 M22 54 l4 -11'
      : 'M70 8 C 52 4, 22 10, 8 30 M8 30 l2 -11 M8 30 l11 -2';
  return (
    <div className={`pointer-events-none flex items-start gap-1 text-clay ${direction === 'right' ? 'flex-row-reverse' : ''} ${className}`} aria-hidden="true">
      <svg
        width="76"
        height="60"
        viewBox="0 0 76 60"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className={direction === 'right' ? '-scale-x-100' : ''}
      >
        <path d={path} />
      </svg>
      <span className="mt-6 max-w-[11rem] font-display text-[15px] font-semibold italic leading-snug">{children}</span>
    </div>
  );
}
