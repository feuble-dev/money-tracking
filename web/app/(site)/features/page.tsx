import React from 'react';
import Link from 'next/link';
import Features from '@/components/site/Features';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Fonctionnalites - MoneyTracking',
  description: 'Decouvrez toutes les fonctionnalites de MoneyTracking pour la gestion de votre agence Mobile Money.',
};

const details = [
  {
    title: 'Detection SMS automatique',
    description:
      "L'application capte les SMS de confirmation d'Orange Money, Moov Money et Coris Money en arriere-plan. Elle extrait le montant, le numero du client, l'identifiant de transaction et le solde operateur.",
    points: [
      "Reconnaissance automatique de l'expediteur SMS",
      "Extraction des champs : montant, numero, ID transaction, solde",
      "Creation de la transaction en statut \"en attente\"",
      "Notification pour confirmer ou rejeter",
    ],
  },
  {
    title: 'Depot & Retrait via USSD',
    description:
      "Lancez les codes USSD depuis l'app. Le numero et montant sont pre-remplis. Le SMS de confirmation qui arrive cree la transaction automatiquement.",
    points: [
      "Composition automatique du code USSD",
      "Support des templates par operateur",
      "Le SMS de confirmation finalise la transaction",
      "Creation manuelle possible",
    ],
  },
  {
    title: 'Gestion clients avec CNIB',
    description:
      "Un annuaire de vos clients reguliers. Enregistrez prenom, nom, telephone et CNIB. Consultez l'historique des transactions par client.",
    points: [
      "Fiche client complete avec CNIB",
      "Historique des transactions par client",
      "Recherche par nom ou telephone",
      "Filtrage par operateur",
    ],
  },
  {
    title: 'Dashboard & statistiques',
    description:
      "Plus de 7 graphiques : evolution depots/retraits, ratio, volume quotidien, heures de pointe, repartition par operateur.",
    points: [
      "Filtres : aujourd'hui, 7j, 30j, 3 mois",
      "Onglets par operateur",
      "Indicateurs de tendance",
      "Vue globale et detaillee",
    ],
  },
  {
    title: 'Commissions automatiques',
    description:
      "Taux de commission configurables par operateur. Calcul automatique sur chaque transaction, suivi par jour, semaine ou mois.",
    points: [
      "Taux configurable depot/retrait",
      "Suivi par jour, semaine, mois",
      "Solde operateur extrait des SMS",
      "Vue globale et par operateur",
    ],
  },
  {
    title: 'Gestion de caisse',
    description:
      "Suivez le solde de chaque operateur. Seuil d'alerte configurable. Enregistrement des rechargements.",
    points: [
      "Solde en temps reel par operateur",
      "Alertes de solde bas",
      "Historique des rechargements",
      "Seuil d'alerte configurable",
    ],
  },
  {
    title: 'Export PDF & CSV',
    description:
      "Rapports PDF A4 paysage ou CSV Excel. Selection de la periode, partage via WhatsApp ou email.",
    points: [
      "PDF A4 paysage professionnel",
      "CSV compatible Excel",
      "Selection de la periode",
      "Partage direct",
    ],
  },
  {
    title: 'Securite PIN & biometrie',
    description:
      "Code PIN 4 chiffres stocke en hash securise et authentification biometrique. Verrouillage automatique configurable.",
    points: [
      "PIN avec hash securise",
      "Empreinte digitale",
      "Verrouillage automatique configurable",
      "Clavier numerique personnalise",
    ],
  },
  {
    title: 'Sauvegarde & restauration',
    description:
      "Sauvegardez en fichier .mmtbak. Les 7 dernieres sauvegardes conservees. Partage du fichier via WhatsApp, Drive, etc.",
    points: [
      "Format .mmtbak",
      "7 sauvegardes conservees",
      "Restauration en un clic",
      "Partage du fichier",
    ],
  },
];

export default function FeaturesPage() {
  return (
    <>
      {/* Header */}
      <section className="gradient-hero py-16">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <h1 className="text-3xl sm:text-4xl font-bold text-white">Fonctionnalites</h1>
          <p className="mt-3 text-blue-200 max-w-lg">
            Tout ce dont un agent Mobile Money a besoin pour automatiser sa gestion quotidienne.
          </p>
        </div>
      </section>

      {/* Grid resume */}
      <Features />

      {/* Details */}
      <section className="py-16 bg-soft">
        <div className="max-w-3xl mx-auto px-4 sm:px-6">
          <h2 className="text-2xl font-bold text-dark mb-10">En detail</h2>
          <div className="space-y-10">
            {details.map((d, i) => (
              <div key={i}>
                <h3 className="text-lg font-semibold text-dark mb-2">{d.title}</h3>
                <p className="text-sm text-muted leading-relaxed mb-3">{d.description}</p>
                <ul className="grid sm:grid-cols-2 gap-x-6 gap-y-1.5">
                  {d.points.map((p) => (
                    <li key={p} className="flex items-start gap-2 text-sm text-gray-600">
                      <svg className="w-4 h-4 text-green-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                      {p}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Stats */}
      <section className="py-14 bg-white border-t border-gray-100">
        <div className="max-w-4xl mx-auto px-4 sm:px-6">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-6 text-center">
            {[
              { value: '3', label: 'Operateurs' },
              { value: '7+', label: 'Graphiques' },
              { value: '100%', label: 'Hors ligne' },
              { value: '30j', label: 'Essai gratuit' },
            ].map((s) => (
              <div key={s.label}>
                <p className="text-2xl font-bold text-primary">{s.value}</p>
                <p className="text-xs text-muted mt-0.5">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 gradient-hero">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 text-center">
          <h2 className="text-2xl font-bold text-white mb-3">Pret a simplifier votre gestion ?</h2>
          <p className="text-blue-200 text-sm mb-6">Essai gratuit 30 jours. Toutes les fonctionnalites incluses.</p>
          <Link href="/download"
            className="inline-flex items-center gap-2 px-6 py-3 bg-accent text-white font-semibold text-sm rounded-lg hover:bg-accent-hover transition-colors">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Telecharger MoneyTracking
          </Link>
        </div>
      </section>
    </>
  );
}
