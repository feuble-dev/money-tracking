'use client';

import React, { useState } from 'react';
import Link from 'next/link';

interface DocSection {
  id: string;
  title: string;
  content: React.ReactNode;
}

const sections: DocSection[] = [
  {
    id: 'demarrage',
    title: 'Demarrage rapide',
    content: (
      <div className="space-y-3">
        <p className="text-sm text-muted">Suivez ces etapes pour commencer a utiliser MoneyTracking.</p>
        <ol className="space-y-3">
          {[
            { title: 'Installer l\'application', desc: 'Telechargez le fichier APK et installez-le sur votre telephone Android (6.0 minimum).' },
            { title: 'Choisir Particulier ou Agence', desc: 'Au premier lancement, indiquez votre numero, votre pays, et le type de compte : Particulier (suivi personnel) ou Agence (usage professionnel avec commissions).' },
            { title: 'Nommer votre agence', desc: 'Chaque agence demarre avec 3 mois d\'essai gratuit. Vous pourrez en ajouter d\'autres plus tard.' },
            { title: 'Selectionner vos operateurs', desc: 'Les operateurs de votre pays (Orange Money, Moov Money, Coris Money...) sont deja configures par MoneyTracking — cochez ceux que vous utilisez, ils s\'importent automatiquement.' },
            { title: 'Creer votre code PIN', desc: 'Definissez un code PIN a 4 chiffres. Vous pourrez activer l\'empreinte digitale plus tard.' },
            { title: 'Accorder la permission SMS', desc: 'Autorisez MoneyTracking a lire vos SMS. Indispensable pour la detection automatique.' },
          ].map((s, i) => (
            <li key={i} className="flex gap-3">
              <span className="w-6 h-6 rounded-full bg-primary text-white text-xs font-bold flex items-center justify-center flex-shrink-0 mt-0.5">{i + 1}</span>
              <div>
                <p className="font-medium text-dark text-sm">{s.title}</p>
                <p className="text-sm text-muted">{s.desc}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    ),
  },
  {
    id: 'operateurs',
    title: 'Operateurs et types de transaction',
    content: (
      <div className="space-y-4">
        <p className="text-sm text-muted">
          Les operateurs (Orange Money, Moov Money, Coris Money...), leurs types de transaction
          (Depot, Retrait, Transfert, Paiement marchand, Envoi d&apos;unites...) et leurs modeles de
          SMS sont configures centralement par MoneyTracking, par pays. Vous n&apos;avez rien a
          parametrer manuellement au depart :
        </p>
        <div className="grid sm:grid-cols-2 gap-3">
          {[
            { title: 'Import automatique', desc: 'Selectionnez vos operateurs a l\'inscription : tous leurs types et modeles de detection SMS sont importes d\'un coup.' },
            { title: 'Types configurables', desc: 'Un operateur peut avoir plusieurs types de transaction, chacun avec son propre code USSD et taux de commission.' },
            { title: 'Activer / desactiver', desc: 'Depuis les parametres, desactivez un type que vous n\'utilisez pas sans le supprimer.' },
            { title: 'Personnalisation possible', desc: 'Besoin d\'un type ou d\'un modele SMS specifique ? Ajoutez-le manuellement ou corrigez un modele existant depuis l\'app.' },
          ].map((s, i) => (
            <div key={i} className="p-3 bg-soft rounded-lg border border-gray-100">
              <p className="font-medium text-dark text-sm">{s.title}</p>
              <p className="text-sm text-muted">{s.desc}</p>
            </div>
          ))}
        </div>
        <div className="p-3 bg-yellow-50 rounded-lg border border-yellow-200 text-sm text-yellow-800">
          <strong>Bon a savoir :</strong> un type de transaction (ex. Transfert) peut etre entrant ou
          sortant selon le SMS reel — c&apos;est le modele de detection qui determine le sens, pas
          le type lui-meme.
        </div>
      </div>
    ),
  },
  {
    id: 'detection-sms',
    title: 'Detection SMS',
    content: (
      <div className="space-y-3">
        <p className="text-sm text-muted">Comment fonctionne la detection automatique :</p>
        <ol className="space-y-2.5">
          {[
            { title: 'Reception du SMS', desc: 'Un SMS arrive de l\'operateur. MoneyTracking le detecte en arriere-plan.' },
            { title: 'Verification de l\'expediteur', desc: 'L\'app verifie si l\'expediteur correspond a un operateur configure.' },
            { title: 'Extraction des champs', desc: 'Montant, numero client, ID transaction et solde sont extraits grace aux modeles configures.' },
            { title: 'Transaction en attente', desc: 'Une transaction est creee en statut "en attente". Vous la confirmez ou la rejetez.' },
          ].map((s, i) => (
            <li key={i} className="flex gap-3">
              <span className="w-6 h-6 rounded-full bg-gray-200 text-dark text-xs font-bold flex items-center justify-center flex-shrink-0 mt-0.5">{i + 1}</span>
              <div>
                <p className="font-medium text-dark text-sm">{s.title}</p>
                <p className="text-sm text-muted">{s.desc}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    ),
  },
  {
    id: 'transactions',
    title: 'Gestion des transactions',
    content: (
      <div className="space-y-4">
        <p className="text-sm text-muted">L&apos;ecran des transactions montre votre activite avec des filtres.</p>
        <div className="p-3 bg-soft rounded-lg border border-gray-100">
          <p className="font-medium text-dark text-sm mb-2">Filtres</p>
          <div className="flex flex-wrap gap-1.5">
            {['Par operateur', 'Par type (depot/retrait)', 'Par periode', 'Recherche texte'].map((f) => (
              <span key={f} className="px-2 py-1 bg-white text-muted text-xs rounded border border-gray-200">{f}</span>
            ))}
          </div>
        </div>
        <div className="p-3 bg-soft rounded-lg border border-gray-100">
          <p className="font-medium text-dark text-sm mb-2">Modes de creation</p>
          <ul className="space-y-1 text-sm text-muted">
            <li><strong className="text-primary">USSD :</strong> Le SMS de confirmation cree la transaction automatiquement.</li>
            <li><strong className="text-accent">Manuel :</strong> Saisie directe des details.</li>
            <li><strong className="text-green-600">SMS auto :</strong> Cree automatiquement a la reception du SMS.</li>
          </ul>
        </div>
        <div className="p-3 bg-soft rounded-lg border border-gray-100">
          <p className="font-medium text-dark text-sm mb-1">Confirmation</p>
          <p className="text-sm text-muted">
            Les transactions detectees arrivent en &quot;en attente&quot;. Confirmez ou rejetez depuis les notifications ou la liste des transactions en attente.
          </p>
        </div>
      </div>
    ),
  },
  {
    id: 'dashboard',
    title: 'Dashboard',
    content: (
      <div className="space-y-4">
        <p className="text-sm text-muted">Plus de 7 types de graphiques pour analyser votre activite.</p>
        <div className="grid sm:grid-cols-2 gap-2">
          {[
            'Evolution depots/retraits', 'Ratio depots/retraits', 'Volume quotidien',
            'Heures de pointe', 'Repartition par operateur', 'Tendances', 'Montants cumules',
          ].map((c) => (
            <div key={c} className="p-2.5 bg-soft rounded-lg border border-gray-100 text-sm text-dark">{c}</div>
          ))}
        </div>
        <div className="p-3 bg-soft rounded-lg border border-gray-100">
          <p className="font-medium text-dark text-sm mb-2">Filtres temporels</p>
          <div className="flex flex-wrap gap-1.5">
            {["Aujourd'hui", 'Hier', '7 jours', '30 jours', '3 mois'].map((f) => (
              <span key={f} className="px-2 py-1 bg-white text-primary text-xs font-medium rounded border border-primary/20">{f}</span>
            ))}
          </div>
        </div>
      </div>
    ),
  },
  {
    id: 'commissions',
    title: 'Commissions',
    content: (
      <div className="space-y-4">
        <p className="text-sm text-muted">MoneyTracking calcule automatiquement vos commissions.</p>
        <div className="p-3 bg-soft rounded-lg border border-gray-100">
          <p className="font-medium text-dark text-sm mb-1">Taux</p>
          <p className="text-sm text-muted">Configurez le taux pour depots et retraits a l&apos;etape 4 de la configuration operateur.</p>
        </div>
        <div className="grid grid-cols-3 gap-3">
          {['Jour', 'Semaine', 'Mois'].map((p) => (
            <div key={p} className="p-3 bg-soft rounded-lg border border-gray-100 text-center">
              <p className="font-semibold text-dark text-sm">{p}</p>
            </div>
          ))}
        </div>
        <p className="text-sm text-muted">Consultez les commissions globales ou par operateur.</p>
      </div>
    ),
  },
  {
    id: 'caisse',
    title: 'Gestion de caisse',
    content: (
      <div className="space-y-3">
        <p className="text-sm text-muted">Suivez le solde de chaque operateur en temps reel.</p>
        {[
          { title: 'Configuration', desc: 'Definissez le solde initial et un seuil d\'alerte pour chaque operateur.' },
          { title: 'Rechargement', desc: 'Enregistrez vos rechargements pour maintenir le solde a jour.' },
          { title: 'Alertes', desc: 'Notification quand le solde passe sous le seuil configure.' },
        ].map((s, i) => (
          <div key={i} className="p-3 bg-soft rounded-lg border border-gray-100">
            <p className="font-medium text-dark text-sm">{s.title}</p>
            <p className="text-sm text-muted">{s.desc}</p>
          </div>
        ))}
      </div>
    ),
  },
  {
    id: 'clients',
    title: 'Clients',
    content: (
      <div className="space-y-3">
        <p className="text-sm text-muted">Gerez votre base de clients reguliers.</p>
        <div className="grid sm:grid-cols-2 gap-2">
          {[
            { title: 'Ajouter', desc: 'Prenom, nom, telephone, CNIB.' },
            { title: 'Rechercher', desc: 'Par nom ou telephone. Filtre par operateur.' },
            { title: 'Fiche client', desc: 'Informations et historique de transactions.' },
            { title: 'CNIB', desc: 'Stocke pour identification rapide.' },
          ].map((s, i) => (
            <div key={i} className="p-3 bg-soft rounded-lg border border-gray-100">
              <p className="font-medium text-dark text-sm">{s.title}</p>
              <p className="text-sm text-muted">{s.desc}</p>
            </div>
          ))}
        </div>
      </div>
    ),
  },
  {
    id: 'export',
    title: 'Export',
    content: (
      <div className="space-y-3">
        <p className="text-sm text-muted">Deux formats pour votre comptabilite.</p>
        <div className="grid sm:grid-cols-2 gap-3">
          <div className="p-3 bg-soft rounded-lg border border-gray-100">
            <p className="font-semibold text-dark text-sm mb-1">PDF</p>
            <p className="text-sm text-muted">A4 paysage, en-tete avec nom de l&apos;agence, tableau et recapitulatif.</p>
          </div>
          <div className="p-3 bg-soft rounded-lg border border-gray-100">
            <p className="font-semibold text-dark text-sm mb-1">CSV</p>
            <p className="text-sm text-muted">Compatible Excel, toutes les colonnes, importable partout.</p>
          </div>
        </div>
      </div>
    ),
  },
  {
    id: 'securite',
    title: 'Securite',
    content: (
      <div className="space-y-3">
        <p className="text-sm text-muted">Plusieurs couches de protection pour vos donnees.</p>
        {[
          { title: 'Code PIN', desc: 'Defini au premier lancement, stocke en hash securise.' },
          { title: 'Empreinte digitale', desc: 'Deverrouillage rapide si le capteur est disponible.' },
          { title: 'Verrouillage auto', desc: 'Configurable : immediat, 30s, 1min, 5min.' },
          { title: 'Sauvegarde', desc: 'Fichier .mmtbak pour securiser vos donnees.' },
        ].map((s, i) => (
          <div key={i} className="p-3 bg-soft rounded-lg border border-gray-100">
            <p className="font-medium text-dark text-sm">{s.title}</p>
            <p className="text-sm text-muted">{s.desc}</p>
          </div>
        ))}
      </div>
    ),
  },
  {
    id: 'licence',
    title: 'Systeme de licence',
    content: (
      <div className="space-y-4">
        <p className="text-sm text-muted">
          Systeme <strong className="text-dark">non bloquant</strong> : meme sans licence, la lecture reste possible.
          La licence est facturee <strong className="text-dark">par agence</strong> — un compte avec
          plusieurs agences paie un abonnement par agence.
        </p>
        <div className="p-3 bg-soft rounded-lg border border-gray-100">
          <p className="font-medium text-dark text-sm mb-2">3 modes d&apos;activation</p>
          <ol className="space-y-1.5 text-sm text-muted">
            <li><strong className="text-dark">Essai gratuit :</strong> 3 mois complets, offerts a chaque nouvelle agence.</li>
            <li><strong className="text-dark">En ligne :</strong> Verification automatique apres paiement.</li>
            <li><strong className="text-dark">Cle manuelle :</strong> Code fourni apres paiement.</li>
          </ol>
        </div>
        <div className="p-3 bg-soft rounded-lg border border-gray-100">
          <p className="font-medium text-dark text-sm mb-2">Tarifs (par agence)</p>
          <div className="grid grid-cols-3 gap-3 text-center">
            <div>
              <p className="text-lg font-bold text-primary">450</p>
              <p className="text-xs text-muted">FCFA / mois</p>
            </div>
            <div>
              <p className="text-lg font-bold text-primary">4 480</p>
              <p className="text-xs text-muted">FCFA / an</p>
              <p className="text-[10px] text-green-600">-17%</p>
            </div>
            <div>
              <p className="text-lg font-bold text-primary">8 100</p>
              <p className="text-xs text-muted">FCFA / 2 ans</p>
              <p className="text-[10px] text-green-600">-25%</p>
            </div>
          </div>
        </div>
        <div className="p-3 bg-yellow-50 rounded-lg border border-yellow-200 text-sm text-yellow-800">
          <strong>Note :</strong> Licence expiree = consultation libre, seule la creation de transactions est limitee.
        </div>
      </div>
    ),
  },
];

export default function DocsPage() {
  const [openSections, setOpenSections] = useState<Set<string>>(new Set(['demarrage']));

  const toggle = (id: string) => {
    setOpenSections((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  };

  return (
    <>
      <section className="gradient-hero py-16">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <h1 className="text-3xl sm:text-4xl font-bold text-white">Documentation</h1>
          <p className="mt-3 text-blue-200 max-w-lg">
            Tout ce qu&apos;il faut savoir pour utiliser MoneyTracking.
          </p>
        </div>
      </section>

      <section className="py-16 bg-white">
        <div className="max-w-3xl mx-auto px-4 sm:px-6">
          {/* Sommaire */}
          <div className="mb-10 p-4 bg-soft rounded-xl border border-gray-100">
            <div className="flex items-center justify-between mb-3">
              <p className="font-semibold text-dark text-sm">Sommaire</p>
              <div className="flex gap-2">
                <button onClick={() => setOpenSections(new Set(sections.map(s => s.id)))}
                  className="text-xs text-primary hover:underline">Tout ouvrir</button>
                <button onClick={() => setOpenSections(new Set())}
                  className="text-xs text-muted hover:underline">Tout fermer</button>
              </div>
            </div>
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-1">
              {sections.map((s) => (
                <button key={s.id} onClick={() => {
                  if (!openSections.has(s.id)) toggle(s.id);
                  document.getElementById(s.id)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }}
                  className="text-left px-3 py-1.5 rounded text-sm text-gray-600 hover:text-primary hover:bg-white transition-colors">
                  {s.title}
                </button>
              ))}
            </div>
          </div>

          {/* Sections */}
          <div className="space-y-3">
            {sections.map((s) => {
              const isOpen = openSections.has(s.id);
              return (
                <div key={s.id} id={s.id}
                  className={`rounded-xl border transition-colors ${isOpen ? 'border-primary/20' : 'border-gray-200'}`}>
                  <button onClick={() => toggle(s.id)} className="w-full flex items-center justify-between p-4 text-left">
                    <span className={`font-semibold text-sm ${isOpen ? 'text-primary' : 'text-dark'}`}>{s.title}</span>
                    <svg className={`w-4 h-4 text-muted flex-shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`}
                      fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  {isOpen && (
                    <div className="px-4 pb-4 border-t border-gray-100 pt-4">
                      {s.content}
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {/* Contact */}
          <div className="mt-14 p-6 gradient-hero rounded-xl text-center">
            <p className="text-white font-semibold mb-1">Des questions ?</p>
            <p className="text-blue-200 text-sm mb-5">Notre equipe peut vous accompagner.</p>
            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <a href="mailto:contact@rftech-bf.com"
                className="px-5 py-2.5 bg-white text-primary font-medium text-sm rounded-lg hover:bg-gray-50 transition-colors">
                Nous contacter
              </a>
              <Link href="/download"
                className="px-5 py-2.5 bg-white/10 text-white font-medium text-sm rounded-lg border border-white/20 hover:bg-white/20 transition-colors">
                Telecharger l&apos;app
              </Link>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
