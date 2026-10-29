import React from 'react';
import Link from 'next/link';
import type { Metadata } from 'next';
import PageHeader from '@/components/site/PageHeader';
import Icon from '@/components/site/Icon';

export const metadata: Metadata = {
  title: 'Guide d’utilisation',
  description: 'Bien démarrer avec MoneyTracking : installation, détection des SMS, Mon argent, budget, agences, licence et sécurité.',
};

interface Doc {
  id: string;
  title: string;
  intro: string;
  items: { title: string; text: string }[];
  note?: string;
}

const docs: Doc[] = [
  {
    id: 'installation',
    title: 'Bien démarrer',
    intro: 'Cinq minutes suffisent pour que vos prochains SMS soient rangés automatiquement.',
    items: [
      { title: 'Installer l’application', text: 'Téléchargez l’APK depuis la page Télécharger (Android 6 ou plus) et autorisez l’installation.' },
      { title: 'Choisir votre usage', text: '« Pour moi » pour suivre votre argent personnel (gratuit), « Pour mon agence » pour une activité d’agent Mobile Money (3 mois offerts).' },
      { title: 'Créer votre compte', text: 'Votre numéro et un mot de passe : ils vous permettront de retrouver votre compte sur un autre téléphone.' },
      { title: 'Cocher vos opérateurs', text: 'Les opérateurs de votre pays sont déjà configurés : cochez ceux que vous utilisez.' },
      { title: 'Autoriser la lecture des SMS', text: 'Indispensable pour la détection. Les SMS sont lus sur votre téléphone et ne sont jamais envoyés ailleurs.' },
    ],
  },
  {
    id: 'detection',
    title: 'Détection des SMS',
    intro: 'Chaque SMS de votre opérateur est comparé aux modèles connus pour devenir une opération.',
    items: [
      { title: 'Automatique, même application fermée', text: 'La détection continue après un redémarrage du téléphone. Les SMS reçus pendant une coupure sont rattrapés à l’ouverture suivante.' },
      { title: 'Détection incertaine', text: 'Si un SMS ressemble à un modèle sans lui correspondre exactement, l’opération est créée « à vérifier » : confirmez-la ou corrigez son type.' },
      { title: 'Vérifier un SMS', text: 'Paramètres → Diagnostic → Tester un SMS : collez un message pour voir comment il est compris.' },
    ],
    note: 'Un téléphone Tecno, Infinix, Xiaomi ou Samsung peut arrêter l’application pour économiser la batterie. Paramètres → Diagnostic → Fonctionnement en arrière-plan règle ce point en un geste.',
  },
  {
    id: 'mon-argent',
    title: 'Mon argent (particuliers)',
    intro: 'Mobile Money, espèces, banque, épargne : tout votre argent au même endroit.',
    items: [
      { title: 'Ajouter un compte', text: 'Mon argent → Nouveau compte : espèces, banque, tontine… avec ce qu’il contient aujourd’hui.' },
      { title: 'Ajouter une dépense ou un revenu', text: 'Le bouton Ajouter : le montant, le compte, le motif. La date et une note sont facultatives.' },
      { title: 'Virement entre vos comptes', text: 'Un retrait Mobile Money vers vos espèces ? Faites un Virement : il est rapproché du SMS et n’est compté ni comme une dépense ni comme un revenu.' },
    ],
  },
  {
    id: 'budget',
    title: 'Motifs et budget',
    intro: 'Comprendre où part votre argent, sans y passer du temps.',
    items: [
      { title: 'Catégoriser en un geste', text: 'Une dépense non rangée ? La notification propose « Catégoriser ». Cochez « toujours ranger ici » et ce numéro sera rangé tout seul la prochaine fois.' },
      { title: 'Fixer un budget', text: 'Onglet Budget : un plafond mensuel par motif, une alerte à 80 % et au dépassement.' },
      { title: 'Bilan du mois', text: 'Au début de chaque mois, un résumé : total dépensé, évolution, premier poste de dépense.' },
    ],
  },
  {
    id: 'agence',
    title: 'Agences : commissions et caisse',
    intro: 'Tout ce qu’un agent Mobile Money suit au quotidien.',
    items: [
      { title: 'Commissions', text: 'Un taux par opérateur et par type d’opération ; le total du jour, de la semaine et du mois est toujours à jour.' },
      { title: 'Caisse et float', text: 'Le solde de chaque puce vient du dernier SMS de l’opérateur. Définissez un seuil d’alerte pour être prévenu à temps.' },
      { title: 'Lancer une opération USSD', text: 'Le bouton + : opérateur, type, numéro (ou un contact), montant. Le code est composé, le SMS de confirmation crée l’opération.' },
    ],
  },
  {
    id: 'multi-agence',
    title: 'Plusieurs agences, plusieurs téléphones',
    intro: 'Le patron voit tout, chaque agent travaille depuis son téléphone.',
    items: [
      { title: 'Rattacher un agent', text: 'À l’installation, l’agent choisit « Rejoindre » et saisit votre numéro. Vous approuvez depuis Mes agences et choisissez son agence.' },
      { title: 'Suivre vos agences', text: 'Mes agences montre le détail de chaque agence, mis à jour en continu dès que l’agent a du réseau.' },
      { title: 'Particulier avec deux puces', text: 'Sur le second téléphone, choisissez « J’ai déjà un compte » : Mes téléphones réunit les deux.' },
    ],
  },
  {
    id: 'licence',
    title: 'Licence d’agence',
    intro: 'Une licence par agence, payée par Mobile Money.',
    items: [
      { title: 'Payer en ligne', text: 'Licence → Renouveler : choisissez la durée, envoyez le montant indiqué, l’activation arrive dès la validation.' },
      { title: 'Activer avec une clé', text: 'Nous pouvons vous envoyer une clé (elle commence par MT2-). Copiez-la puis collez-la : elle fonctionne même sans Internet.' },
      { title: 'Licence expirée', text: 'Vos données restent consultables, et les SMS reçus sont mis de côté : ils deviennent des opérations dès le renouvellement.' },
    ],
  },
  {
    id: 'securite',
    title: 'Sécurité et sauvegardes',
    intro: 'Vos données sont sur votre téléphone : protégez-les.',
    items: [
      { title: 'Code PIN et empreinte', text: 'Le code PIN protège l’ouverture de l’application. Après 5 erreurs, il est bloqué quelques instants.' },
      { title: 'Sauvegarde chiffrée', text: 'Paramètres → Sauvegarde : choisissez un mot de passe. Le fichier peut être envoyé sur WhatsApp ou Drive sans risque : il est illisible sans le mot de passe.' },
      { title: 'Changer de téléphone', text: 'Reconnectez-vous avec votre numéro et votre mot de passe, ou restaurez une sauvegarde.' },
    ],
    note: 'Sans le mot de passe d’une sauvegarde, personne ne peut la restaurer — pas même nous. Notez-le en lieu sûr.',
  },
];

