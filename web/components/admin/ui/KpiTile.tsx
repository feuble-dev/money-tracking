import React from 'react';
import Sparkline from '../charts/Sparkline';

/** Indicateur clé : valeur, variation vs période précédente, mini-courbe. */
export default function KpiTile({
  label,
  value,
  delta,
  hint,
  trend,
  color = '#1565C0',
  href,
}: {
  label: string;
  value: React.ReactNode;
  delta?: number | null;
  hint?: string;
  trend?: number[];
  color?: string;
  href?: string;
}) {
  const body = (
    <>
      <div className="flex items-start justify-between gap-3">
        <p className="text-xs font-medium text-muted">{label}</p>
        {trend && <Sparkline values={trend} color={color} width={72} height={24} />}
      </div>
      {/* Montant sur une seule ligne, jamais coupé : la taille s'adapte. */}
      <p className="mt-2 whitespace-nowrap font-display text-[clamp(1.25rem,1.6vw,1.6rem)] font-bold tabular-nums tracking-tight text-ink">
        {value}
      </p>
      <p className="mt-2 flex items-center gap-1.5 text-xs">
        {delta !== undefined && delta !== null && (
          <span
            className={`rounded-md px-1.5 py-0.5 font-semibold ${
              delta >= 0 ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'
            }`}
          >
            {delta >= 0 ? '+' : ''}
            {delta} %
          </span>
        )}
        {hint && <span className="text-muted">{hint}</span>}
      </p>
    </>
  );
  const cls = 'block rounded-2xl border border-gray-200/80 bg-white p-5 transition-colors';
  return href ? (
    <a href={href} className={`${cls} hover:border-primary/30`}>
      {body}
    </a>
  ) : (
    <div className={cls}>{body}</div>
  );
}
