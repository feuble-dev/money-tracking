'use client';

import React, { useEffect, useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { genererLicence, getAgences, getPricingTiers } from '@/lib/api';

interface GenerateLicenceModalProps {
  isOpen: boolean;
  onClose: () => void;
  onGenerated: () => void;
}

interface AgenceOption {
  id: number;
  nom: string;
  telephone_client: string;
}

interface TierOption {
  id: number;
  duree_mois: number;
  montant: number;
  is_essai: boolean;
}

export default function GenerateLicenceModal({
  isOpen,
  onClose,
  onGenerated,
}: GenerateLicenceModalProps) {
  const [agences, setAgences] = useState<AgenceOption[]>([]);
  const [tiers, setTiers] = useState<TierOption[]>([]);
  const [agenceId, setAgenceId] = useState<number | ''>('');
  const [dureeMois, setDureeMois] = useState<number>(1);
  const [montant, setMontant] = useState(450);
  const [loading, setLoading] = useState(false);
  const [generatedCode, setGeneratedCode] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isOpen) return;
    (async () => {
      try {
        const [agencesData, tiersData] = await Promise.all([getAgences(), getPricingTiers()]);
        setAgences(agencesData);
        const payantsTiers = (tiersData as TierOption[]).filter((t) => !t.is_essai);
        setTiers(payantsTiers);
        if (payantsTiers.length > 0) {
          setDureeMois(payantsTiers[0].duree_mois);
          setMontant(payantsTiers[0].montant);
        }
      } catch {
        setError("Impossible de charger les agences/tarifs");
      }
    })();
  }, [isOpen]);

  const handleDureeChange = (value: number) => {
    setDureeMois(value);
    const tier = tiers.find((t) => t.duree_mois === value);
    if (tier) setMontant(tier.montant);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!agenceId) {
      setError('Sélectionnez une agence');
      return;
    }
    setLoading(true);
    setError('');

    try {
      const result = await genererLicence({
        agence_id: Number(agenceId),
        duree_mois: dureeMois,
        montant_paye: montant,
      });
      setGeneratedCode(result.code || 'XXXX-XXXX-XXXX');
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : 'Erreur lors de la génération';
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    if (generatedCode) {
      onGenerated();
    }
    setAgenceId('');
    setGeneratedCode('');
    setError('');
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Générer une licence">
      {generatedCode ? (
        <div className="text-center py-4">
          <div className="w-16 h-16 bg-green-100 text-green-600 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h3 className="text-lg font-bold text-dark mb-2">Licence générée avec succès</h3>
          <div className="bg-soft rounded-xl p-4 mb-4">
            <p className="text-xs text-gray-500 mb-1">Code licence</p>
            <p className="text-2xl font-mono font-bold text-primary tracking-wider">{generatedCode}</p>
          </div>
          <p className="text-sm text-gray-500 mb-6">
            Communiquez ce code au client pour activer sa licence.
          </p>
          <Button variant="primary" onClick={handleClose} className="w-full">
            Fermer
          </Button>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-5">
          {error && (
            <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">Agence</label>
            <select
              value={agenceId}
              onChange={(e) => setAgenceId(e.target.value ? Number(e.target.value) : '')}
              required
              className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
            >
              <option value="">Sélectionner une agence...</option>
              {agences.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.nom} - {a.telephone_client}
                </option>
              ))}
            </select>
            <p className="text-xs text-gray-400 mt-1">
              La licence est facturée par agence (D8) - l&apos;appareil est repris de sa dernière licence.
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">Durée</label>
            <select
              value={dureeMois}
              onChange={(e) => handleDureeChange(Number(e.target.value))}
              className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
            >
              {tiers.map((tier) => (
                <option key={tier.id} value={tier.duree_mois}>
                  {tier.duree_mois} mois - {tier.montant.toLocaleString('fr-FR')} FCFA
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">Montant (FCFA)</label>
            <input
              type="number"
              value={montant}
              onChange={(e) => setMontant(Number(e.target.value))}
              className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
            />
          </div>

          <div className="flex gap-3 pt-2">
            <Button type="button" variant="ghost" onClick={handleClose} className="flex-1">
              Annuler
            </Button>
            <Button type="submit" variant="primary" disabled={loading} className="flex-1">
              {loading ? 'Génération...' : 'Générer'}
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
