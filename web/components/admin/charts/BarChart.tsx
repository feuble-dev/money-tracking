'use client';

import React, { useState } from 'react';
import { labelAnchor, niceMax, shortDate, useWidth } from './useWidth';

export interface BarSeries {
  label: string;
  color: string;
  values: number[];
}

/** Barres empilées (ex. inscriptions Particulier / Agence par jour). */
export default function BarChart({
  dates,
  series,
  height = 220,
}: {
  dates: string[];
  series: BarSeries[];
  height?: number;
}) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  const pad = { top: 12, right: 4, bottom: 26, left: 4 };
  const w = width - pad.left - pad.right;
  const h = height - pad.top - pad.bottom;
  const totals = dates.map((_, i) => series.reduce((s, se) => s + (se.values[i] ?? 0), 0));
  const max = niceMax(Math.max(...totals, 0));
  const slot = w / Math.max(dates.length, 1);
  const bar = Math.max(2, Math.min(28, slot * 0.62));
  const labelEvery = Math.max(1, Math.ceil(dates.length / Math.max(2, Math.floor(w / 70))));

  return (
    <div ref={ref} className="relative" style={{ height }}>
      <svg width={width} height={height} className="block" onMouseLeave={() => setHover(null)}>
        {[0, 0.5, 1].map((t) => (
          <line key={t} x1={pad.left} x2={pad.left + w} y1={pad.top + h - h * t} y2={pad.top + h - h * t} stroke="#EEF1F5" />
        ))}
        {dates.map((d, i) => {
          let acc = 0;
          let drawn = 0;
          const cx = pad.left + slot * i + slot / 2;
          return (
            <g key={d} onMouseEnter={() => setHover(i)}>
              <rect x={pad.left + slot * i} y={pad.top} width={slot} height={h} fill="transparent" />
              {series.map((se) => {
                const v = se.values[i] ?? 0;
                const bh = (v / max) * h;
                acc += bh;
                if (v <= 0) return null;
                // 2 px de fond entre deux segments empilés.
                const gap = drawn++ > 0 ? 2 : 0;
                return (
                  <rect
                    key={se.label}
                    x={cx - bar / 2}
                    y={pad.top + h - acc}
                    width={bar}
                    height={Math.max(bh - gap, 1)}
                    rx={2}
                    fill={se.color}
                    opacity={hover === null || hover === i ? 1 : 0.45}
                    className="transition-opacity"
                  />
                );
              })}
              {i % labelEvery === 0 && (
                <text x={cx} y={height - 6} textAnchor={labelAnchor(cx, width)} className="fill-gray-400 text-[10px]">
                  {shortDate(d)}
                </text>
              )}
            </g>
          );
        })}
      </svg>
      {hover !== null && (
        <div
          className="pointer-events-none absolute top-0 -translate-x-1/2 rounded-lg bg-ink px-2.5 py-1.5 text-xs text-white shadow-lg"
          style={{ left: Math.min(Math.max(pad.left + slot * hover + slot / 2, 70), width - 70) }}
        >
          <p className="mb-1 text-white/60">{shortDate(dates[hover])}</p>
          {series.map((se) => (
            <p key={se.label} className="flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-sm" style={{ background: se.color }} />
              {se.label} : <span className="font-semibold">{se.values[hover] ?? 0}</span>
            </p>
          ))}
        </div>
      )}
    </div>
  );
}
