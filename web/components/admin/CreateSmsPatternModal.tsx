'use client';

import React, { useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import SmsPatternTagger, { TaggedZone } from '@/components/admin/SmsPatternTagger';
import { createSmsPattern } from '@/lib/api';

interface CreateSmsPatternModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreated: () => void;
  operatorTransactionTypeId: number;
  defaultDirection: 'in' | 'out';
}

export default function CreateSmsPatternModal({
  isOpen,
  onClose,
  onCreated,
  operatorTransactionTypeId,
  defaultDirection,
}: CreateSmsPatternModalProps) {
  const [rawExample, setRawExample] = useState('');
  const [zones, setZones] = useState<TaggedZone[]>([]);
  const [directionOverride, setDirectionOverride] = useState<'' | 'in' | 'out'>('');
  const [cibleCompte, setCibleCompte] = useState<'tous' | 'particulier' | 'agence'>('tous');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const reset = () => {
    setRawExample('');
    setZones([]);
    setDirectionOverride('');
    setCibleCompte('tous');
    setError('');
  };

  const handleClose = () => {
    reset();
    onClose();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (zones.length === 0) {
      setError('Taguez au moins une zone (montant, par exemple)');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await createSmsPattern({
        operator_transaction_type: operatorTransactionTypeId,
        raw_example: rawExample,
        tagged_zones: zones,
        direction_override: directionOverride || null,
        cible_compte: cibleCompte,
      });
      onCreated();
      handleClose();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Erreur lors de la création';
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Ajouter un pattern SMS">
      <form onSubmit={handleSubmit} className="space-y-5">
        {error && <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">SMS exemple</label>
          <textarea
            value={rawExample}
            onChange={(e) => { setRawExample(e.target.value); setZones([]); }}
            rows={3}
            placeholder="Depot de 5000 FCFA recu de 70123456. Ref: TXN2026..."
            required
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm font-mono"
          />
        </div>

        {rawExample && (
          <SmsPatternTagger rawExample={rawExample} zones={zones} onZonesChange={setZones} />
        )}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">
            Sens (optionnel - remplace le sens par défaut du type, actuellement &quot;{defaultDirection === 'in' ? 'entrant' : 'sortant'}&quot;)
          </label>
          <select
            value={directionOverride}
            onChange={(e) => setDirectionOverride(e.target.value as '' | 'in' | 'out')}
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
          >
            <option value="">Utiliser le sens par défaut du type</option>
            <option value="in">Entrant</option>
            <option value="out">Sortant</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">
            Compte visé par ce SMS
          </label>
          <select
            value={cibleCompte}
            onChange={(e) => setCibleCompte(e.target.value as 'tous' | 'particulier' | 'agence')}
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
          >
            <option value="tous">Tous (Particulier et Agence)</option>
            <option value="particulier">Particulier uniquement</option>
            <option value="agence">Agence uniquement</option>
          </select>
          <p className="text-xs text-gray-400 mt-1">
            Le SMS d&apos;un compte Particulier diffère parfois de celui d&apos;un compte Agence
            pour la même transaction - ciblez ce pattern en conséquence.
          </p>
        </div>

        <div className="flex gap-3 pt-2">
          <Button type="button" variant="ghost" onClick={handleClose} className="flex-1">
            Annuler
          </Button>
          <Button type="submit" variant="primary" disabled={loading} className="flex-1">
            {loading ? 'Création...' : 'Créer'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
