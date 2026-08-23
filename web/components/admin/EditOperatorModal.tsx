'use client';

import React, { useEffect, useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { updateOperator, getCountries } from '@/lib/api';

interface Operator {
  id: number;
  country: number;
  name: string;
  logo: string | null;
  sms_sender: string;
  is_active: boolean;
}

interface CountryOption {
  id: number;
  name: string;
}

interface EditOperatorModalProps {
  isOpen: boolean;
  onClose: () => void;
  onUpdated: () => void;
  operator: Operator | null;
}

export default function EditOperatorModal({ isOpen, onClose, onUpdated, operator }: EditOperatorModalProps) {
  const [countries, setCountries] = useState<CountryOption[]>([]);
  const [countryId, setCountryId] = useState<number | ''>('');
  const [name, setName] = useState('');
  const [smsSender, setSmsSender] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [logo, setLogo] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isOpen) return;
    getCountries().then(setCountries).catch(() => setCountries([]));
  }, [isOpen]);

  useEffect(() => {
    if (operator) {
      setCountryId(operator.country);
      setName(operator.name);
      setSmsSender(operator.sms_sender);
      setIsActive(operator.is_active);
      setLogo(null);
    }
  }, [operator]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!operator || !countryId) return;
    setLoading(true);
    setError('');
    try {
      const form = new FormData();
      form.append('country', String(countryId));
      form.append('name', name);
      form.append('sms_sender', smsSender);
      form.append('is_active', String(isActive));
      if (logo) form.append('logo', logo);

      await updateOperator(operator.id, form);
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
    <Modal isOpen={isOpen} onClose={onClose} title={`Modifier ${operator?.name ?? ''}`}>
      <form onSubmit={handleSubmit} className="space-y-5">
        {error && <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Pays</label>
          <select
            value={countryId}
            onChange={(e) => setCountryId(e.target.value ? Number(e.target.value) : '')}
            required
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
          >
            <option value="">Sélectionner...</option>
            {countries.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        </div>

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
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Expéditeur SMS</label>
          <input
            type="text"
            value={smsSender}
            onChange={(e) => setSmsSender(e.target.value)}
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Nouveau logo (optionnel)</label>
          <input
            type="file"
            accept="image/*"
            onChange={(e) => setLogo(e.target.files?.[0] ?? null)}
            className="w-full text-sm text-gray-600 file:mr-4 file:py-2 file:px-4 file:rounded-xl file:border-0 file:bg-accent-50 file:text-accent file:font-medium"
          />
        </div>

        <label className="flex items-center gap-2 text-sm text-gray-700">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} className="rounded border-gray-300" />
          Opérateur actif (visible du mobile)
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
