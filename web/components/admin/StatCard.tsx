import React from 'react';

interface StatCardProps {
  title: string;
  value: string | number;
  icon: React.ReactNode;
  trend?: string;
  trendUp?: boolean;
  color: 'blue' | 'green' | 'orange' | 'purple';
}

const colorMap = {
  blue: {
    gradient: 'from-blue-500 to-blue-600',
    bg: 'bg-blue-50',
    icon: 'bg-gradient-to-br from-blue-500 to-blue-600 text-white',
    ring: 'ring-blue-500/20',
  },
  green: {
    gradient: 'from-emerald-500 to-emerald-600',
    bg: 'bg-emerald-50',
    icon: 'bg-gradient-to-br from-emerald-500 to-emerald-600 text-white',
    ring: 'ring-emerald-500/20',
  },
  orange: {
    gradient: 'from-orange-500 to-orange-600',
    bg: 'bg-orange-50',
    icon: 'bg-gradient-to-br from-orange-500 to-orange-600 text-white',
    ring: 'ring-orange-500/20',
  },
  purple: {
    gradient: 'from-violet-500 to-violet-600',
    bg: 'bg-violet-50',
    icon: 'bg-gradient-to-br from-violet-500 to-violet-600 text-white',
    ring: 'ring-violet-500/20',
  },
};

export default function StatCard({ title, value, icon, trend, trendUp, color }: StatCardProps) {
  const c = colorMap[color];

  return (
    <div className={`relative bg-white rounded-2xl p-6 border border-gray-100 shadow-soft hover:shadow-medium transition-all duration-300 overflow-hidden group`}>
      {/* Subtle gradient overlay on hover */}
      <div className={`absolute inset-0 ${c.bg} opacity-0 group-hover:opacity-50 transition-opacity duration-300`} />

      <div className="relative flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-muted mb-1">{title}</p>
          <p className="text-3xl font-extrabold text-dark tracking-tight">{value}</p>
          {trend && (
            <div className={`inline-flex items-center gap-1 mt-3 px-2.5 py-1 rounded-full text-xs font-semibold ${
              trendUp ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-600'
            }`}>
              <svg className={`w-3 h-3 ${trendUp ? '' : 'rotate-180'}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 10l7-7m0 0l7 7m-7-7v18" />
              </svg>
              {trend}
            </div>
          )}
        </div>
        <div className={`w-14 h-14 rounded-2xl ${c.icon} flex items-center justify-center shadow-lg ring-4 ${c.ring}`}>
          {icon}
        </div>
      </div>
    </div>
  );
}
