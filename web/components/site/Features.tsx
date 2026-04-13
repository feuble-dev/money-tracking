import React from 'react';

const features = [
  {
    emoji: '📩',
    title: 'Détection SMS automatique',
    description: 'Les SMS Orange Money, Moov Money et Coris Money sont détectés et convertis automatiquement en transactions. Montant, numéro client, ID transaction — tout est extrait.',
    color: 'from-blue-500 to-blue-600',
  },
  {
    emoji: '📱',
    title: 'Dépôt & Retrait via USSD',
    description: 'Lancez vos opérations USSD directement depuis l\'app. Saisissez le numéro et le montant, le code USSD est composé automatiquement.',
    color: 'from-violet-500 to-violet-600',
  },
  {
    emoji: '👥',
    title: 'Gestion clients avec CNIB',
    description: 'Enregistrez vos clients avec prénom, nom, téléphone et CNIB. Historique complet de chaque client consultable.',
    color: 'from-emerald-500 to-emerald-600',
  },
  {
    emoji: '📊',
    title: 'Dashboard & statistiques',
    description: 'Graphiques d\'évolution, ratio dépôts/retraits, heures de pointe, répartition par opérateur. Filtres par période et par opérateur.',
    color: 'from-primary to-primary-dark',
  },
  {
    emoji: '💰',
    title: 'Calcul automatique des commissions',
    description: 'Les commissions sont calculées selon vos taux configurés par opérateur. Suivi par jour, semaine, mois et par opérateur.',
    color: 'from-amber-500 to-amber-600',
  },
  {
    emoji: '🏦',
    title: 'Gestion de caisse par opérateur',
    description: 'Suivez le solde de chaque opérateur séparément. Alertes quand le solde passe sous le seuil configuré. Rechargement en un clic.',
    color: 'from-cyan-500 to-cyan-600',
  },
  {
    emoji: '📤',
    title: 'Export PDF & CSV',
    description: 'Générez des rapports professionnels en PDF (A4 paysage) ou exportez en CSV compatible Excel. Partagez par WhatsApp ou email.',
    color: 'from-rose-500 to-rose-600',
  },
  {
    emoji: '🔐',
    title: 'Sécurité PIN + empreinte',
    description: 'Protégez vos données avec un code PIN 4 chiffres et l\'empreinte digitale. Délai de verrouillage automatique configurable.',
    color: 'from-slate-600 to-slate-700',
  },
  {
    emoji: '☁️',
    title: 'Sauvegarde & restauration',
    description: 'Sauvegardez votre base de données en fichier .mmtbak. Restaurez à tout moment. Les 7 dernières sauvegardes sont conservées.',
    color: 'from-teal-500 to-teal-600',
    badge: 'Local',
  },
  {
    emoji: '📥',
    title: 'Import Historique SMS',
    description: 'Importez vos anciens SMS pour récupérer toutes vos transactions passées. Choisissez la période, l\'app analyse et crée les transactions automatiquement. Achat unique 2 000 FCFA.',
    color: 'from-indigo-500 to-indigo-600',
    badge: '2 000 F',
  },
  {
    emoji: '🔔',
    title: 'Notifications intelligentes',
    description: 'Deux onglets : notifications transactions (SMS détecté, en attente) et notifications générales envoyées par l\'administrateur en temps réel.',
    color: 'from-pink-500 to-pink-600',
  },
  {
    emoji: '📝',
    title: 'Confirmation avancée',
    description: 'Formulaire complet pour chaque transaction : identité du porteur (nom, CNIB, date de naissance). Le porteur peut être différent du titulaire du numéro. Modification possible après confirmation.',
    color: 'from-lime-600 to-lime-700',
  },
];

interface FeaturesProps {
  limit?: number;
}

export default function Features({ limit }: FeaturesProps) {
  const displayed = limit ? features.slice(0, limit) : features;

  return (
    <section className="py-20 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary-50 text-primary text-sm font-semibold rounded-full mb-4">
            Fonctionnalités
          </div>
          <h2 className="text-3xl sm:text-4xl font-extrabold text-dark mb-4">
            Tout ce dont vous avez besoin
          </h2>
          <p className="text-lg text-muted max-w-2xl mx-auto">
            Des outils puissants conçus spécifiquement pour les agents Mobile Money au Burkina Faso.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {displayed.map((f) => (
            <div key={f.title} className="group relative p-7 rounded-2xl border border-gray-100 hover:border-transparent card-hover hover:shadow-large bg-white">
              <div className={`w-14 h-14 rounded-2xl bg-gradient-to-br ${f.color} flex items-center justify-center mb-5 shadow-lg group-hover:scale-110 transition-transform duration-300`}>
                <span className="text-2xl">{f.emoji}</span>
              </div>
              <h3 className="text-lg font-bold text-dark mb-2 flex items-center gap-2">
                {f.title}
                {f.badge && (
                  <span className="px-2 py-0.5 bg-teal-100 text-teal-700 text-[10px] font-bold rounded-full uppercase">{f.badge}</span>
                )}
              </h3>
              <p className="text-muted leading-relaxed text-sm">{f.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
