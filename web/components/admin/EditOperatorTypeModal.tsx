'use client';

import React, { useEffect, useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { updateOperatorType } from '@/lib/api';

interface OperatorTypeLink {
  id: number;
  transaction_type_label: string;
  ussd_code: string;
  commission_taux: string;
  is_active: boolean;
}

interface EditOperatorTypeModalProps {
  isOpen: boolean;
  onClose: () => void;
  onUpdated: () => void;
  link: OperatorTypeLink | null;
}

export default function EditOperatorTypeModal({ isOpen, onClose, onUpdated, link }: EditOperatorTypeModalProps) {
  const [ussdCode, setUssdCode] = useState('');
  const [commissionTaux, setCommissionTaux] = useState(0);
  const [isActive, setIsActive] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (link) {
      setUssdCode(link.ussd_code);
      setCommissionTaux(Number(link.commission_taux));
      setIsActive(link.is_active);
    }
  }, [link]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!link) return;
    setLoading(true);
    setError('');
    try {
      await updateOperatorType(link.id, { ussd_code: ussdCode, commission_taux: commissionTaux, is_active: isActive });
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
    <Modal isOpen={isOpen} onClose={onClose} title={`Modifier ${link?.transaction_type_label ?? ''}`}>
      <form onSubmit={handleSubmit} className="space-y-5">
        {error && <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>}

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

        <label className="flex items-center gap-2 text-sm text-gray-700">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} className="rounded border-gray-300" />
          Association active
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
