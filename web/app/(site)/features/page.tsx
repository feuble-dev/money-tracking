import React from 'react';
import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Fonctionnalites - MoneyTracking',
  description: 'Decouvrez toutes les fonctionnalites de MoneyTracking pour la gestion de votre agence Mobile Money.',
};

const features = [
  {
    emoji: '📨',
    title: 'Detection SMS automatique',
    description:
      "L'application capte automatiquement les SMS de confirmation d'Orange Money, Moov Money et Coris Money. Elle extrait intelligemment le montant, le numero du client, l'identifiant de transaction et votre solde operateur.",
    details: [
      "Reconnaissance automatique de l'expediteur SMS de chaque operateur",
      "Extraction des champs : montant, numero client, ID transaction, solde",
      "Creation automatique de la transaction en statut \"en attente\"",
      "Notification pour confirmer ou rejeter chaque transaction detectee",
    ],
    gradient: 'from-blue-500 to-blue-700',
  },
  {
    emoji: '📱',
    title: 'Depot & Retrait via USSD',
    description:
      "Lancez les codes USSD directement depuis l'application. Pour un depot, MoneyTracking compose automatiquement *144*{numero}*{montant}# sur l'operateur selectionne. Le SMS de confirmation qui arrive cree la transaction automatiquement.",
    details: [
      "Composition automatique du code USSD avec numero et montant pre-remplis",
      "Support des templates USSD par operateur (depot et retrait)",
      "Le SMS de confirmation finalise la transaction sans saisie manuelle",
      "Possibilite de creer une transaction manuellement si necessaire",
    ],
    gradient: 'from-orange-500 to-orange-700',
  },
  {
    emoji: '👥',
    title: 'Gestion clients avec CNIB',
    description:
      "Un annuaire complet de vos clients reguliers. Enregistrez prenom, nom, numero de telephone et numero CNIB. Consultez l'historique complet des transactions de chaque client en un clic.",
    details: [
      "Fiche client : prenom, nom, telephone, numero CNIB",
      "Historique des transactions par client",
      "Recherche rapide par nom ou numero de telephone",
      "Filtrage des clients par operateur",
    ],
    gradient: 'from-green-500 to-green-700',
  },
  {
    emoji: '📊',
    title: 'Dashboard & statistiques',
    description:
      "Plus de 7 graphiques pour analyser votre activite en detail. Visualisez l'evolution des depots et retraits, le ratio entre les deux, le volume quotidien, les heures de pointe et la repartition par operateur.",
    details: [
      "Graphiques : evolution depots/retraits, ratio, volume quotidien, heures de pointe, repartition operateur",
      "Filtres temporels : Aujourd'hui, Hier, 7 jours, 30 jours, 3 mois",
      "Onglets par operateur pour une analyse ciblee",
      "Indicateurs de tendance (hausse/baisse) par rapport a la periode precedente",
    ],
    gradient: 'from-purple-500 to-purple-700',
  },
  {
    emoji: '💰',
    title: 'Calcul automatique des commissions',
    description:
      "Les taux de commission sont configurables par operateur. MoneyTracking calcule automatiquement vos gains sur chaque transaction et vous offre un suivi par jour, semaine ou mois.",
    details: [
      "Taux de commission configurable pour chaque operateur",
      "Suivi des commissions par jour, semaine et mois",
      "Solde operateur extrait directement des SMS de confirmation",
      "Vue globale et vue detaillee par operateur",
    ],
    gradient: 'from-yellow-500 to-yellow-700',
  },
  {
    emoji: '🏦',
    title: 'Gestion de caisse par operateur',
    description:
      "Suivez le solde de chaque operateur separement. Definissez un seuil d'alerte pour etre prevenu quand votre caisse est basse. Enregistrez vos rechargements pour garder un historique precis.",
    details: [
      "Solde en temps reel par operateur",
      "Seuil d'alerte configurable par operateur",
      "Enregistrement des rechargements de caisse",
      "Alertes automatiques quand le solde passe sous le seuil",
    ],
    gradient: 'from-indigo-500 to-indigo-700',
  },
  {
    emoji: '📄',
    title: 'Export PDF & CSV',
    description:
      "Generez des rapports professionnels au format PDF A4 paysage ou CSV compatible Excel. Selectionnez la periode souhaitee et partagez directement via WhatsApp ou email.",
    details: [
      "PDF A4 paysage avec mise en page professionnelle",
      "CSV compatible Excel pour analyses personnalisees",
      "Selection de la periode d'export",
      "Partage direct via WhatsApp, email ou autre application",
    ],
    gradient: 'from-red-500 to-red-700',
  },
  {
    emoji: '🔒',
    title: 'Securite PIN + empreinte',
    description:
      "Protegez l'acces a votre application avec un code PIN a 4 chiffres et l'authentification biometrique par empreinte digitale. Le delai de verrouillage automatique est configurable.",
    details: [
      "Code PIN a 4 chiffres avec hash securise",
      "Authentification biometrique (empreinte digitale)",
      "Delai de verrouillage automatique configurable",
      "Ecran de verrouillage avec clavier numerique personnalise",
    ],
    gradient: 'from-teal-500 to-teal-700',
  },
  {
    emoji: '☁️',
    title: 'Sauvegarde & restauration',
    description:
      "Sauvegardez toutes vos donnees dans un fichier .mmtbak. Les 7 dernieres sauvegardes sont conservees automatiquement. Partagez le fichier pour le stocker en securite ou restaurer sur un autre appareil.",
    details: [
      "Format de sauvegarde proprietaire .mmtbak",
      "Conservation automatique des 7 dernieres sauvegardes",
      "Restauration complete des donnees en un clic",
      "Partage du fichier de sauvegarde via WhatsApp, Drive, etc.",
    ],
    gradient: 'from-cyan-500 to-cyan-700',
  },
];

