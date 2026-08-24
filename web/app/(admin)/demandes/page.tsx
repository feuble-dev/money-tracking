'use client';

import React, { useEffect, useState } from 'react';
import Button from '@/components/ui/Button';
import Badge from '@/components/ui/Badge';
import Modal from '@/components/ui/Modal';
import { getDemandes, validerDemande, rejeterDemande } from '@/lib/api';

interface Demande {
  id: number;
  telephone: string;
  nom?: string;
  duree_mois: number;
  montant?: number;
  device_id: string;
  created_at: string;
  statut: string;
  note?: string;
}

const demoDemandes: Demande[] = [
  {
    id: 1,
    telephone: '+226 70 99 88 77',
    nom: 'Diallo Abdoulaye',
    duree_mois: 12,
    montant: 10000,
    device_id: 'android-xyz111',
    created_at: '2026-03-29T10:00:00',
    statut: 'en_attente',
  },
  {
    id: 2,
    telephone: '+226 76 55 44 33',
    nom: 'Sanou Marie',
    duree_mois: 1,
    montant: 1000,
    device_id: 'android-xyz222',
    created_at: '2026-03-28T10:00:00',
    statut: 'en_attente',
  },
  {
    id: 3,
    telephone: '+226 71 22 33 44',
    nom: 'Ouattara Issa',
    duree_mois: 12,
    montant: 10000,
    device_id: 'android-xyz333',
    created_at: '2026-03-27T10:00:00',
    statut: 'en_attente',
  },
  {
    id: 4,
    telephone: '+226 65 11 22 33',
    nom: 'Belem Pascaline',
    duree_mois: 1,
    montant: 1000,
    device_id: 'android-xyz444',
    created_at: '2026-03-26T10:00:00',
    statut: 'en_attente',
  },
  {
    id: 5,
    telephone: '+226 78 66 77 88',
    nom: 'Tapsoba Rasmané',
    duree_mois: 1,
    montant: 0,
    device_id: 'android-xyz555',
    created_at: '2026-03-25T10:00:00',
    statut: 'en_attente',
  },
];

