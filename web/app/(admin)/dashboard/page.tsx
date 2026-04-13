'use client';

import React, { useEffect, useState, useCallback } from 'react';
import StatCard from '@/components/admin/StatCard';
import { getStats } from '@/lib/api';

interface ExpiringLicence {
  id: number;
  tel: string;
  code: string;
  expire: string;
  jours: number;
}

interface Activity {
  type: string;
  text: string;
  time: string;
  color: string;
}

interface MonthlyItem {
  month: string;
  value: number;
  revenue: number;
}

interface Repartition {
  annuel: number;
  mensuel: number;
  essai: number;
}

interface DashboardData {
  licences_actives: number;
  clients_total: number;
  demandes_en_attente: number;
  revenus_mois: number;
  licences_expirant: ExpiringLicence[];
  monthly_data: MonthlyItem[];
  repartition: Repartition;
  activite: Activity[];
}

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [lastRefresh, setLastRefresh] = useState<Date>(new Date());

  const loadData = useCallback(async () => {
    try {
      const result = await getStats();
      setData(result);
    } catch {
      // Pas de données — on affiche un état vide
      setData({
        licences_actives: 0,
        clients_total: 0,
        demandes_en_attente: 0,
        revenus_mois: 0,
        licences_expirant: [],
        monthly_data: [],
        repartition: { annuel: 0, mensuel: 0, essai: 0 },
        activite: [],
      });
    } finally {
      setLoading(false);
      setLastRefresh(new Date());
    }
  }, []);

  useEffect(() => {
    loadData();
    // Auto-refresh toutes les 30 secondes
    const interval = setInterval(loadData, 30000);
    return () => clearInterval(interval);
  }, [loadData]);

  if (loading || !data) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="text-center">
          <div className="w-12 h-12 rounded-full border-4 border-primary/20 border-t-primary animate-spin mx-auto mb-4" />
          <p className="text-muted text-sm">Chargement du dashboard...</p>
        </div>
      </div>
    );
  }

  const { licences_expirant, monthly_data, repartition, activite } = data;
  const maxVal = monthly_data.length > 0 ? Math.max(...monthly_data.map(d => d.value), 1) : 1;
  const totalLicencesMois = monthly_data.reduce((s, d) => s + d.value, 0);
  const totalRepartition = repartition.annuel + repartition.mensuel + repartition.essai || 1;

  // Calcul donut
  const circumference = 2 * Math.PI * 38; // ~238.76
  const annuelPct = repartition.annuel / totalRepartition;
  const mensuelPct = repartition.mensuel / totalRepartition;
  const essaiPct = repartition.essai / totalRepartition;

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-extrabold text-dark">Tableau de bord</h1>
          <p className="text-muted text-sm mt-1">
            Données en temps réel — mis à jour {lastRefresh.toLocaleTimeString('fr-FR')}
          </p>
        </div>
        <button onClick={loadData}
          className="flex items-center gap-2 px-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm font-medium text-muted hover:text-primary hover:border-primary/30 transition-all shadow-soft">
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Actualiser
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard title="Licences actives" value={data.licences_actives} color="blue"
          icon={<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" /></svg>} />
        <StatCard title="Clients total" value={data.clients_total} color="green"
          icon={<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" /></svg>} />
        <StatCard title="Demandes en attente" value={data.demandes_en_attente} color="orange"
          icon={<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>} />
        <StatCard title="Revenus ce mois" value={`${data.revenus_mois.toLocaleString('fr-FR')} FCFA`} color="purple"
          icon={<svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>} />
      </div>

      {/* Charts row */}
      <div className="grid lg:grid-cols-3 gap-6">
        {/* Bar chart */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-gray-100 p-6 shadow-soft">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-lg font-bold text-dark">Licences par mois</h3>
              <p className="text-sm text-muted mt-0.5">12 derniers mois</p>
            </div>
            {totalLicencesMois > 0 && (
              <div className="px-3 py-1.5 bg-primary-50 text-primary text-xs font-semibold rounded-lg">
                {totalLicencesMois} total
              </div>
            )}
          </div>
          {monthly_data.length === 0 ? (
            <div className="h-64 flex items-center justify-center text-muted text-sm">
              Aucune donnée disponible
            </div>
          ) : (
            <div className="h-64 flex items-end justify-between gap-2 px-2">
              {monthly_data.map((d, i) => (
                <div key={i} className="flex-1 flex flex-col items-center gap-2 group">
                  <span className="text-[10px] text-muted opacity-0 group-hover:opacity-100 transition-opacity font-semibold">
                    {d.value}
                  </span>
                  <div className="w-full relative rounded-t-lg overflow-hidden cursor-pointer transition-all duration-300"
                    style={{ height: `${(d.value / maxVal) * 200}px`, minHeight: d.value > 0 ? '8px' : '0' }}>
                    <div className="absolute inset-0 bg-gradient-to-t from-primary to-primary-light opacity-80 group-hover:opacity-100 transition-opacity" />
                    <div className="absolute inset-0 shimmer opacity-0 group-hover:opacity-100" />
                  </div>
                  <span className="text-[11px] text-muted font-medium">{d.month}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Donut chart */}
        <div className="bg-white rounded-2xl border border-gray-100 p-6 shadow-soft">
          <h3 className="text-lg font-bold text-dark mb-2">Répartition des plans</h3>
          <p className="text-sm text-muted mb-6">Distribution par type</p>
          <div className="flex flex-col items-center">
            <div className="relative w-44 h-44 mb-6">
              <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
                <circle cx="50" cy="50" r="38" fill="none" stroke="#E5E7EB" strokeWidth="12" />
                {annuelPct > 0 && (
                  <circle cx="50" cy="50" r="38" fill="none" stroke="#1565C0" strokeWidth="12"
                    strokeDasharray={`${annuelPct * circumference} ${circumference}`} strokeDashoffset="0" strokeLinecap="round" />
                )}
                {mensuelPct > 0 && (
                  <circle cx="50" cy="50" r="38" fill="none" stroke="#FF6B35" strokeWidth="12"
                    strokeDasharray={`${mensuelPct * circumference} ${circumference}`}
                    strokeDashoffset={`${-annuelPct * circumference}`} strokeLinecap="round" />
                )}
                {essaiPct > 0 && (
                  <circle cx="50" cy="50" r="38" fill="none" stroke="#42A5F5" strokeWidth="12"
                    strokeDasharray={`${essaiPct * circumference} ${circumference}`}
                    strokeDashoffset={`${-(annuelPct + mensuelPct) * circumference}`} strokeLinecap="round" />
                )}
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className="text-3xl font-extrabold text-dark">{data.licences_actives}</span>
                <span className="text-xs text-muted">actives</span>
              </div>
            </div>
            <div className="space-y-3 w-full">
              {[
                { label: 'Annuel', color: 'bg-primary', count: repartition.annuel, pct: Math.round(annuelPct * 100) },
                { label: 'Mensuel', color: 'bg-accent', count: repartition.mensuel, pct: Math.round(mensuelPct * 100) },
                { label: 'Essai', color: 'bg-primary-light', count: repartition.essai, pct: Math.round(essaiPct * 100) },
              ].map((p) => (
                <div key={p.label} className="flex items-center gap-3">
                  <div className={`w-3 h-3 rounded-full ${p.color}`} />
                  <span className="text-sm text-gray-600 flex-1">{p.label}</span>
                  <span className="text-sm font-bold text-dark">{p.count}</span>
                  <span className="text-xs text-muted">{p.pct}%</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Bottom row */}
      <div className="grid lg:grid-cols-5 gap-6">
        {/* Expiring licences */}
        <div className="lg:col-span-3 bg-white rounded-2xl border border-gray-100 shadow-soft">
          <div className="p-6 border-b border-gray-50 flex items-center justify-between">
            <div>
              <h3 className="text-lg font-bold text-dark">Licences expirant bientôt</h3>
              <p className="text-sm text-muted mt-0.5">Dans les 30 prochains jours</p>
            </div>
            <span className="px-3 py-1 bg-orange-50 text-orange-600 text-xs font-semibold rounded-lg">
              {licences_expirant.length} licence{licences_expirant.length > 1 ? 's' : ''}
            </span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-50">
                  {['Téléphone', 'Code licence', 'Expire le', 'Jours'].map((h) => (
                    <th key={h} className="text-left px-6 py-3 text-[11px] font-bold text-muted uppercase tracking-wider">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {licences_expirant.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="text-center py-12 text-muted text-sm">
                      <svg className="w-12 h-12 text-gray-200 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      Aucune licence n&apos;expire prochainement
                    </td>
                  </tr>
                ) : (
                  licences_expirant.map((l) => (
                    <tr key={l.id} className="border-b border-gray-50/50 hover:bg-soft/50 transition-colors">
                      <td className="px-6 py-4">
                        <span className="text-sm font-semibold text-dark">{l.tel}</span>
                      </td>
                      <td className="px-6 py-4">
                        <code className="text-xs bg-gray-50 px-2 py-1 rounded-md text-gray-600 font-mono">
                          {l.code.length > 20 ? l.code.substring(0, 20) + '...' : l.code}
                        </code>
                      </td>
                      <td className="px-6 py-4 text-sm text-muted">{l.expire}</td>
                      <td className="px-6 py-4">
                        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${
                          l.jours <= 5 ? 'bg-red-50 text-red-700' : l.jours <= 10 ? 'bg-orange-50 text-orange-700' : 'bg-yellow-50 text-yellow-700'
                        }`}>
                          {l.jours}j
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Recent activity */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-gray-100 p-6 shadow-soft">
          <h3 className="text-lg font-bold text-dark mb-1">Activité récente</h3>
          <p className="text-sm text-muted mb-6">Dernières actions</p>
          {activite.length === 0 ? (
            <div className="text-center py-8 text-muted text-sm">
              <svg className="w-12 h-12 text-gray-200 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Aucune activité récente
            </div>
          ) : (
            <div className="space-y-4">
              {activite.map((a, i) => (
                <div key={i} className="flex gap-3">
                  <div className="relative">
                    <div className={`w-2.5 h-2.5 rounded-full ${a.color} mt-1.5`} />
                    {i < activite.length - 1 && (
                      <div className="absolute top-4 left-1 w-0.5 h-full bg-gray-100" />
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-dark leading-snug">{a.text}</p>
                    <p className="text-xs text-muted mt-0.5">{a.time}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
