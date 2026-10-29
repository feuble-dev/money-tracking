'use client';

import React, { useState } from 'react';
import Icon from '@/components/site/Icon';

/** Valeur à transmettre au client (clé, jeton) avec un bouton Copier. */
export default function CopyField({ label, value }: { label: string; value: string }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      /* presse-papiers indisponible (http) : la valeur reste sélectionnable */
    }
  };
  return (
    <div>
      <p className="mb-1.5 text-xs font-medium text-muted">{label}</p>
      <div className="flex items-stretch overflow-hidden rounded-lg border border-gray-200 bg-soft">
        <code className="min-w-0 flex-1 select-all break-all px-3 py-2.5 font-mono text-[13px] text-ink">{value}</code>
        <button
          type="button"
          onClick={copy}
          className={`flex flex-shrink-0 items-center gap-1.5 border-l border-gray-200 px-3 text-xs font-semibold transition-colors ${
            copied ? 'bg-emerald-50 text-emerald-700' : 'bg-white text-gray-600 hover:text-ink'
          }`}
        >
          <Icon name={copied ? 'check' : 'copy'} className="h-3.5 w-3.5" strokeWidth={2} />
          {copied ? 'Copié' : 'Copier'}
        </button>
      </div>
    </div>
  );
}