export default function DocsPage() {
  return (
    <>
      <PageHeader
        eyebrow="Aide"
        title="Guide d’utilisation"
        text="Les réponses aux questions courantes, de l’installation à la licence d’agence."
      />
      <section className="bg-white py-16">
        <div className="mx-auto grid max-w-6xl gap-12 px-4 sm:px-6 lg:grid-cols-[220px_1fr]">
          <nav aria-label="Sommaire" className="lg:sticky lg:top-24 lg:self-start">
            <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted">Sommaire</p>
            <ul className="flex flex-wrap gap-2 lg:block lg:space-y-1">
              {docs.map((d) => (
                <li key={d.id}>
                  <a
                    href={`#${d.id}`}
                    className="block rounded-lg px-3 py-1.5 text-sm text-muted transition-colors hover:bg-soft hover:text-ink"
                  >
                    {d.title}
                  </a>
                </li>
              ))}
            </ul>
          </nav>

          <div className="space-y-16">
            {docs.map((d) => (
              <article key={d.id} id={d.id} className="scroll-mt-24">
                <h2 className="font-display text-2xl font-bold text-ink sm:text-3xl">{d.title}</h2>
                <p className="mt-2 text-muted">{d.intro}</p>
                <ol className="mt-6 space-y-4">
                  {d.items.map((it, i) => (
                    <li key={it.title} className="flex gap-4 rounded-2xl border border-gray-200 p-5">
                      <span className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-primary-50 text-xs font-bold text-primary">
                        {i + 1}
                      </span>
                      <div>
                        <p className="font-semibold text-ink">{it.title}</p>
                        <p className="mt-1 leading-relaxed text-muted">{it.text}</p>
                      </div>
                    </li>
                  ))}
                </ol>
                {d.note && (
                  <p className="mt-4 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm leading-relaxed text-amber-900">
                    {d.note}
                  </p>
                )}
              </article>
            ))}

            <div className="rounded-3xl bg-ink p-8 text-center sm:p-10">
              <p className="font-display text-2xl font-bold text-white">Une question sans réponse ?</p>
              <p className="mt-2 text-white/70">Écrivez-nous, nous répondons aussi sur WhatsApp.</p>
              <div className="mt-6 flex flex-col justify-center gap-3 sm:flex-row">
                <a
                  href="mailto:contact@rftech-bf.com"
                  className="rounded-xl bg-white px-5 py-3 text-sm font-semibold text-ink transition-colors hover:bg-primary-50"
                >
                  Nous écrire
                </a>
                <Link
                  href="/download"
                  className="inline-flex items-center justify-center gap-2 rounded-xl border border-white/20 px-5 py-3 text-sm font-semibold text-white transition-colors hover:bg-white/10"
                >
                  <Icon name="download" className="h-4 w-4" strokeWidth={2} />
                  Télécharger l’application
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
