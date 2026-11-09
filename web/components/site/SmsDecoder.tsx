'use client';

import React, { useEffect, useState } from 'react';
import Icon from './Icon';

type Field = 'montant' | 'numero' | 'solde' | 'ref' | 'date' | 'beneficiaire';

interface Sample {
  operator: string;
  sender: string;
  /** Le SMS découpé en morceaux ; un morceau avec `f` est une information lue. */
  parts: { t: string; f?: Field }[];
  result: { title: string; subtitle: string; amount: string; incoming: boolean; motif: string };
}

const fieldInfo: Record<Field, { label: string; color: string; bg: string }> = {
  montant: { label: 'Montant', color: '#1565C0', bg: 'rgba(21,101,192,0.12)' },
  numero: { label: 'Numéro', color: '#2E7D32', bg: 'rgba(46,125,50,0.12)' },
  beneficiaire: { label: 'Bénéficiaire', color: '#2E7D32', bg: 'rgba(46,125,50,0.12)' },
  solde: { label: 'Nouveau solde', color: '#B4532A', bg: 'rgba(180,83,42,0.12)' },
  ref: { label: 'Référence', color: '#7C3AED', bg: 'rgba(124,58,237,0.10)' },
  date: { label: 'Date', color: '#0F766E', bg: 'rgba(15,118,110,0.10)' },
};

// Exemples écrits sur le modèle des vrais SMS des opérateurs (valeurs
// fictives).
const samples: Sample[] = [
  {
    operator: 'Orange Money',
    sender: 'OrangeMoney',
    parts: [
      { t: 'Transfert de ' }, { t: '25 000 FCFA', f: 'montant' }, { t: ' vers le ' }, { t: '76 54 32 10', f: 'numero' },
      { t: ' reussi. Frais : 0 FCFA. Nouveau solde : ' }, { t: '159 500 FCFA', f: 'solde' }, { t: '. Ref : ' },
      { t: 'CI241107.1532.A12345', f: 'ref' },
    ],
    result: { title: 'Envoi à 76 54 32 10', subtitle: 'Orange Money · Famille', amount: '− 25 000', incoming: false, motif: 'Famille' },
  },
  {
    operator: 'Moov Money',
    sender: 'MOOV',
    parts: [
      { t: 'Vous avez recu ' }, { t: '15 000,00 FCFA', f: 'montant' }, { t: ' du ' }, { t: '60 11 22 33', f: 'numero' },
      { t: ' le ' }, { t: '07/11/2026 14:02', f: 'date' }, { t: '. Votre solde est de ' }, { t: '199 500,00 FCFA', f: 'solde' },
      { t: '. Ref : ' }, { t: '0711202614023', f: 'ref' },
    ],
    result: { title: 'Reçu de 60 11 22 33', subtitle: 'Moov Money · Revenu', amount: '+ 15 000', incoming: true, motif: 'Revenu' },
  },
  {
    operator: 'Wave',
    sender: 'Wave',
    parts: [
      { t: 'Paiement de ' }, { t: '3 500 F', f: 'montant' }, { t: ' a ' }, { t: 'Pharmacie du Centre', f: 'beneficiaire' },
      { t: '. Nouveau solde : ' }, { t: '52 000 F', f: 'solde' }, { t: '.' },
    ],
    result: { title: 'Pharmacie du Centre', subtitle: 'Wave · Santé', amount: '− 3 500', incoming: false, motif: 'Santé' },
  },
  {
    operator: 'Coris Money',
    sender: 'CorisMoney',
    parts: [
      { t: 'Retrait de ' }, { t: '50 000 FCFA', f: 'montant' }, { t: ' effectue le ' }, { t: '07/11/2026', f: 'date' },
      { t: '. Solde disponible : ' }, { t: '250 000 FCFA', f: 'solde' }, { t: '. Trans ID : ' }, { t: 'CM78231', f: 'ref' },
    ],
    result: { title: 'Retrait d’espèces', subtitle: 'Coris Money · Vers mes espèces', amount: '− 50 000', incoming: false, motif: 'Entre mes comptes' },
  },
];

/**
 * Montre ce que fait l'application avec un SMS : chaque information est
 * repérée, puis l'opération apparaît rangée. Les informations s'allument
 * l'une après l'autre ; survoler un champ l'allume dans le SMS.
 */
