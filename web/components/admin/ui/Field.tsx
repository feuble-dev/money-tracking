import React from 'react';

/** Style commun des champs de formulaire de l'admin. */
export const inputCls =
  'h-10 w-full rounded-lg border border-gray-200 bg-white px-3 text-sm text-ink outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/15 disabled:bg-soft';

export default function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-medium text-gray-700">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-xs text-muted">{hint}</span>}
    </label>
  );
}

export function FormError({ children }: { children?: React.ReactNode }) {
  if (!children) return null;
  return <p className="rounded-lg bg-red-50 px-3 py-2.5 text-sm text-red-700">{children}</p>;
}
