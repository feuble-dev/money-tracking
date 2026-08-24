import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'MoneyTracking - Gestion Mobile Money | Burkina Faso',
  description:
    'Application de gestion pour agents Mobile Money. Détection automatique des SMS Orange Money, Moov Money et Coris Money au Burkina Faso.',
  keywords: 'mobile money, burkina faso, orange money, moov money, coris money, agent, gestion, suivi transactions',
  icons: { icon: '/icon.png', apple: '/icon.png' },
  openGraph: {
    title: 'MoneyTracking - Gérez votre agence Mobile Money',
    description: 'Détection SMS automatique, dashboard, export PDF, commissions. Tout pour gérer votre agence Mobile Money au Burkina Faso.',
    images: ['/logo.png'],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr" className="scroll-smooth">
      <body className="min-h-screen bg-white">{children}</body>
    </html>
  );
}
