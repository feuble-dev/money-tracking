import React from 'react';
import type { Metadata } from 'next';
import PageHeader from '@/components/site/PageHeader';

export const metadata: Metadata = {
  title: 'Politique de confidentialité',
  description:
    'Ce que MoneyTracking lit, ce qui reste sur votre téléphone, ce qui est envoyé à nos serveurs, et comment supprimer votre compte.',
};

const CONTACT = 'contact@rftech-bf.com';
const UPDATED = '13 novembre 2026';

interface Section {
  id: string;
  title: string;
  body: React.ReactNode;
}

const sections: Section[] = [
  {
    id: 'resume',
    title: 'En résumé',
    body: (
      <ul>
        <li>L’application lit les SMS de vos opérateurs Mobile Money <strong>sur votre téléphone</strong> pour créer vos opérations. Le texte de vos SMS n’est jamais envoyé à nos serveurs.</li>
        <li>Les SMS qui ne viennent pas d’un opérateur que vous avez choisi (messages personnels, codes de banque…) ne sont ni enregistrés ni conservés.</li>
        <li>Compte Particulier : vos opérations, vos dépenses, vos motifs et votre budget restent sur votre téléphone.</li>
        <li>Compte Agence : les opérations de l’agence sont envoyées à nos serveurs pour que le patron de l’agence puisse les consulter.</li>
        <li>Pas de publicité, pas d’outil de suivi, aucune donnée vendue ou partagée à des fins commerciales.</li>
      </ul>
    ),
  },
  {
    id: 'sms',
    title: 'Lecture des SMS',
    body: (
      <>
        <p>
          La fonction principale de MoneyTracking est de transformer les SMS de confirmation de vos opérateurs Mobile
          Money (Orange Money, Moov Money, Coris Money, Wave…) en opérations : montant, numéro, référence, solde.
          Pour cela, l’application demande l’autorisation de recevoir et de lire les SMS.
        </p>
        <ul>
          <li>L’analyse se fait entièrement sur le téléphone, même sans connexion Internet.</li>
          <li>Seuls les SMS dont l’expéditeur correspond à un opérateur que vous avez activé sont traités et conservés dans l’application.</li>
          <li>Les autres SMS sont ignorés : ils ne sont ni enregistrés, ni transmis.</li>
          <li>« Récupérer mes anciens SMS » lit, à votre demande, les SMS déjà reçus de ces mêmes opérateurs.</li>
        </ul>
        <p>Vous pouvez retirer cette autorisation à tout moment dans les réglages d’Android ; la détection automatique s’arrête alors.</p>
      </>
    ),
  },
  {
    id: 'donnees',
    title: 'Données envoyées à nos serveurs',
    body: (
      <>
        <p><strong>Pour tous les comptes :</strong></p>
        <ul>
          <li>votre numéro de téléphone et le type de compte (Particulier ou Agence) ;</li>
          <li>votre mot de passe, conservé uniquement sous forme chiffrée irréversible ;</li>
          <li>un identifiant d’installation propre à l’application, pour reconnaître vos téléphones autorisés ;</li>
          <li>l’état de votre licence et, pour une agence, les demandes de paiement de licence.</li>
        </ul>
        <p><strong>Pour un compte Agence uniquement</strong> (synchronisation avec le patron de l’agence) :</p>
        <ul>
          <li>les opérations de l’agence : opérateur, type, montant, commission, statut, date, numéro et nom du client ;</li>
          <li>le fichier clients de l’agence : nom, prénom, numéro de téléphone ;</li>
          <li>les rechargements de float.</li>
        </ul>
        <p>
          Ces données d’agence ne sont visibles que par le titulaire du compte de l’agence. Un compte Particulier
          n’envoie aucune opération à nos serveurs.
        </p>
      </>
    ),
  },
  {
    id: 'local',
    title: 'Données qui restent sur votre téléphone',
    body: (
      <ul>
        <li>le texte des SMS de vos opérateurs et les opérations qui en sont tirées ;</li>
        <li>vos comptes « Mon argent » (espèces, banque, épargne), vos dépenses, motifs, règles et budgets ;</li>
        <li>votre code PIN (conservé sous forme chiffrée) et votre choix d’utiliser l’empreinte — l’empreinte elle-même est gérée par Android, l’application n’y a pas accès ;</li>
        <li>vos sauvegardes : elles sont chiffrées avec le mot de passe que vous choisissez. Sans ce mot de passe, personne ne peut les lire, pas même nous.</li>
      </ul>
    ),
  },
  {
    id: 'autorisations',
    title: 'Autres autorisations',
    body: (
      <ul>
        <li><strong>Téléphone (appels)</strong> : pour composer un code USSD à votre demande. Aucun appel n’est passé sans votre action.</li>
        <li><strong>Contacts</strong> : uniquement quand vous touchez « choisir un contact » pour remplir un numéro. Votre répertoire n’est ni copié ni envoyé.</li>
        <li><strong>Notifications</strong> : pour vous prévenir d’une opération détectée, d’un float bas ou d’un bilan.</li>
        <li><strong>Fonctionnement en arrière-plan</strong> : pour que la détection continue quand l’application est fermée, sur les téléphones qui arrêtent les applications pour économiser la batterie. Demandé seulement si vous le choisissez.</li>
        <li><strong>Empreinte digitale</strong> : pour déverrouiller l’application, si vous l’activez.</li>
      </ul>
    ),
  },
  {
    id: 'partage',
    title: 'Partage et conservation',
    body: (
      <>
        <p>
          Nous ne vendons aucune donnée et n’en partageons pas avec des annonceurs. L’application ne contient ni
          publicité ni outil de mesure d’audience. Les données de compte sont hébergées sur nos serveurs et
          transmises par connexion chiffrée (HTTPS).
        </p>
        <p>
          Les données sont conservées tant que votre compte existe. Elles peuvent être communiquées aux autorités
          uniquement lorsque la loi l’exige.
        </p>
      </>
    ),
  },
  {
    id: 'suppression',
    title: 'Supprimer mon compte et mes données',
    body: (
      <>
        <p>
          <strong>Depuis l’application</strong> : Paramètres → Mon compte → « Supprimer mon compte ». Le compte, ses
          agences, ses licences, ses téléphones autorisés et les opérations synchronisées sont effacés de nos
          serveurs immédiatement, puis toutes les données de l’application sont effacées du téléphone. Les
          paiements de licence déjà validés sont conservés pour notre comptabilité, sans numéro ni lien avec le
          compte.
        </p>
        <p>
          Vous n’avez plus accès à l’application ? Écrivez-nous à{' '}
          <a href={`mailto:${CONTACT}?subject=Suppression%20de%20mon%20compte%20MoneyTracking`}>{CONTACT}</a> depuis
          l’adresse de votre choix, en indiquant le numéro de téléphone du compte. Nous vérifions que la demande
          vient bien du titulaire, puis supprimons le compte, ses agences, ses licences, ses téléphones autorisés et
          les opérations synchronisées, sous 30 jours.
        </p>
        <p>
          Les données enregistrées sur votre téléphone s’effacent en désinstallant l’application (ou depuis les
          réglages d’Android : Applications → MoneyTracking → Stockage → Effacer les données).
        </p>
      </>
    ),
  },
  {
    id: 'contact',
    title: 'Nous contacter',
    body: (
      <p>
        MoneyTracking est édité par FEUBLE-TechBuilder, Ouagadougou, Burkina Faso. Pour toute question sur vos
        données : <a href={`mailto:${CONTACT}`}>{CONTACT}</a>. Cette politique peut évoluer avec l’application ;
        la date de mise à jour figure en haut de la page.
      </p>
    ),
  },
];

