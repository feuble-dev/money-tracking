'use client';

import React, { useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import { genererLicence } from '@/lib/api';

interface GenerateLicenceModalProps {
  isOpen: boolean;
  onClose: () => void;
  onGenerated: () => void;
}

export default function GenerateLicenceModal({
  isOpen,
  onClose,
  onGenerated,
}: GenerateLicenceModalProps) {
  const [telephone, setTelephone] = useState('');
  const [deviceId, setDeviceId] = useState('');
  const [duree, setDuree] = useState('mensuel');
  const [montant, setMontant] = useState(1000);
  const [loading, setLoading] = useState(false);
  const [generatedCode, setGeneratedCode] = useState('');
  const [error, setError] = useState('');

  const dureeOptions = [
    { value: 'essai', label: 'Essai gratuit (30 jours)', montant: 0 },
    { value: 'mensuel', label: 'Mensuel', montant: 1000 },
    { value: 'annuel', label: 'Annuel', montant: 10000 },
  ];

  const handleDureeChange = (value: string) => {
    setDuree(value);
    const option = dureeOptions.find((o) => o.value === value);
    if (option) setMontant(option.montant);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const result = await genererLicence({
        telephone,
        device_id: deviceId,
        duree,
        montant,
      });
      setGeneratedCode(result.code || result.licence_key || 'XXXX-XXXX-XXXX');
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : 'Erreur lors de la génération';
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    if (generatedCode) {
      onGenerated();
    }
    setTelephone('');
    setDeviceId('');
    setDuree('mensuel');
    setMontant(1000);
    setGeneratedCode('');
    setError('');
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Générer une licence">
      {generatedCode ? (
        <div className="text-center py-4">
          <div className="w-16 h-16 bg-green-100 text-green-600 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h3 className="text-lg font-bold text-dark mb-2">Licence générée avec succès</h3>
          <div className="bg-soft rounded-xl p-4 mb-4">
            <p className="text-xs text-gray-500 mb-1">Code licence</p>
            <p className="text-2xl font-mono font-bold text-primary tracking-wider">{generatedCode}</p>
          </div>
          <p className="text-sm text-gray-500 mb-6">
            Communiquez ce code au client pour activer sa licence.
          </p>
          <Button variant="primary" onClick={handleClose} className="w-full">
            Fermer
          </Button>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-5">
          {error && (
            <div className="p-3 bg-red-50 text-red-700 text-sm rounded-xl">{error}</div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">Téléphone</label>
            <input
              type="tel"
              value={telephone}
              onChange={(e) => setTelephone(e.target.value)}
              placeholder="+226 70 00 00 00"
              required
              className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">Device ID</label>
            <input
              type="text"
              value={deviceId}
              onChange={(e) => setDeviceId(e.target.value)}
              placeholder="Identifiant de l'appareil"
              required
              className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">Durée</label>
            <select
              value={duree}
              onChange={(e) => handleDureeChange(e.target.value)}
              className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm bg-white"
            >
              {dureeOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">Montant (FCFA)</label>
            <input
              type="number"
              value={montant}
              onChange={(e) => setMontant(Number(e.target.value))}
              className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm"
            />
          </div>

          <div className="flex gap-3 pt-2">
            <Button type="button" variant="ghost" onClick={handleClose} className="flex-1">
              Annuler
            </Button>
            <Button type="submit" variant="primary" disabled={loading} className="flex-1">
              {loading ? 'Génération...' : 'Générer'}
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