export default function FeaturesPage() {
  return (
    <>
      {/* Hero Header */}
      <section className="gradient-hero py-20 relative overflow-hidden">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-10 left-10 w-72 h-72 bg-white rounded-full blur-3xl" />
          <div className="absolute bottom-10 right-10 w-96 h-96 bg-blue-300 rounded-full blur-3xl" />
        </div>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center relative z-10">
          <span className="inline-block px-4 py-1.5 bg-white/10 backdrop-blur-sm text-blue-100 text-sm font-medium rounded-full mb-6 border border-white/20">
            9 fonctionnalites puissantes
          </span>
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white mb-6">
            Tout ce dont un agent{' '}
            <span className="gradient-text bg-gradient-to-r from-orange-300 to-orange-500 bg-clip-text text-transparent">
              Mobile Money
            </span>{' '}
            a besoin
          </h1>
          <p className="text-lg sm:text-xl text-blue-100 max-w-3xl mx-auto leading-relaxed">
            MoneyTracking automatise votre quotidien : detection SMS, calcul des commissions,
            gestion de caisse, statistiques avancees et bien plus encore.
          </p>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-20 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-8">
            {features.map((feature, index) => (
              <div
                key={feature.title}
                className="group relative bg-white rounded-3xl border border-gray-100 hover:border-transparent hover:shadow-2xl hover:shadow-primary/10 transition-all duration-500 overflow-hidden card-hover"
              >
                {/* Top gradient bar */}
                <div className={`h-1.5 bg-gradient-to-r ${feature.gradient}`} />

                <div className="p-8">
                  {/* Emoji + Number */}
                  <div className="flex items-center justify-between mb-5">
                    <span className="text-5xl float-animation" style={{ animationDelay: `${index * 0.2}s` }}>
                      {feature.emoji}
                    </span>
                    <span className="text-6xl font-black text-gray-100 group-hover:text-primary/10 transition-colors">
                      {String(index + 1).padStart(2, '0')}
                    </span>
                  </div>

                  {/* Title */}
                  <h3 className="text-xl font-bold text-[#0F1923] mb-3 group-hover:text-[#1565C0] transition-colors">
                    {feature.title}
                  </h3>

                  {/* Description */}
                  <p className="text-[#64748B] leading-relaxed text-sm mb-5">
                    {feature.description}
                  </p>

                  {/* Detail list */}
                  <ul className="space-y-2.5">
                    {feature.details.map((detail) => (
                      <li key={detail} className="flex items-start gap-2.5 text-sm">
                        <svg className="w-5 h-5 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                        <span className="text-gray-600">{detail}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="py-16 bg-[#F5F7FA]">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            {[
              { value: '3', label: 'Operateurs supportes', sub: 'Orange, Moov, Coris' },
              { value: '7+', label: 'Graphiques', sub: 'Statistiques detaillees' },
              { value: '100%', label: 'Hors ligne', sub: 'Aucune connexion requise' },
              { value: '30j', label: "Essai gratuit", sub: 'Sans engagement' },
            ].map((stat) => (
              <div key={stat.label} className="glass-card text-center p-6 rounded-2xl">
                <p className="text-3xl sm:text-4xl font-black text-[#1565C0] mb-1">{stat.value}</p>
                <p className="text-sm font-semibold text-[#0F1923] mb-0.5">{stat.label}</p>
                <p className="text-xs text-[#64748B]">{stat.sub}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div className="relative p-10 sm:p-16 rounded-3xl overflow-hidden gradient-hero">
            <div className="absolute inset-0 opacity-10">
              <div className="absolute -top-20 -right-20 w-80 h-80 bg-orange-400 rounded-full blur-3xl" />
            </div>
            <div className="relative z-10">
              <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
                Pret a simplifier votre gestion ?
              </h2>
              <p className="text-blue-100 mb-8 text-lg max-w-xl mx-auto">
                Essayez gratuitement pendant 30 jours. Toutes les fonctionnalites incluses, aucune carte requise.
              </p>
              <Link
                href="/download"
                className="inline-flex items-center gap-3 px-10 py-5 bg-[#FF6B35] text-white text-lg font-bold rounded-2xl hover:brightness-110 transition-all shadow-2xl shadow-orange-500/30 hover:-translate-y-1 glow-orange"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
                Telecharger MoneyTracking
              </Link>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
