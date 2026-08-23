'use client';

import React, { useEffect, useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { updateCountry } from '@/lib/api';

interface Country {
  id: number;
  code: string;
  name: string;
  dial_code: string;
  is_active: boolean;
}

interface EditCountryModalProps {
  isOpen: boolean;
  onClose: () => void;
  onUpdated: () => void;
  country: Country | null;
}

export default function EditCountryModal({ isOpen, onClose, onUpdated, country }: EditCountryModalProps) {
  const [name, setName] = useState('');
  const [dialCode, setDialCode] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (country) {
      setName(country.name);
      setDialCode(country.dial_code);
      setIsActive(country.is_active);
    }
  }, [country]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!country) return;
    setLoading(true);
    setError('');
    try {
      await updateCountry(country.id, { name, dial_code: dialCode, is_active: isActive });
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
    <Modal isOpen={isOpen} onClose={onClose} title={`Modifier ${country?.code ?? ''}`}>
      <form onSubmit={handleSubmit} className="space-y-5">
        {error && <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Nom</label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Indicatif</label>
          <input
            type="text"
            value={dialCode}
            onChange={(e) => setDialCode(e.target.value)}
            required
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <label className="flex items-center gap-2 text-sm text-gray-700">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} className="rounded border-gray-300" />
          Pays actif (visible du mobile)
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
