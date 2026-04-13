'use client';

import React, { useState } from 'react';
import Link from 'next/link';

interface DocSection {
  id: string;
  icon: string;
  title: string;
  content: React.ReactNode;
}

const sections: DocSection[] = [
  {
    id: 'demarrage',
    icon: '🚀',
    title: 'Demarrage rapide',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          Suivez ces etapes pour commencer a utiliser MoneyTracking en quelques minutes.
        </p>
        <div className="space-y-3">
          <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-xl">
            <span className="inline-flex items-center justify-center w-7 h-7 rounded-full bg-[#1565C0] text-white text-xs font-bold flex-shrink-0">1</span>
            <div>
              <p className="font-semibold text-[#0F1923] text-sm">Installer l&apos;application</p>
              <p className="text-[#64748B] text-sm">Telechargez le fichier APK et installez-le sur votre telephone Android (6.0 minimum). Autorisez les sources inconnues si demande.</p>
            </div>
          </div>
          <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-xl">
            <span className="inline-flex items-center justify-center w-7 h-7 rounded-full bg-[#1565C0] text-white text-xs font-bold flex-shrink-0">2</span>
            <div>
              <p className="font-semibold text-[#0F1923] text-sm">Creer votre code PIN</p>
              <p className="text-[#64748B] text-sm">Au premier lancement, definissez un code PIN a 4 chiffres. Ce PIN protegera l&apos;acces a votre application. Vous pourrez aussi activer l&apos;empreinte digitale plus tard.</p>
            </div>
          </div>
          <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-xl">
            <span className="inline-flex items-center justify-center w-7 h-7 rounded-full bg-[#1565C0] text-white text-xs font-bold flex-shrink-0">3</span>
            <div>
              <p className="font-semibold text-[#0F1923] text-sm">Configurer votre premier operateur</p>
              <p className="text-[#64748B] text-sm">Allez dans le menu Operateurs et ajoutez Orange Money, Moov Money ou Coris Money. Suivez l&apos;assistant de configuration en 4 etapes (informations, SMS, USSD, commissions).</p>
            </div>
          </div>
          <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-xl">
            <span className="inline-flex items-center justify-center w-7 h-7 rounded-full bg-[#1565C0] text-white text-xs font-bold flex-shrink-0">4</span>
            <div>
              <p className="font-semibold text-[#0F1923] text-sm">Accorder la permission SMS</p>
              <p className="text-[#64748B] text-sm">Autorisez MoneyTracking a lire vos SMS. Cette permission est indispensable pour la detection automatique des transactions.</p>
            </div>
          </div>
        </div>
      </div>
    ),
  },
  {
    id: 'operateurs',
    icon: '📡',
    title: 'Configuration des operateurs',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          La configuration d&apos;un operateur se fait via un assistant en <strong className="text-[#0F1923]">4 etapes (Stepper)</strong> :
        </p>
        <div className="grid sm:grid-cols-2 gap-4">
          <div className="p-4 bg-[#F5F7FA] rounded-xl border-l-4 border-[#1565C0]">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Etape 1 : Informations generales</p>
            <p className="text-[#64748B] text-sm">Nom de l&apos;operateur, couleur d&apos;identification et expediteur SMS (ex: &quot;OrangeMoney&quot;, &quot;MoovMoney&quot;).</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl border-l-4 border-[#FF6B35]">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Etape 2 : Configuration SMS</p>
            <p className="text-[#64748B] text-sm">Collez un SMS exemple de depot et un SMS exemple de retrait. L&apos;application identifie automatiquement les champs (montant, numero, ID, solde).</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl border-l-4 border-green-500">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Etape 3 : Templates USSD</p>
            <p className="text-[#64748B] text-sm">Definissez le code USSD pour les depots (ex: *144*&#123;numero&#125;*&#123;montant&#125;#) et les retraits. MoneyTracking les compose automatiquement.</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl border-l-4 border-purple-500">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Etape 4 : Commissions</p>
            <p className="text-[#64748B] text-sm">Configurez les taux de commission pour les depots et les retraits. Ces taux seront appliques automatiquement a chaque transaction.</p>
          </div>
        </div>
        <div className="p-4 bg-yellow-50 rounded-xl border border-yellow-200">
          <p className="text-sm text-yellow-800">
            <strong>Conseil :</strong> Pour l&apos;expediteur SMS, notez exactement le nom qui apparait lorsque vous recevez un SMS de l&apos;operateur (ex: &quot;OrangeMoney&quot;, pas &quot;Orange Money&quot;).
          </p>
        </div>
      </div>
    ),
  },
  {
    id: 'detection-sms',
    icon: '📨',
    title: 'Detection SMS',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          Voici comment fonctionne la detection automatique des SMS de transaction :
        </p>
        <div className="space-y-3">
          <div className="flex items-start gap-4 p-4 bg-[#F5F7FA] rounded-xl">
            <div className="w-10 h-10 rounded-full bg-[#1565C0] flex items-center justify-center flex-shrink-0">
              <span className="text-white text-lg">1</span>
            </div>
            <div>
              <p className="font-semibold text-[#0F1923] text-sm">Reception du SMS</p>
              <p className="text-[#64748B] text-sm">Un SMS de confirmation arrive de l&apos;operateur (ex: OrangeMoney). MoneyTracking le detecte en arriere-plan.</p>
            </div>
          </div>
          <div className="flex items-start gap-4 p-4 bg-[#F5F7FA] rounded-xl">
            <div className="w-10 h-10 rounded-full bg-[#42A5F5] flex items-center justify-center flex-shrink-0">
              <span className="text-white text-lg">2</span>
            </div>
            <div>
              <p className="font-semibold text-[#0F1923] text-sm">Correspondance de l&apos;expediteur</p>
              <p className="text-[#64748B] text-sm">L&apos;application verifie si l&apos;expediteur du SMS correspond a un operateur configure (sender matching). Si oui, elle analyse le contenu.</p>
            </div>
          </div>
          <div className="flex items-start gap-4 p-4 bg-[#F5F7FA] rounded-xl">
            <div className="w-10 h-10 rounded-full bg-[#FF6B35] flex items-center justify-center flex-shrink-0">
              <span className="text-white text-lg">3</span>
            </div>
            <div>
              <p className="font-semibold text-[#0F1923] text-sm">Extraction des champs</p>
              <p className="text-[#64748B] text-sm">MoneyTracking extrait automatiquement : le montant, le numero du client, l&apos;ID de transaction et le solde operateur, grace aux modeles configures.</p>
            </div>
          </div>
          <div className="flex items-start gap-4 p-4 bg-[#F5F7FA] rounded-xl">
            <div className="w-10 h-10 rounded-full bg-green-500 flex items-center justify-center flex-shrink-0">
              <span className="text-white text-lg">4</span>
            </div>
            <div>
              <p className="font-semibold text-[#0F1923] text-sm">Transaction en attente</p>
              <p className="text-[#64748B] text-sm">Une transaction est creee avec le statut &quot;en attente&quot;. Vous recevez une notification pour <strong>confirmer</strong> ou <strong>rejeter</strong> la transaction.</p>
            </div>
          </div>
        </div>
      </div>
    ),
  },
  {
    id: 'transactions',
    icon: '💳',
    title: 'Gestion des transactions',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          L&apos;ecran des transactions vous montre l&apos;ensemble de votre activite avec des outils de filtrage puissants.
        </p>
        <div className="space-y-3">
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-2">Filtres disponibles</p>
            <div className="flex flex-wrap gap-2">
              {['Par operateur', 'Par type (depot/retrait)', 'Par periode', 'Recherche par texte'].map((f) => (
                <span key={f} className="px-3 py-1 bg-white text-[#64748B] text-xs rounded-full border border-gray-200">{f}</span>
              ))}
            </div>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-2">Modes de creation</p>
            <ul className="space-y-1.5 text-sm text-[#64748B]">
              <li className="flex items-start gap-2">
                <span className="text-[#1565C0] font-bold">USSD :</span>
                Lancez le code USSD, le SMS de confirmation cree la transaction automatiquement.
              </li>
              <li className="flex items-start gap-2">
                <span className="text-[#FF6B35] font-bold">Manuel :</span>
                Creez une transaction manuellement en saisissant les details.
              </li>
              <li className="flex items-start gap-2">
                <span className="text-green-600 font-bold">SMS auto :</span>
                La transaction est creee automatiquement a la reception du SMS de l&apos;operateur.
              </li>
            </ul>
          </div>
          <div className="p-4 bg-orange-50 rounded-xl border border-orange-200">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Flux de confirmation</p>
            <p className="text-sm text-[#64748B]">
              Les transactions detectees par SMS arrivent en statut &quot;en attente&quot;. Depuis l&apos;ecran des notifications ou la liste des transactions en attente, vous pouvez les <strong className="text-green-600">confirmer</strong> ou les <strong className="text-red-500">rejeter</strong> individuellement.
            </p>
          </div>
        </div>
      </div>
    ),
  },
  {
    id: 'dashboard',
    icon: '📊',
    title: 'Dashboard',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          Le dashboard offre une vue complete de votre activite grace a plus de 7 types de graphiques.
        </p>
        <div className="grid sm:grid-cols-2 gap-3">
          {[
            { name: 'Evolution depots/retraits', desc: 'Courbe montrant l\'evolution dans le temps' },
            { name: 'Ratio depots/retraits', desc: 'Comparaison visuelle entre depots et retraits' },
            { name: 'Volume quotidien', desc: 'Histogramme du nombre de transactions par jour' },
            { name: 'Heures de pointe', desc: 'Graphique montrant les heures les plus actives' },
            { name: 'Repartition par operateur', desc: 'Camembert de la part de chaque operateur' },
            { name: 'Tendances', desc: 'Indicateurs de hausse/baisse vs periode precedente' },
            { name: 'Montants cumules', desc: 'Total des depots et retraits sur la periode' },
          ].map((chart) => (
            <div key={chart.name} className="p-3 bg-[#F5F7FA] rounded-xl">
              <p className="font-semibold text-[#0F1923] text-sm">{chart.name}</p>
              <p className="text-[#64748B] text-xs">{chart.desc}</p>
            </div>
          ))}
        </div>
        <div className="p-4 bg-blue-50 rounded-xl">
          <p className="font-bold text-[#0F1923] text-sm mb-2">Filtres temporels</p>
          <div className="flex flex-wrap gap-2">
            {["Aujourd'hui", 'Hier', '7 derniers jours', '30 derniers jours', '3 derniers mois'].map((f) => (
              <span key={f} className="px-3 py-1.5 bg-white text-[#1565C0] text-xs font-medium rounded-lg border border-[#1565C0]/20">{f}</span>
            ))}
          </div>
        </div>
        <p className="text-sm text-[#64748B]">
          <strong className="text-[#0F1923]">Onglets par operateur :</strong> Basculez entre la vue globale et la vue par operateur (Orange, Moov, Coris) pour une analyse ciblee.
        </p>
      </div>
    ),
  },
  {
    id: 'commissions',
    icon: '💰',
    title: 'Commissions',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          MoneyTracking calcule automatiquement vos commissions sur chaque transaction.
        </p>
        <div className="p-4 bg-[#F5F7FA] rounded-xl">
          <p className="font-bold text-[#0F1923] text-sm mb-2">Comment fonctionnent les taux</p>
          <p className="text-sm text-[#64748B]">
            Lors de la configuration de chaque operateur (etape 4 du Stepper), vous definissez le taux de commission pour les depots et les retraits. Ce taux est applique automatiquement a chaque transaction confirmee.
          </p>
        </div>
        <div className="grid sm:grid-cols-3 gap-3">
          {[
            { period: 'Jour', desc: 'Commissions du jour en cours' },
            { period: 'Semaine', desc: 'Total hebdomadaire' },
            { period: 'Mois', desc: 'Bilan mensuel complet' },
          ].map((p) => (
            <div key={p.period} className="p-4 bg-green-50 rounded-xl text-center border border-green-200">
              <p className="font-bold text-green-700 text-lg">{p.period}</p>
              <p className="text-[#64748B] text-xs">{p.desc}</p>
            </div>
          ))}
        </div>
        <p className="text-sm text-[#64748B]">
          <strong className="text-[#0F1923]">Vue par operateur :</strong> Consultez les commissions globales ou filtrez par operateur pour voir la contribution de chacun.
        </p>
      </div>
    ),
  },
  {
    id: 'caisse',
    icon: '🏦',
    title: 'Gestion de caisse',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          La gestion de caisse vous permet de suivre le solde de chaque operateur en temps reel.
        </p>
        <div className="space-y-3">
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Configuration initiale</p>
            <p className="text-sm text-[#64748B]">Pour chaque operateur, definissez le solde initial et un seuil d&apos;alerte (montant minimum avant notification).</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Rechargement</p>
            <p className="text-sm text-[#64748B]">Quand vous approvisionnez votre caisse aupres de l&apos;operateur, enregistrez le rechargement pour mettre a jour le solde.</p>
          </div>
          <div className="p-4 bg-red-50 rounded-xl border border-red-200">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Alertes de solde bas</p>
            <p className="text-sm text-[#64748B]">Lorsque le solde d&apos;un operateur passe sous le seuil defini, MoneyTracking vous envoie une alerte pour vous rappeler de recharger.</p>
          </div>
        </div>
      </div>
    ),
  },
  {
    id: 'clients',
    icon: '👥',
    title: 'Clients',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          Gerez votre base de clients reguliers pour un suivi personnalise.
        </p>
        <div className="grid sm:grid-cols-2 gap-3">
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Ajouter un client</p>
            <p className="text-sm text-[#64748B]">Renseignez le prenom, nom, numero de telephone et numero CNIB du client.</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Recherche</p>
            <p className="text-sm text-[#64748B]">Trouvez un client par son nom ou numero de telephone. Filtrez par operateur.</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Fiche client</p>
            <p className="text-sm text-[#64748B]">Consultez toutes les informations du client et son historique complet de transactions.</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Numero CNIB</p>
            <p className="text-sm text-[#64748B]">Le numero CNIB est stocke pour identification rapide lors des transactions.</p>
          </div>
        </div>
      </div>
    ),
  },
  {
    id: 'export',
    icon: '📄',
    title: 'Export',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          Exportez vos donnees dans deux formats professionnels pour votre comptabilite.
        </p>
        <div className="grid sm:grid-cols-2 gap-4">
          <div className="p-5 bg-red-50 rounded-xl border border-red-200">
            <p className="font-bold text-red-700 text-lg mb-2">PDF</p>
            <ul className="space-y-1.5 text-sm text-[#64748B]">
              <li>Format A4 paysage</li>
              <li>Mise en page professionnelle</li>
              <li>En-tete avec nom de l&apos;agence</li>
              <li>Tableau des transactions</li>
              <li>Totaux et recapitulatif</li>
            </ul>
          </div>
          <div className="p-5 bg-green-50 rounded-xl border border-green-200">
            <p className="font-bold text-green-700 text-lg mb-2">CSV</p>
            <ul className="space-y-1.5 text-sm text-[#64748B]">
              <li>Compatible Microsoft Excel</li>
              <li>Toutes les colonnes de donnees</li>
              <li>Importable dans tout logiciel</li>
              <li>Ideal pour analyses personnalisees</li>
            </ul>
          </div>
        </div>
        <div className="p-4 bg-blue-50 rounded-xl">
          <p className="font-bold text-[#0F1923] text-sm mb-1">Selection de periode & partage</p>
          <p className="text-sm text-[#64748B]">Choisissez la periode a exporter, puis partagez directement le fichier via WhatsApp, email ou toute autre application de partage.</p>
        </div>
      </div>
    ),
  },
  {
    id: 'securite',
    icon: '🔒',
    title: 'Securite',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          MoneyTracking protege vos donnees financieres avec plusieurs couches de securite.
        </p>
        <div className="space-y-3">
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Code PIN a 4 chiffres</p>
            <p className="text-sm text-[#64748B]">Defini au premier lancement. Le PIN est stocke sous forme de hash securise (non reversible). Modifiable dans les parametres.</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Empreinte digitale</p>
            <p className="text-sm text-[#64748B]">Activez l&apos;authentification biometrique pour un deverrouillage rapide. Necessite un capteur d&apos;empreinte et au moins une empreinte enregistree.</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Verrouillage automatique</p>
            <p className="text-sm text-[#64748B]">Configurez le delai apres lequel l&apos;application se verrouille automatiquement (immediat, 30s, 1min, 5min, etc.).</p>
          </div>
          <div className="p-4 bg-[#F5F7FA] rounded-xl">
            <p className="font-bold text-[#0F1923] text-sm mb-1">Sauvegarde securisee</p>
            <p className="text-sm text-[#64748B]">Les fichiers de sauvegarde .mmtbak contiennent toutes vos donnees. Les 7 dernieres sauvegardes sont conservees. Partagez-les pour les stocker en securite.</p>
          </div>
        </div>
      </div>
    ),
  },
  {
    id: 'licence',
    icon: '🔑',
    title: 'Systeme de licence',
    content: (
      <div className="space-y-4">
        <p className="text-[#64748B] leading-relaxed">
          MoneyTracking propose un systeme de licence flexible et <strong className="text-[#0F1923]">non bloquant</strong> : meme sans licence active, la lecture de vos donnees reste toujours possible.
        </p>
        <div className="p-4 bg-blue-50 rounded-xl border border-blue-200">
          <p className="font-bold text-[#0F1923] text-sm mb-2">3 modes d&apos;activation</p>
          <div className="space-y-2">
            <div className="flex items-start gap-2 text-sm">
              <span className="text-[#1565C0] font-bold">1.</span>
              <span className="text-[#64748B]"><strong className="text-[#0F1923]">Essai gratuit :</strong> 30 jours d&apos;acces complet sans engagement.</span>
            </div>
            <div className="flex items-start gap-2 text-sm">
              <span className="text-[#1565C0] font-bold">2.</span>
              <span className="text-[#64748B]"><strong className="text-[#0F1923]">Recuperation en ligne :</strong> Si vous avez deja paye, MoneyTracking verifie automatiquement votre licence en ligne.</span>
            </div>
            <div className="flex items-start gap-2 text-sm">
              <span className="text-[#1565C0] font-bold">3.</span>
              <span className="text-[#64748B]"><strong className="text-[#0F1923]">Cle manuelle :</strong> Entrez une cle de licence fournie par notre equipe apres paiement.</span>
            </div>
          </div>
        </div>
        <div className="p-4 bg-green-50 rounded-xl border border-green-200">
          <p className="font-bold text-[#0F1923] text-sm mb-2">Tarifs</p>
          <div className="grid grid-cols-3 gap-3">
            <div className="text-center p-3 bg-white rounded-xl">
              <p className="text-2xl font-black text-[#1565C0]">1 000</p>
              <p className="text-xs text-[#64748B]">FCFA / mois</p>
            </div>
            <div className="text-center p-3 bg-white rounded-xl border-2 border-[#FF6B35]">
              <p className="text-2xl font-black text-[#FF6B35]">10 000</p>
              <p className="text-xs text-[#64748B]">FCFA / an</p>
              <p className="text-[10px] text-green-600 font-medium">2 mois offerts</p>
            </div>
            <div className="text-center p-3 bg-white rounded-xl">
              <p className="text-2xl font-black text-[#1565C0]">18 000</p>
              <p className="text-xs text-[#64748B]">FCFA / 2 ans</p>
              <p className="text-[10px] text-green-600 font-medium">6 mois offerts</p>
            </div>
          </div>
        </div>
        <div className="p-4 bg-yellow-50 rounded-xl border border-yellow-200">
          <p className="text-sm text-yellow-800">
            <strong>Important :</strong> Le systeme de licence est non bloquant. Meme si votre licence expire, vous pouvez toujours consulter vos donnees existantes (transactions, clients, rapports). Seule la creation de nouvelles transactions est limitee.
          </p>
        </div>
      </div>
    ),
  },
];

