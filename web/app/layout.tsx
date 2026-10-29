import type { Metadata, Viewport } from 'next';
import { Bricolage_Grotesque, Inter } from 'next/font/google';
import './globals.css';

// Polices auto-hébergées par next/font (pas de requête Google au runtime,
// pas de saut de mise en page). Bricolage pour les titres, Inter pour le
// texte courant.
const display = Bricolage_Grotesque({
  subsets: ['latin'],
  variable: '--font-display',
  display: 'swap',
});
const body = Inter({ subsets: ['latin'], variable: '--font-body', display: 'swap' });

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://money-tracking.site';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'MoneyTracking — Votre argent Mobile Money, enfin clair',
    template: '%s · MoneyTracking',
  },
  description:
    "Suivez automatiquement vos opérations Orange Money, Moov Money, Coris Money et Wave à partir de vos SMS. Gratuit pour les particuliers, complet pour les agences au Burkina Faso.",
  keywords:
    'mobile money, burkina faso, orange money, moov money, coris money, wave, budget, dépenses, agent, agence, commissions',
  icons: { icon: '/icon.png', apple: '/icon.png' },
  openGraph: {
    title: 'MoneyTracking — Votre argent Mobile Money, enfin clair',
    description:
      'Vos SMS deviennent un tableau de bord : dépenses, budget, commissions. Gratuit pour les particuliers.',
    images: ['/logo.png'],
    locale: 'fr_FR',
    type: 'website',
  },
};

export const viewport: Viewport = {
  themeColor: '#0B2545',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr" className={`${display.variable} ${body.variable}`}>
      <body className="min-h-screen bg-white font-sans text-dark antialiased">
        {children}
      </body>
    </html>
  );
}
