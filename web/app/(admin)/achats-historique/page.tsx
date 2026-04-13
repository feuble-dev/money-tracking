'use client';

import React, { useEffect, useState } from 'react';
import { getAchatsHistorique, validerAchatHistorique } from '@/lib/api';

interface Achat {
  id: number;
  telephone: string;
  device_id: string;
  statut: string;
  token: string | null;
  montant_paye: number;
  created_at: string;
}

export default function AchatsHistoriquePage() {
  const [achats, setAchats] = useState<Achat[]>([]);
  const [loading, setLoading] = useState(true);
  const [validating, setValidating] = useState<number | null>(null);
  const [generatedToken, setGeneratedToken] = useState<string | null>(null);

  useEffect(() => { loadData(); }, []);

  const loadData = async () => {
    try {
      const data = await getAchatsHistorique();
      setAchats(data);
    } catch {
      setAchats([]);
    } finally {
      setLoading(false);
    }
  };

  const handleValidate = async (id: number) => {
    setValidating(id);
    try {
      const res = await validerAchatHistorique(id);
      setGeneratedToken(res.token);
      loadData();
    } catch {
      // error
    } finally {
      setValidating(null);
    }
  };

  const enAttente = achats.filter(a => a.statut === 'en_attente');
  const valides = achats.filter(a => a.statut === 'active');

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-12 h-12 rounded-full border-4 border-primary/20 border-t-primary animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold text-dark">Achats Import Historique SMS</h1>
        <p className="text-muted text-sm mt-1">Gérez les demandes d&apos;achat import historique (2 000 FCFA)</p>
      </div>

      {/* Token affiché après validation */}
      {generatedToken && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 rounded-2xl">
          <p className="text-sm text-emerald-700 font-semibold mb-2">Token généré avec succès :</p>
          <div className="flex items-center gap-3">
            <code className="flex-1 px-4 py-3 bg-white border border-emerald-300 rounded-xl text-lg font-mono font-bold text-dark">
              {generatedToken}
            </code>
            <button onClick={() => { navigator.clipboard.writeText(generatedToken); }}
              className="px-4 py-3 bg-emerald-600 text-white font-semibold rounded-xl hover:bg-emerald-700 text-sm">
              Copier
            </button>
          </div>
        </div>
      )}

      {/* Demandes en attente */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-soft">
        <div className="p-6 border-b border-gray-50 flex items-center justify-between">
          <div>
            <h3 className="text-lg font-bold text-dark">Demandes en attente</h3>
            <p className="text-sm text-muted mt-0.5">{enAttente.length} demande(s)</p>
          </div>
          <span className="px-3 py-1 bg-orange-50 text-orange-600 text-xs font-semibold rounded-lg">
            2 000 FCFA / achat
          </span>
        </div>

        {enAttente.length === 0 ? (
          <div className="p-12 text-center text-muted text-sm">Aucune demande en attente</div>
        ) : (
          <div className="divide-y divide-gray-50">
            {enAttente.map(a => (
              <div key={a.id} className="p-5 flex items-center gap-4">
                <div className="w-10 h-10 bg-orange-50 rounded-xl flex items-center justify-center">
                  <svg className="w-5 h-5 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div className="flex-1">
                  <div className="text-sm font-bold text-dark">{a.telephone}</div>
                  <div className="text-xs text-muted">Device: {a.device_id} — {new Date(a.created_at).toLocaleDateString('fr-FR')}</div>
                </div>
                <div className="text-sm font-bold text-dark">{a.montant_paye.toLocaleString('fr-FR')} FCFA</div>
                <button onClick={() => handleValidate(a.id)} disabled={validating === a.id}
                  className="px-4 py-2 bg-emerald-500 text-white font-semibold rounded-xl hover:bg-emerald-600 text-sm disabled:opacity-50">
                  {validating === a.id ? 'Validation...' : 'Valider'}
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Achats validés */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-soft">
        <div className="p-6 border-b border-gray-50">
          <h3 className="text-lg font-bold text-dark">Achats validés</h3>
          <p className="text-sm text-muted mt-0.5">{valides.length} achat(s)</p>
        </div>
        {valides.length === 0 ? (
          <div className="p-12 text-center text-muted text-sm">Aucun achat validé</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-50">
                  {['Téléphone', 'Device', 'Token', 'Montant', 'Date'].map(h => (
                    <th key={h} className="text-left px-6 py-3 text-[11px] font-bold text-muted uppercase tracking-wider">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {valides.map(a => (
                  <tr key={a.id} className="border-b border-gray-50/50 hover:bg-soft/50">
                    <td className="px-6 py-4 text-sm font-semibold text-dark">{a.telephone}</td>
                    <td className="px-6 py-4 text-xs text-muted">{a.device_id}</td>
                    <td className="px-6 py-4">
                      <code className="text-xs bg-gray-50 px-2 py-1 rounded-md text-gray-600 font-mono">{a.token}</code>
                    </td>
                    <td className="px-6 py-4 text-sm">{a.montant_paye.toLocaleString('fr-FR')} F</td>
                    <td className="px-6 py-4 text-sm text-muted">{new Date(a.created_at).toLocaleDateString('fr-FR')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