export default function DocsPage() {
  const [openSections, setOpenSections] = useState<Set<string>>(new Set(['demarrage']));

  const toggleSection = (id: string) => {
    setOpenSections((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const expandAll = () => {
    setOpenSections(new Set(sections.map((s) => s.id)));
  };

  const collapseAll = () => {
    setOpenSections(new Set());
  };

  return (
    <>
      {/* Hero Header */}
      <section className="gradient-hero py-20 relative overflow-hidden">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-10 right-10 w-72 h-72 bg-white rounded-full blur-3xl" />
          <div className="absolute bottom-10 left-10 w-96 h-96 bg-blue-300 rounded-full blur-3xl" />
        </div>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center relative z-10">
          <span className="inline-block px-4 py-1.5 bg-white/10 backdrop-blur-sm text-blue-100 text-sm font-medium rounded-full mb-6 border border-white/20">
            Guide complet
          </span>
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white mb-4">
            Documentation
          </h1>
          <p className="text-lg sm:text-xl text-blue-100 max-w-2xl mx-auto">
            Tout ce que vous devez savoir pour maitriser MoneyTracking de A a Z.
          </p>
        </div>
      </section>

      {/* Content */}
      <section className="py-20 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          {/* Table of contents */}
          <div className="bg-[#F5F7FA] rounded-3xl p-6 sm:p-8 mb-12">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-bold text-[#0F1923]">Sommaire</h2>
              <div className="flex gap-2">
                <button
                  onClick={expandAll}
                  className="px-3 py-1.5 text-xs font-medium text-[#1565C0] bg-white rounded-lg border border-[#1565C0]/20 hover:bg-[#1565C0] hover:text-white transition-all"
                >
                  Tout ouvrir
                </button>
                <button
                  onClick={collapseAll}
                  className="px-3 py-1.5 text-xs font-medium text-[#64748B] bg-white rounded-lg border border-gray-200 hover:bg-gray-100 transition-all"
                >
                  Tout fermer
                </button>
              </div>
            </div>
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-2">
              {sections.map((section) => (
                <button
                  key={section.id}
                  onClick={() => {
                    if (!openSections.has(section.id)) toggleSection(section.id);
                    document.getElementById(section.id)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                  }}
                  className="flex items-center gap-2.5 px-4 py-2.5 rounded-xl text-sm font-medium text-gray-600 hover:text-[#1565C0] hover:bg-white transition-all text-left"
                >
                  <span className="text-lg">{section.icon}</span>
                  {section.title}
                </button>
              ))}
            </div>
          </div>

          {/* Accordion Sections */}
          <div className="space-y-4">
            {sections.map((section) => {
              const isOpen = openSections.has(section.id);
              return (
                <div
                  key={section.id}
                  id={section.id}
                  className={`rounded-2xl border transition-all duration-300 overflow-hidden ${
                    isOpen
                      ? 'border-[#1565C0]/20 shadow-lg shadow-[#1565C0]/5'
                      : 'border-gray-100 hover:border-gray-200'
                  }`}
                >
                  <button
                    onClick={() => toggleSection(section.id)}
                    className="w-full flex items-center gap-4 p-6 text-left"
                  >
                    <span className={`text-3xl transition-transform duration-300 ${isOpen ? 'scale-110' : ''}`}>
                      {section.icon}
                    </span>
                    <span className="flex-1">
                      <span className={`text-lg font-bold transition-colors ${isOpen ? 'text-[#1565C0]' : 'text-[#0F1923]'}`}>
                        {section.title}
                      </span>
                    </span>
                    <svg
                      className={`w-5 h-5 text-[#64748B] flex-shrink-0 transition-transform duration-300 ${isOpen ? 'rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <div
                    className={`transition-all duration-300 ease-in-out ${
                      isOpen ? 'max-h-[2000px] opacity-100' : 'max-h-0 opacity-0'
                    } overflow-hidden`}
                  >
                    <div className="px-6 pb-6 pt-0">
                      <div className="border-t border-gray-100 pt-5">
                        {section.content}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Contact */}
          <div className="mt-16 p-8 sm:p-10 rounded-3xl gradient-hero text-center relative overflow-hidden">
            <div className="absolute inset-0 opacity-10">
              <div className="absolute -top-20 -right-20 w-60 h-60 bg-orange-400 rounded-full blur-3xl" />
            </div>
            <div className="relative z-10">
              <h3 className="text-2xl font-bold text-white mb-3">Vous avez d&apos;autres questions ?</h3>
              <p className="text-blue-100 mb-8 max-w-lg mx-auto">
                Notre equipe est disponible pour vous accompagner dans la prise en main de MoneyTracking.
              </p>
              <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                <a
                  href="mailto:contact@rftech-bf.com"
                  className="inline-flex items-center gap-2 px-6 py-3 bg-white text-[#1565C0] font-semibold rounded-xl hover:bg-blue-50 transition-all"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                  Nous contacter
                </a>
                <Link
                  href="/download"
                  className="inline-flex items-center gap-2 px-6 py-3 bg-[#FF6B35] text-white font-semibold rounded-xl hover:brightness-110 transition-all shadow-lg shadow-orange-500/30"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                  </svg>
                  Telecharger l&apos;app
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
