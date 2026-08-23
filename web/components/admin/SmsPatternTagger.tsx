'use client';

import React, { useRef, useState } from 'react';

export interface TaggedZone {
  start: number;
  end: number;
  fieldName: string;
}

const FIELD_NAMES = [
  'montant',
  'numero_client',
  'operator_transaction_id',
  'operator_reference',
  'solde',
  'nom_client',
];

interface SmsPatternTaggerProps {
  rawExample: string;
  zones: TaggedZone[];
  onZonesChange: (zones: TaggedZone[]) => void;
}

/**
 * Tag des zones d'un SMS exemple par sélection de texte (start/end/fieldName).
 * Ne génère jamais de regex côté web (D2) — c'est le mobile qui compile en
 * RegExp Dart à la synchronisation, via SmsPatternBuilder.buildRegex().
 */
export default function SmsPatternTagger({ rawExample, zones, onZonesChange }: SmsPatternTaggerProps) {
  const textRef = useRef<HTMLDivElement>(null);
  const [pendingField, setPendingField] = useState(FIELD_NAMES[0]);

  const handleTag = () => {
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0 || !textRef.current) return;
    const range = selection.getRangeAt(0);
    if (!textRef.current.contains(range.commonAncestorContainer)) return;

    const selected = range.toString();
    if (!selected) return;

    const preRange = document.createRange();
    preRange.selectNodeContents(textRef.current);
    preRange.setEnd(range.startContainer, range.startOffset);
    const start = preRange.toString().length;
    const end = start + selected.length;

    onZonesChange([...zones, { start, end, fieldName: pendingField }]);
    selection.removeAllRanges();
  };

  const removeZone = (idx: number) => {
    onZonesChange(zones.filter((_, i) => i !== idx));
  };

  const renderHighlighted = () => {
    if (!rawExample) return null;
    if (zones.length === 0) return rawExample;
    const sorted = [...zones].sort((a, b) => a.start - b.start);
    const parts: React.ReactNode[] = [];
    let cursor = 0;
    sorted.forEach((z, i) => {
      if (z.start > cursor) parts.push(rawExample.slice(cursor, z.start));
      parts.push(
        <mark key={i} className="bg-accent-50 text-accent px-0.5 rounded font-semibold" title={z.fieldName}>
          {rawExample.slice(z.start, z.end)}
        </mark>
      );
      cursor = Math.max(cursor, z.end);
    });
    if (cursor < rawExample.length) parts.push(rawExample.slice(cursor));
    return parts;
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2">
        <select
          value={pendingField}
          onChange={(e) => setPendingField(e.target.value)}
          className="px-3 py-2 border border-gray-200 rounded-lg text-sm bg-white"
        >
          {FIELD_NAMES.map((f) => (
            <option key={f} value={f}>{f}</option>
          ))}
        </select>
        <button
          type="button"
          onClick={handleTag}
          className="px-3 py-2 text-sm font-medium text-accent bg-accent-50 rounded-lg hover:bg-accent-50/70 transition-colors"
        >
          Taguer la sélection
        </button>
      </div>
      <p className="text-xs text-gray-400">Sélectionnez une portion du texte ci-dessous, puis cliquez sur &quot;Taguer la sélection&quot;.</p>
      <div ref={textRef} className="p-4 bg-soft rounded-xl text-sm font-mono leading-relaxed select-text">
        {renderHighlighted()}
      </div>
      {zones.length > 0 && (
        <ul className="space-y-1">
          {zones.map((z, i) => (
            <li key={i} className="flex items-center justify-between text-xs bg-white border border-gray-100 rounded-lg px-3 py-2">
              <span><strong>{z.fieldName}</strong> — &quot;{rawExample.slice(z.start, z.end)}&quot;</span>
              <button type="button" onClick={() => removeZone(i)} className="text-red-500 hover:text-red-700">
                Retirer
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
