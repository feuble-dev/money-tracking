'use client';

import React, { useEffect, useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { attachTransactionType, getTransactionTypes } from '@/lib/api';

interface AttachTransactionTypeModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAttached: () => void;
  operatorId: number;
  alreadyAttachedTypeIds: number[];
}

interface TransactionTypeOption {
  id: number;
  code: string;
  label: string;
  default_direction: 'in' | 'out';
}

export default function AttachTransactionTypeModal({
  isOpen,
  onClose,
  onAttached,
  operatorId,
  alreadyAttachedTypeIds,
}: AttachTransactionTypeModalProps) {
  const [types, setTypes] = useState<TransactionTypeOption[]>([]);
  const [typeId, setTypeId] = useState<number | ''>('');
  const [ussdCode, setUssdCode] = useState('');
  const [commissionTaux, setCommissionTaux] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isOpen) return;
    getTransactionTypes().then(setTypes).catch(() => setTypes([]));
  }, [isOpen]);

  const availableTypes = types.filter((t) => !alreadyAttachedTypeIds.includes(t.id));

  const reset = () => {
    setTypeId('');
    setUssdCode('');
    setCommissionTaux(0);
    setError('');
  };

  const handleClose = () => {
    reset();
    onClose();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!typeId) {
      setError('Sélectionnez un type');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await attachTransactionType({
        operator: operatorId,
        transaction_type: Number(typeId),
        ussd_code: ussdCode,
        commission_taux: commissionTaux,
      });
      onAttached();
      handleClose();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Erreur lors de l\'association';
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Activer un type de transaction">
      <form onSubmit={handleSubmit} className="space-y-5">
        {error && <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Type de transaction</label>
          <select
            value={typeId}
            onChange={(e) => setTypeId(e.target.value ? Number(e.target.value) : '')}
            required
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
          >
            <option value="">Sélectionner...</option>
            {availableTypes.map((t) => (
              <option key={t.id} value={t.id}>
                {t.label} ({t.default_direction === 'in' ? 'entrant' : 'sortant'})
              </option>
            ))}
          </select>
          {availableTypes.length === 0 && (
            <p className="text-xs text-gray-400 mt-1">
              Tous les types existants sont déjà activés pour cet opérateur — créez-en un nouveau depuis Catalogue &gt; Types de transaction.
            </p>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Code USSD (propre à cet opérateur)</label>
          <input
            type="text"
            value={ussdCode}
            onChange={(e) => setUssdCode(e.target.value)}
            placeholder="*144*1#"
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Commission (%)</label>
          <input
            type="number"
            step="0.001"
            value={commissionTaux}
            onChange={(e) => setCommissionTaux(Number(e.target.value))}
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <div className="flex gap-3 pt-2">
          <Button type="button" variant="ghost" onClick={handleClose} className="flex-1">
            Annuler
          </Button>
          <Button type="submit" variant="primary" disabled={loading} className="flex-1">
            {loading ? 'Association...' : 'Activer'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
