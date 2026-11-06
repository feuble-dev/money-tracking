import React from 'react';

/** Mini-courbe de tendance dans une tuile d'indicateur. */
export default function Sparkline({
  values,
  color = '#1565C0',
  width = 96,
  height = 32,
}: {
  values: number[];
  color?: string;
  width?: number;
  height?: number;
}) {
  if (values.length < 2) return null;
  const max = Math.max(...values, 1);
  const min = Math.min(...values, 0);
  const span = max - min || 1;
  const pts = values.map((v, i) => [
    (i / (values.length - 1)) * width,
    height - 2 - ((v - min) / span) * (height - 4),
  ]);
  const d = pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ');
  return (
    <svg width={width} height={height} className="overflow-visible" aria-hidden="true">
      <path d={d} fill="none" stroke={color} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