export default function SmsDecoder() {
  const [index, setIndex] = useState(0);
  const [step, setStep] = useState(0);
  const [hover, setHover] = useState<Field | null>(null);
  const sample = samples[index];
  const fields = sample.parts.filter((p) => p.f) as { t: string; f: Field }[];

  // Lecture progressive : un champ toutes les 600 ms, puis la ligne.
  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setStep(fields.length + 1);
      return;
    }
    setStep(0);
    const t = setInterval(() => setStep((s) => (s > fields.length ? s : s + 1)), 600);
    return () => clearInterval(t);
  }, [index, fields.length]);

  let seen = 0;
  return (
    <div className="grid items-start gap-8 lg:grid-cols-[1.15fr_0.85fr]">
      <div>
        <div role="tablist" aria-label="Opérateur" className="flex flex-wrap gap-2">
          {samples.map((s, i) => (
            <button
              key={s.operator}
              role="tab"
              aria-selected={i === index}
              onClick={() => setIndex(i)}
              className={`rounded-full border px-3.5 py-1.5 text-sm font-medium transition-colors ${
                i === index ? 'border-ink bg-ink text-white' : 'border-gray-300 bg-white text-dark hover:border-gray-400'
              }`}
            >
              {s.operator}
            </button>
          ))}
        </div>

        {/* Le SMS tel qu'il arrive */}
        <div className="mt-6 rounded-[22px] rounded-tl-md border border-gray-200 bg-white p-5 shadow-sm">
          <p className="mb-2 text-xs font-semibold text-muted">{sample.sender} · SMS</p>
          <p className="font-mono text-[15px] leading-[1.9] text-dark">
            {sample.parts.map((p, i) => {
              if (!p.f) return <span key={i}>{p.t}</span>;
              const order = seen++;
              const lit = step > order || hover === p.f;
              const info = fieldInfo[p.f];
              return (
                <mark
                  key={i}
                  className="rounded px-0.5 text-inherit transition-[background-color,box-shadow] duration-300"
                  style={{
                    background: lit ? info.bg : 'transparent',
                    boxShadow: lit ? `inset 0 -2px 0 ${info.color}` : 'none',
                  }}
                >
                  {p.t}
                </mark>
              );
            })}
          </p>
        </div>

        <p className="mt-4 flex items-start gap-2 text-sm text-muted">
          <Icon name="lock" className="mt-0.5 h-4 w-4 flex-shrink-0" strokeWidth={1.8} />
          Lu sur votre téléphone, jamais envoyé ailleurs. Fonctionne sans Internet.
        </p>
      </div>

      {/* Ce que l'application en retient */}
      <div className="rounded-3xl bg-sand p-5 ring-1 ring-sand-deep">
        <p className="text-xs font-semibold uppercase tracking-wider text-clay">Ce que l&apos;application retient</p>
        <dl className="mt-4 space-y-2">
          {fields.map((f, i) => {
            const info = fieldInfo[f.f];
            const shown = step > i;
            return (
              <div
                key={`${index}-${i}`}
                onMouseEnter={() => setHover(f.f)}
                onMouseLeave={() => setHover(null)}
                className={`flex items-center justify-between gap-3 rounded-xl bg-white px-3 py-2 text-sm transition-all duration-300 ${
                  shown ? 'translate-y-0 opacity-100' : 'translate-y-1 opacity-0'
                }`}
              >
                <dt className="flex items-center gap-2 text-muted">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ background: info.color }} />
                  {info.label}
                </dt>
                <dd className="truncate font-mono text-[13px] font-semibold text-dark">{f.t}</dd>
              </div>
            );
          })}
        </dl>

        <div
          className={`mt-5 transition-all duration-500 ${
            step > fields.length ? 'translate-y-0 opacity-100' : 'translate-y-2 opacity-0'
          }`}
        >
          <p className="mb-2 text-xs font-semibold text-muted">Et dans l&apos;application :</p>
          <div className="flex items-center gap-3 rounded-2xl bg-white p-3 shadow-sm ring-1 ring-black/[0.04]">
            <span
              className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl ${
                sample.result.incoming ? 'bg-accent-50 text-accent' : 'bg-primary-50 text-primary'
              }`}
            >
              <Icon name={sample.result.incoming ? 'arrowDown' : 'arrowUp'} className="h-5 w-5" strokeWidth={2} />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-semibold text-dark">{sample.result.title}</span>
              <span className="block truncate text-xs text-muted">{sample.result.subtitle}</span>
            </span>
            <span className={`whitespace-nowrap font-bold tabular-nums ${sample.result.incoming ? 'text-accent' : 'text-dark'}`}>
              {sample.result.amount}
            </span>
          </div>
          <p className="mt-2 text-xs text-muted">
            Rangé dans « {sample.result.motif} » — le solde de {sample.operator} est mis à jour.
          </p>
        </div>
      </div>
    </div>
  );
}
