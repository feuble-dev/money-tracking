import React from 'react';

export interface Slice {
  label: string;
  value: number;
  color: string;
}

/** Anneau de répartition avec légende ; total au centre. */
export default function Donut({
  slices,
  size = 132,
  thickness = 16,
  center,
}: {
  slices: Slice[];
  size?: number;
  thickness?: number;
  center?: React.ReactNode;
}) {
  const total = slices.reduce((s, x) => s + x.value, 0);
  const r = (size - thickness) / 2;
  const c = 2 * Math.PI * r;
  let offset = 0;
  return (
    <div className="flex items-center gap-6">
      <div className="relative flex-shrink-0" style={{ width: size, height: size }}>
        <svg width={size} height={size} className="-rotate-90">
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#F1F4F8" strokeWidth={thickness} />
          {total > 0 &&
            slices.map((s) => {
              const len = (s.value / total) * c;
              const el = (
                <circle
                  key={s.label}
                  cx={size / 2}
                  cy={size / 2}
                  r={r}
                  fill="none"
                  stroke={s.color}
                  strokeWidth={thickness}
                  strokeDasharray={`${Math.max(len - 2, 0)} ${c}`}
                  strokeDashoffset={-offset}
                  className="transition-[stroke-dasharray] duration-700"
                />
              );
              offset += len;
              return el;
            })}
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center text-center">{center}</div>
      </div>
      <ul className="min-w-0 flex-1 space-y-2.5">
        {slices.map((s) => (
          <li key={s.label} className="flex items-center justify-between gap-3 text-sm">
            <span className="flex min-w-0 items-center gap-2 text-gray-600">
              <span className="h-2.5 w-2.5 flex-shrink-0 rounded-sm" style={{ background: s.color }} />
              <span className="truncate">{s.label}</span>
            </span>
            <span className="font-semibold tabular-nums text-ink">
              {s.value}
              <span className="ml-1.5 text-xs font-normal text-muted">
                {total ? Math.round((s.value / total) * 100) : 0} %
              </span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
