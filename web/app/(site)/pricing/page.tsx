import React from 'react';
import type { Metadata } from 'next';
import Pricing from '@/components/site/Pricing';
import Faq from '@/components/site/Faq';
import CtaBand from '@/components/site/CtaBand';
import PageHeader from '@/components/site/PageHeader';

export const metadata: Metadata = {
  title: 'Tarifs',
  description: 'Gratuit pour les particuliers. Licence par agence pour les professionnels, 3 mois offerts.',
};

export default function PricingPage() {
  return (
    <>
      <PageHeader
        eyebrow="Tarifs"
        title="Gratuit pour vous. Juste pour votre agence."
        text="Aucun abonnement pour suivre votre argent personnel. Une licence simple, par agence, pour les professionnels du Mobile Money."
      />
      <Pricing withTitle={false} />
      <Faq />
      <CtaBand />
    </>
  );
}
