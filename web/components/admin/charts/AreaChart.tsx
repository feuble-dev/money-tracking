'use client';

import React, { useMemo, useState } from 'react';
import { labelAnchor, niceMax, shortDate, useWidth } from './useWidth';

export interface Point {
  date: string;
  value: number;
}

/** Courbe d'évolution avec infobulle au survol. */
export default function AreaChart({
  data,
  height = 220,
  color = '#1565C0',
  format = (v: number) => String(v),
}: {
  data: Point[];
  height?: number;
  color?: string;
  format?: (v: number) => string;
}) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  const pad = { top: 12, right: 8, bottom: 26, left: 8 };
  const w = width - pad.left - pad.right;
  const h = height - pad.top - pad.bottom;
  const max = niceMax(Math.max(...data.map((d) => d.value), 0));
  const id = useMemo(() => `area-${Math.random().toString(36).slice(2)}`, []);

  const x = (i: number) => pad.left + (data.length <= 1 ? w / 2 : (i / (data.length - 1)) * w);
  const y = (v: number) => pad.top + h - (v / max) * h;

  const line = data.map((d, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(d.value).toFixed(1)}`).join(' ');
  const area = data.length ? `${line} L${x(data.length - 1)},${pad.top + h} L${x(0)},${pad.top + h} Z` : '';
  const ticks = [0, 0.5, 1];
  const labelEvery = Math.max(1, Math.ceil(data.length / Math.max(2, Math.floor(w / 70))));

  const onMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const rel = (e.clientX - rect.left - pad.left) / w;
    setHover(Math.max(0, Math.min(data.length - 1, Math.round(rel * (data.length - 1)))));
  };

  return (
    <div ref={ref} className="relative" style={{ height }}>
      <svg width={width} height={height} onMouseMove={onMove} onMouseLeave={() => setHover(null)} className="block">
        <defs>
          <linearGradient id={id} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.18" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        {ticks.map((t) => (
          <line key={t} x1={pad.left} x2={pad.left + w} y1={y(max * t)} y2={y(max * t)} stroke="#EEF1F5" />
        ))}
        <path d={area} fill={`url(#${id})`} />
        <path d={line} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
        {data.map((d, i) =>
          i % labelEvery === 0 ? (
            <text key={d.date} x={x(i)} y={height - 6} textAnchor={labelAnchor(x(i), width)} className="fill-gray-400 text-[10px]">
              {shortDate(d.date)}
            </text>
          ) : null,
        )}
        {hover !== null && data[hover] && (
          <g>
            <line x1={x(hover)} x2={x(hover)} y1={pad.top} y2={pad.top + h} stroke="#CBD5E1" strokeDasharray="3 3" />
            <circle cx={x(hover)} cy={y(data[hover].value)} r={4.5} fill="white" stroke={color} strokeWidth={2} />
          </g>
        )}
      </svg>
      {hover !== null && data[hover] && (
        <div
          className="pointer-events-none absolute top-0 -translate-x-1/2 rounded-lg bg-ink px-2.5 py-1.5 text-xs text-white shadow-lg"
          style={{ left: Math.min(Math.max(x(hover), 60), width - 60) }}
        >
          <p className="font-semibold">{format(data[hover].value)}</p>
          <p className="text-white/60">{shortDate(data[hover].date)}</p>
        </div>
      )}
    </div>
  );
}