export default function ConfidentialitePage() {
  return (
    <>
      <PageHeader
        eyebrow="Vos données"
        title="Politique de confidentialité"
        text={`Ce que l’application lit, ce qui reste sur votre téléphone, et ce qui nous est envoyé. Mise à jour le ${UPDATED}.`}
      />
      <section className="bg-white py-16">
        <div className="mx-auto grid max-w-6xl gap-12 px-4 sm:px-6 lg:grid-cols-[220px_1fr]">
          <nav aria-label="Sommaire" className="lg:sticky lg:top-24 lg:self-start">
            <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted">Sommaire</p>
            <ul className="flex flex-wrap gap-2 lg:block lg:space-y-1">
              {sections.map((s) => (
                <li key={s.id}>
                  <a href={`#${s.id}`} className="block rounded-lg px-3 py-1.5 text-sm text-muted transition-colors hover:bg-soft hover:text-ink">
                    {s.title}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
          <div className="max-w-2xl space-y-12">
            {sections.map((s) => (
              <article
                key={s.id}
                id={s.id}
                className="scroll-mt-24 [&_a]:font-medium [&_a]:text-primary [&_a]:underline [&_li]:mt-2 [&_p]:mt-3 [&_p]:leading-relaxed [&_ul]:mt-3 [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:leading-relaxed"
              >
                <h2 className="font-display text-2xl font-bold text-ink">{s.title}</h2>
                <div className="text-dark/90">{s.body}</div>
              </article>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
