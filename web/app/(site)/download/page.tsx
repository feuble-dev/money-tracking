import React from 'react';
import Image from 'next/image';
import type { Metadata } from 'next';
import PageHeader from '@/components/site/PageHeader';
import Icon from '@/components/site/Icon';
import Reveal from '@/components/site/motion/Reveal';

export const metadata: Metadata = {
  title: 'Télécharger',
  description: 'Téléchargez MoneyTracking pour Android : gratuit pour les particuliers, 3 mois offerts aux agences.',
};

// URL du fichier APK publié — à définir au déploiement.
const APK_URL = process.env.NEXT_PUBLIC_APK_URL || '/downloads/moneytracking.apk';
const VERSION = process.env.NEXT_PUBLIC_APP_VERSION || '1.2.0';

const steps = [
  { title: 'Téléchargez le fichier', text: 'Appuyez sur le bouton depuis votre téléphone Android.' },
  {
    title: 'Autorisez l’installation',
    text: 'Android vous demande d’autoriser votre navigateur à installer des applications : acceptez pour celle-ci.',
  },
  { title: 'Ouvrez MoneyTracking', text: 'Choisissez « Pour moi » ou « Pour mon agence », puis créez votre code PIN.' },
];

const requirements = [
  { label: 'Android', value: '6.0 ou plus récent' },
  { label: 'Espace', value: 'Environ 60 Mo' },
  { label: 'Permission', value: 'Lecture des SMS (sur le téléphone uniquement)' },
  { label: 'Internet', value: 'Seulement pour créer le compte et synchroniser' },
];

const versions = [
  {
    v: '1.2.0',
    date: 'Octobre 2026',
    text: '« Mon argent » : espèces, banque et épargne avec le Mobile Money ; compte Particulier gratuit ; sauvegardes chiffrées ; clés de licence hors ligne sécurisées ; SMS reçus pendant une licence expirée récupérés.',
  },
  {
    v: '1.1.0',
    date: 'Avril 2026',
    text: 'Import de l’historique SMS, notifications, confirmation avancée, filtre des commissions par opérateur.',
  },
  {
    v: '1.0.0',
    date: 'Mars 2026',
    text: 'Version initiale : détection SMS, USSD, tableau de bord, commissions, caisse, exports, PIN et empreinte.',
  },
];

export default function DownloadPage() {
  return (
    <>
      <PageHeader
        eyebrow="Télécharger"
        title="MoneyTracking pour Android"
        text="Gratuit pour les particuliers. 3 mois offerts pour chaque agence."
      >
        <div className="mt-9 flex flex-col items-start gap-4 sm:flex-row sm:items-center">
          <a
            href={APK_URL}
            className="inline-flex items-center gap-3 rounded-xl bg-accent px-7 py-4 font-semibold text-white transition-colors hover:bg-accent-hover"
          >
            <Icon name="download" strokeWidth={2} />
            Télécharger la version {VERSION}
          </a>
          <span className="text-sm text-muted">Fichier APK · Android uniquement · ~60 Mo</span>
        </div>
      </PageHeader>

      <section id="installation" className="bg-white py-20">
        <div className="mx-auto grid max-w-6xl gap-12 px-4 sm:px-6 lg:grid-cols-2">
          <div>
            <h2 className="font-display text-3xl font-bold text-ink">Installer en 3 étapes</h2>
            <ol className="mt-8 space-y-7">
              {steps.map((s, i) => (
                <Reveal as="li" key={s.title} delay={i * 100} className="flex gap-4">
                  <span className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full bg-ink font-display text-sm font-bold text-white">
                    {i + 1}
                  </span>
                  <div>
                    <p className="font-display text-lg font-semibold text-ink">{s.title}</p>
                    <p className="mt-1 text-muted">{s.text}</p>
                  </div>
                </Reveal>
              ))}
            </ol>
          </div>
          <div className="grid content-start gap-3 sm:grid-cols-2">
            {requirements.map((r, i) => (
              <Reveal key={r.label} delay={i * 70} className="rounded-2xl border border-gray-200 bg-soft p-5">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted">{r.label}</p>
                <p className="mt-1 font-medium text-ink">{r.value}</p>
              </Reveal>
            ))}
            <Reveal className="flex items-center gap-4 rounded-2xl border border-dashed border-gray-300 p-5 sm:col-span-2">
              <Image src="/logo.png" alt="" width={44} height={44} className="rounded-xl" />
              <p className="text-sm text-muted">
                Bientôt sur Google Play. En attendant, l’APK officiel est toujours disponible ici.
              </p>
            </Reveal>
          </div>
        </div>
      </section>

      <section className="bg-soft py-20">
        <div className="mx-auto max-w-3xl px-4 sm:px-6">
          <h2 className="font-display text-3xl font-bold text-ink">Nouveautés</h2>
          <ol className="relative mt-10 space-y-8 border-l border-gray-300 pl-8">
            {versions.map((v, i) => (
              <Reveal as="li" key={v.v} delay={i * 90} className="relative">
                <span
                  className={`absolute -left-[37px] top-1 h-4 w-4 rounded-full ring-4 ring-soft ${
                    i === 0 ? 'bg-accent' : 'bg-gray-300'
                  }`}
                />
                <p className="flex items-center gap-3">
                  <span className="font-display text-lg font-bold text-ink">Version {v.v}</span>
                  <span className="text-sm text-muted">{v.date}</span>
                </p>
                <p className="mt-2 leading-relaxed text-muted">{v.text}</p>
              </Reveal>
            ))}
          </ol>
        </div>
      </section>
    </>
  );
}
