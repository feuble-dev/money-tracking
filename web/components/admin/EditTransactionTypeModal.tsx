'use client';

import React, { useEffect, useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { updateTransactionType } from '@/lib/api';

interface TransactionType {
  id: number;
  code: string;
  label: string;
  default_direction: 'in' | 'out';
  is_active: boolean;
}

interface EditTransactionTypeModalProps {
  isOpen: boolean;
  onClose: () => void;
  onUpdated: () => void;
  transactionType: TransactionType | null;
}

export default function EditTransactionTypeModal({ isOpen, onClose, onUpdated, transactionType }: EditTransactionTypeModalProps) {
  const [label, setLabel] = useState('');
  const [defaultDirection, setDefaultDirection] = useState<'in' | 'out'>('in');
  const [isActive, setIsActive] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (transactionType) {
      setLabel(transactionType.label);
      setDefaultDirection(transactionType.default_direction);
      setIsActive(transactionType.is_active);
    }
  }, [transactionType]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!transactionType) return;
    setLoading(true);
    setError('');
    try {
      await updateTransactionType(transactionType.id, { label, default_direction: defaultDirection, is_active: isActive });
      onUpdated();
      onClose();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Erreur lors de la modification';
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={`Modifier ${transactionType?.code ?? ''}`}>
      <form onSubmit={handleSubmit} className="space-y-5">
        {error && <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Libellé</label>
          <input
            type="text"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            required
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">
            Sens par défaut (D1 - un pattern SMS peut ensuite le remplacer pour ce type)
          </label>
          <select
            value={defaultDirection}
            onChange={(e) => setDefaultDirection(e.target.value as 'in' | 'out')}
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
          >
            <option value="in">Entrant</option>
            <option value="out">Sortant</option>
          </select>
        </div>

        <label className="flex items-center gap-2 text-sm text-gray-700">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} className="rounded border-gray-300" />
          Type actif (visible du mobile)
        </label>

        <div className="flex gap-3 pt-2">
          <Button type="button" variant="ghost" onClick={onClose} className="flex-1">
            Annuler
          </Button>
          <Button type="submit" variant="primary" disabled={loading} className="flex-1">
            {loading ? 'Enregistrement...' : 'Enregistrer'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
