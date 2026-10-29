import React from 'react';

/** En-tête des pages intérieures. */
export default function PageHeader({
  eyebrow,
  title,
  text,
  children,
}: {
  eyebrow: string;
  title: string;
  text?: string;
  children?: React.ReactNode;
}) {
  return (
    <section className="relative overflow-hidden bg-soft">
      <div className="bg-grid absolute inset-0 [mask-image:linear-gradient(to_bottom,black,transparent)]" />
      <div className="fade-up relative mx-auto max-w-6xl px-4 pb-16 pt-14 sm:px-6 sm:pt-20">
        <p className="text-sm font-semibold text-primary">{eyebrow}</p>
        <h1 className="mt-3 max-w-3xl font-display text-4xl font-bold leading-tight tracking-tight text-ink sm:text-5xl">
          {title}
        </h1>
        {text && <p className="mt-5 max-w-2xl text-lg leading-relaxed text-muted">{text}</p>}
        {children}
      </div>
    </section>
  );
}
