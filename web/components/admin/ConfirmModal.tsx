'use client';

import React, { useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { FormError } from '@/components/admin/ui/Field';
import { apiError } from '@/lib/admin-types';

interface ConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void>;
  title: string;
  message: React.ReactNode;
  /** Libellé du bouton de confirmation (« Supprimer » par défaut). */
  confirmLabel?: string;
}

/// Confirmation d'une action destructive. Pour le catalogue, toutes les FK
/// sont en RESTRICT (D12) : le backend renvoie un 409 avec un message clair
/// si des éléments dépendent encore de celui qu'on supprime, affiché tel quel.
export default function ConfirmModal({ isOpen, onClose, onConfirm, title, message, confirmLabel = 'Supprimer' }: ConfirmModalProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const close = () => {
    setError('');
    onClose();
  };

  const confirm = async () => {
    setLoading(true);
    setError('');
    try {
      await onConfirm();
      close();
    } catch (err) {
      setError(apiError(err, 'L’opération a échoué'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={close} title={title}>
      <div className="space-y-5">
        <FormError>{error}</FormError>
        <div className="text-sm leading-relaxed text-gray-600">{message}</div>
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" onClick={close}>Annuler</Button>
          <Button type="button" variant="danger" loading={loading} onClick={confirm}>{confirmLabel}</Button>
        </div>
      </div>
    </Modal>
  );
}
