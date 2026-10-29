import React from 'react';

export default function Card({
  title,
  subtitle,
  action,
  children,
  className = '',
  padded = true,
}: {
  title?: string;
  subtitle?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
  padded?: boolean;
}) {
  return (
    <section className={`rounded-2xl border border-gray-200/80 bg-white ${className}`}>
      {(title || action) && (
        <header className="flex items-start justify-between gap-4 px-5 pb-1 pt-5">
          <div>
            {title && <h3 className="font-display text-[15px] font-semibold text-ink">{title}</h3>}
            {subtitle && <p className="mt-0.5 text-xs text-muted">{subtitle}</p>}
          </div>
          {action}
        </header>
      )}
      <div className={padded ? 'p-5' : ''}>{children}</div>
    </section>
  );
}
