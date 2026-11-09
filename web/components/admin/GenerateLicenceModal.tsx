'use client';

import React, { useEffect, useState } from 'react';
import Modal from '@/components/ui/Modal';
import Button from '@/components/ui/Button';
import Field, { FormError, inputCls } from '@/components/admin/ui/Field';
import CopyField from '@/components/admin/ui/CopyField';
import { genererLicence, getAgences, getPricingTiers } from '@/lib/api';
import { apiError } from '@/lib/admin-types';
import { fcfa } from '@/lib/format';

interface AgenceOption {
  id: number;
  nom: string;
  telephone_client: string;
  account_type: 'particulier' | 'agence';
}

interface TierOption {
  id: number;
  duree_mois: number;
  montant: number;
  is_essai: boolean;
}

/**
 * Licence payée hors application (ex. paiement reçu en direct) : l'admin
 * choisit l'agence et la durée, et transmet la clé MT2 à l'agent, qui la
 * colle dans l'app (elle fonctionne même hors ligne).
 */
export default function GenerateLicenceModal({
  isOpen,
  onClose,
  onGenerated,
  agenceId: presetAgence,
}: {
  isOpen: boolean;
  onClose: () => void;
  onGenerated: () => void;
  /** Agence présélectionnée (depuis une fiche client). */
  agenceId?: number;
}) {
  const [agences, setAgences] = useState<AgenceOption[]>([]);
  const [tiers, setTiers] = useState<TierOption[]>([]);
  const [agenceId, setAgenceId] = useState<number | ''>('');
  const [dureeMois, setDureeMois] = useState(1);
  const [montant, setMontant] = useState(450);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<{ cle: string; date_fin: string } | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isOpen) return;
    setAgenceId(presetAgence ?? '');
    (async () => {
      try {
        const [agencesData, tiersData] = await Promise.all([getAgences(), getPricingTiers()]);
        // Un Particulier est gratuit : son agence cachée n'a pas de licence à vendre.
        setAgences((agencesData as AgenceOption[]).filter((a) => a.account_type !== 'particulier'));
        const payants = (tiersData as TierOption[]).filter((t) => !t.is_essai);
        setTiers(payants);
        if (payants.length > 0) {
          setDureeMois(payants[0].duree_mois);
          setMontant(payants[0].montant);
        }
      } catch (e) {
        setError(apiError(e, 'Impossible de charger les agences et les tarifs'));
      }
    })();
  }, [isOpen, presetAgence]);

  const onDuree = (value: number) => {
    setDureeMois(value);
    const tier = tiers.find((t) => t.duree_mois === value);
    if (tier) setMontant(tier.montant);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!agenceId) return setError('Choisissez une agence');
    setLoading(true);
    setError('');
    try {
      const r = await genererLicence({ agence_id: Number(agenceId), duree_mois: dureeMois, montant_paye: montant });
      setResult({ cle: r.cle_hors_ligne || r.code, date_fin: r.date_fin });
      onGenerated();
    } catch (err) {
      setError(apiError(err, 'La génération a échoué'));
    } finally {
      setLoading(false);
    }
  };

  const close = () => {
    setResult(null);
    setError('');
    onClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={close}
      title={result ? 'Licence créée' : 'Nouvelle licence'}
      description={result ? undefined : 'Pour un paiement reçu en dehors de l’application.'}
    >
      {result ? (
        <div className="space-y-5">
          <p className="text-sm text-muted">
            Valable jusqu’au <span className="font-semibold text-ink">{new Date(result.date_fin).toLocaleDateString('fr-FR')}</span>.
            Envoyez cette clé à l’agent : il la colle dans Licence → Activer avec une clé.
          </p>
          <CopyField label="Clé d’activation" value={result.cle} />
          <Button onClick={close} className="w-full">Terminé</Button>
        </div>
      ) : (
        <form onSubmit={submit} className="space-y-4">
          <FormError>{error}</FormError>
          <Field label="Agence" hint="La licence est attachée à l’agence et à son téléphone actuel.">
            <select
              value={agenceId}
              onChange={(e) => setAgenceId(e.target.value ? Number(e.target.value) : '')}
              className={inputCls}
              required
            >
              <option value="">Choisir une agence…</option>
              {agences.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.nom} — {a.telephone_client}
                </option>
              ))}
            </select>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Durée">
              <select value={dureeMois} onChange={(e) => onDuree(Number(e.target.value))} className={inputCls}>
                {tiers.map((t) => (
                  <option key={t.id} value={t.duree_mois}>
                    {t.duree_mois} mois — {fcfa(t.montant)}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Montant reçu (FCFA)">
              <input type="number" min={0} value={montant} onChange={(e) => setMontant(Number(e.target.value))} className={inputCls} />
            </Field>
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="ghost" onClick={close}>Annuler</Button>
            <Button type="submit" loading={loading}>Créer la licence</Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
