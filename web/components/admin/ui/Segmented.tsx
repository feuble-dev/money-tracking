'use client';

import React from 'react';

export default function Segmented<T extends string | number>({
  value,
  options,
  onChange,
}: {
  value: T;
  options: { value: T; label: string }[];
  onChange: (v: T) => void;
}) {
  return (
    <div className="inline-flex rounded-lg border border-gray-200 bg-white p-0.5 text-sm">
      {options.map((o) => (
        <button
          key={String(o.value)}
          onClick={() => onChange(o.value)}
          className={`rounded-md px-3 py-1.5 font-medium transition-colors ${
            value === o.value ? 'bg-ink text-white' : 'text-muted hover:text-ink'
          }`}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