export default function DemandesPage() {
  const [demandes, setDemandes] = useState<Demande[]>([]);
  const [loading, setLoading] = useState(true);
  const [processingId, setProcessingId] = useState<number | null>(null);
  const [generatedCode, setGeneratedCode] = useState('');
  const [showCodeModal, setShowCodeModal] = useState(false);
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectId, setRejectId] = useState<number | null>(null);
  const [rejectMotif, setRejectMotif] = useState('');

  useEffect(() => {
    loadDemandes();
  }, []);

  const loadDemandes = async () => {
    try {
      const data = await getDemandes();
      setDemandes(data.results || data);
    } catch {
      setDemandes(demoDemandes);
    } finally {
      setLoading(false);
    }
  };

  const handleValider = async (id: number) => {
    setProcessingId(id);
    try {
      const result = await validerDemande(id);
      setGeneratedCode(result.code || result.licence_key || `MT-${Math.random().toString(36).substring(2, 6).toUpperCase()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`);
      setShowCodeModal(true);
      setDemandes((prev) =>
        prev.map((d) => (d.id === id ? { ...d, statut: 'validée' } : d))
      );
    } catch {
      // Demo mode: generate a fake code
      const code = `MT-${Math.random().toString(36).substring(2, 6).toUpperCase()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;
      setGeneratedCode(code);
      setShowCodeModal(true);
      setDemandes((prev) =>
        prev.map((d) => (d.id === id ? { ...d, statut: 'validée' } : d))
      );
    } finally {
      setProcessingId(null);
    }
  };

  const openRejectModal = (id: number) => {
    setRejectId(id);
    setRejectMotif('');
    setShowRejectModal(true);
  };

  const handleRejeter = async () => {
    if (!rejectId) return;
    setProcessingId(rejectId);
    try {
      await rejeterDemande(rejectId, rejectMotif);
    } catch {
      // Demo mode
    }
    setDemandes((prev) =>
      prev.map((d) =>
        d.id === rejectId ? { ...d, statut: 'rejetée', motif_rejet: rejectMotif } : d
      )
    );
    setShowRejectModal(false);
    setRejectId(null);
    setProcessingId(null);
  };

  const pendingDemandes = demandes.filter((d) => d.statut === 'en_attente');
  const processedDemandes = demandes.filter((d) => d.statut !== 'en_attente');

  const getDureLabel = (duree: string) => {
    switch (duree) {
      case '12':
      case 'annuel':
        return 'Annuel (12 mois)';
      case '24':
        return '2 ans (24 mois)';
      case '1':
      case 'mensuel':
        return 'Mensuel';
      case 'essai':
        return 'Essai gratuit';
      default:
        return duree;
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold text-dark">Demandes de licence</h2>
        <p className="text-sm text-gray-500 mt-1">
          {pendingDemandes.length} demande(s) en attente de validation
        </p>
      </div>

      {/* Pending requests */}
      {pendingDemandes.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-100 p-12 text-center">
          <div className="w-16 h-16 bg-green-100 text-green-600 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h3 className="text-lg font-bold text-dark mb-2">Tout est à jour</h3>
          <p className="text-gray-500 text-sm">Aucune demande en attente de validation.</p>
        </div>
      ) : (
        <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-6">
          {pendingDemandes.map((demande) => (
            <div
              key={demande.id}
              className="bg-white rounded-2xl border border-gray-100 p-6 hover:shadow-lg transition-shadow"
            >
              {/* Header */}
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-11 h-11 rounded-full bg-accent/10 text-accent flex items-center justify-center text-sm font-bold">
                    {(demande.nom || demande.telephone || '?').charAt(0)}
                  </div>
                  <div>
                    <p className="text-sm font-bold text-dark">{demande.nom || demande.telephone}</p>
                    <p className="text-xs text-gray-500">{demande.telephone}</p>
                  </div>
                </div>
                <Badge variant="warning">En attente</Badge>
              </div>

              {/* Details */}
              <div className="space-y-3 mb-6">
                <div className="flex items-center justify-between py-2 border-b border-gray-50">
                  <span className="text-xs text-gray-400 uppercase tracking-wider">Durée</span>
                  <span className="text-sm font-medium text-dark">{getDureLabel(String(demande.duree_mois))}</span>
                </div>
                <div className="flex items-center justify-between py-2 border-b border-gray-50">
                  <span className="text-xs text-gray-400 uppercase tracking-wider">Montant</span>
                  <span className="text-sm font-bold text-dark">
                    {(demande.montant || 0) === 0 ? 'Gratuit' : `${(demande.montant || 0).toLocaleString('fr-FR')} FCFA`}
                  </span>
                </div>
                <div className="flex items-center justify-between py-2 border-b border-gray-50">
                  <span className="text-xs text-gray-400 uppercase tracking-wider">Device</span>
                  <span className="text-xs font-mono text-gray-500">{demande.device_id}</span>
                </div>
                <div className="flex items-center justify-between py-2">
                  <span className="text-xs text-gray-400 uppercase tracking-wider">Date</span>
                  <span className="text-sm text-gray-600">{demande.created_at ? new Date(demande.created_at).toLocaleDateString('fr-FR') : '-'}</span>
                </div>
              </div>

              {/* Actions */}
              <div className="flex gap-3">
                <Button
                  variant="danger"
                  size="sm"
                  onClick={() => openRejectModal(demande.id)}
                  disabled={processingId === demande.id}
                  className="flex-1"
                >
                  Rejeter
                </Button>
                <Button
                  variant="primary"
                  size="sm"
                  onClick={() => handleValider(demande.id)}
                  disabled={processingId === demande.id}
                  className="flex-1"
                >
                  {processingId === demande.id ? 'Traitement...' : 'Valider'}
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Processed requests */}
      {processedDemandes.length > 0 && (
        <div>
          <h3 className="text-lg font-bold text-dark mb-4">Demandes traitées</h3>
          <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50/50">
                    <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                      Client
                    </th>
                    <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                      Téléphone
                    </th>
                    <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                      Durée
                    </th>
                    <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                      Montant
                    </th>
                    <th className="text-left px-6 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">
                      Statut
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {processedDemandes.map((d) => (
                    <tr key={d.id} className="border-b border-gray-50 hover:bg-gray-50/50">
                      <td className="px-6 py-4 text-sm font-medium text-dark">{d.nom || d.telephone}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">{d.telephone}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">{getDureLabel(String(d.duree_mois))}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">
                        {(d.montant || 0) === 0 ? 'Gratuit' : `${(d.montant || 0).toLocaleString('fr-FR')} FCFA`}
                      </td>
                      <td className="px-6 py-4">
                        {d.statut === 'validee' ? (
                          <Badge variant="success">Validée</Badge>
                        ) : (
                          <Badge variant="danger">Rejetée</Badge>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* Generated code modal */}
      <Modal
        isOpen={showCodeModal}
        onClose={() => setShowCodeModal(false)}
        title="Licence générée"
      >
        <div className="text-center py-4">
          <div className="w-16 h-16 bg-green-100 text-green-600 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h3 className="text-lg font-bold text-dark mb-2">Demande validée avec succès</h3>
          <div className="bg-soft rounded-xl p-4 mb-4">
            <p className="text-xs text-gray-500 mb-1">Code licence généré</p>
            <p className="text-2xl font-mono font-bold text-primary tracking-wider">
              {generatedCode}
            </p>
          </div>
          <p className="text-sm text-gray-500 mb-6">
            Communiquez ce code au client pour activer sa licence.
          </p>
          <Button variant="primary" onClick={() => setShowCodeModal(false)} className="w-full">
            Fermer
          </Button>
        </div>
      </Modal>

      {/* Reject modal */}
      <Modal
        isOpen={showRejectModal}
        onClose={() => setShowRejectModal(false)}
        title="Rejeter la demande"
      >
        <div className="space-y-5">
          <p className="text-sm text-gray-600">
            Veuillez indiquer le motif du rejet. Le client sera informé.
          </p>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              Motif du rejet
            </label>
            <textarea
              value={rejectMotif}
              onChange={(e) => setRejectMotif(e.target.value)}
              placeholder="Ex: Paiement non reçu, informations incomplètes..."
              rows={3}
              className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm resize-none"
            />
          </div>
          <div className="flex gap-3 pt-2">
            <Button
              type="button"
              variant="ghost"
              onClick={() => setShowRejectModal(false)}
              className="flex-1"
            >
              Annuler
            </Button>
            <Button
              type="button"
              variant="danger"
              onClick={handleRejeter}
              disabled={!rejectMotif.trim()}
              className="flex-1"
            >
              Confirmer le rejet
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
