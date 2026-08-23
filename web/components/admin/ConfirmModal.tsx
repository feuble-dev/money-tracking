'use client';

import React, { useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';

interface ConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void>;
  title: string;
  message: string;
}

/// Confirmation de suppression générique — toutes les FK du catalogue sont
/// en RESTRICT (D-restrict), donc le backend peut renvoyer un 409 clair
/// si des éléments dépendent encore de celui qu'on essaie de supprimer.
export default function ConfirmModal({ isOpen, onClose, onConfirm, title, message }: ConfirmModalProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleConfirm = async () => {
    setLoading(true);
    setError('');
    try {
      await onConfirm();
      onClose();
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { erreur?: string } } };
      setError(axiosErr.response?.data?.erreur || 'Erreur lors de la suppression');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={title}>
      <div className="space-y-5">
        {error && <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>}
        <p className="text-sm text-gray-600">{message}</p>
        <div className="flex gap-3 pt-2">
          <Button type="button" variant="ghost" onClick={onClose} className="flex-1">
            Annuler
          </Button>
          <Button type="button" variant="danger" disabled={loading} onClick={handleConfirm} className="flex-1">
            {loading ? 'Suppression...' : 'Supprimer'}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
