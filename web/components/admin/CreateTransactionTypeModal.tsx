'use client';

import React, { useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { createTransactionType } from '@/lib/api';

interface CreateTransactionTypeModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreated: () => void;
}

export default function CreateTransactionTypeModal({ isOpen, onClose, onCreated }: CreateTransactionTypeModalProps) {
  const [code, setCode] = useState('');
  const [label, setLabel] = useState('');
  const [defaultDirection, setDefaultDirection] = useState<'in' | 'out'>('in');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const reset = () => {
    setCode('');
    setLabel('');
    setDefaultDirection('in');
    setError('');
  };

  const handleClose = () => {
    reset();
    onClose();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await createTransactionType({ code, label, default_direction: defaultDirection });
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
    <Modal isOpen={isOpen} onClose={handleClose} title="Créer un type de transaction">
      <form onSubmit={handleSubmit} className="space-y-5">
        {error && <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>}

        <p className="text-xs text-gray-400">
          Ce type est global (D3) - créé une seule fois, il sera ensuite activable pour n&apos;importe quel opérateur avec son propre USSD/commission.
        </p>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Code (identifiant stable)</label>
          <input
            type="text"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            placeholder="paiement_marchand"
            required
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Libellé</label>
          <input
            type="text"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder="Paiement marchand"
            required
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Sens par défaut</label>
          <select
            value={defaultDirection}
            onChange={(e) => setDefaultDirection(e.target.value as 'in' | 'out')}
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
          >
            <option value="in">Entrant</option>
            <option value="out">Sortant</option>
          </select>
          <p className="text-xs text-gray-400 mt-1">
            Un pattern SMS spécifique pourra surcharger ce sens (D1) - utile pour un type qui peut être tantôt entrant, tantôt sortant.
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
