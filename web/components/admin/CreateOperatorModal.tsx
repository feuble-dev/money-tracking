'use client';

import React, { useEffect, useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { createOperator, getCountries } from '@/lib/api';

interface CreateOperatorModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreated: () => void;
  defaultCountryId?: number;
}

interface CountryOption {
  id: number;
  name: string;
}

export default function CreateOperatorModal({
  isOpen,
  onClose,
  onCreated,
  defaultCountryId,
}: CreateOperatorModalProps) {
  const [countries, setCountries] = useState<CountryOption[]>([]);
  const [countryId, setCountryId] = useState<number | ''>(defaultCountryId ?? '');
  const [name, setName] = useState('');
  const [smsSender, setSmsSender] = useState('');
  const [logo, setLogo] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isOpen) return;
    getCountries().then(setCountries).catch(() => setCountries([]));
    setCountryId(defaultCountryId ?? '');
  }, [isOpen, defaultCountryId]);

  const reset = () => {
    setName('');
    setSmsSender('');
    setLogo(null);
    setError('');
  };

  const handleClose = () => {
    reset();
    onClose();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!countryId) {
      setError('Sélectionnez un pays');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const form = new FormData();
      form.append('country', String(countryId));
      form.append('name', name);
      form.append('sms_sender', smsSender);
      // Les champs booléens absents d'un formulaire multipart sont traités
      // par DRF comme False (sémantique "checkbox non coché"), pas comme le
      // défaut du modèle — il faut donc l'envoyer explicitement.
      form.append('is_active', 'true');
      if (logo) form.append('logo', logo);

      await createOperator(form);
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
    <Modal isOpen={isOpen} onClose={handleClose} title="Ajouter un opérateur">
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
            placeholder="Orange Money"
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
            placeholder="OrangeMoney"
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Logo</label>
          <input
            type="file"
            accept="image/*"
            onChange={(e) => setLogo(e.target.files?.[0] ?? null)}
            className="w-full text-sm text-gray-600 file:mr-4 file:py-2 file:px-4 file:rounded-xl file:border-0 file:bg-accent-50 file:text-accent file:font-medium"
          />
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
