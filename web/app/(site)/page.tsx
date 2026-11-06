import React from 'react';
import Link from 'next/link';
import Hero from '@/components/site/Hero';
import Operators from '@/components/site/Operators';
import Audiences from '@/components/site/Audiences';
import HowItWorks from '@/components/site/HowItWorks';
import FeatureGrid from '@/components/site/FeatureGrid';
import SectionTitle from '@/components/site/SectionTitle';
import Stats from '@/components/site/Stats';
import Pricing from '@/components/site/Pricing';
import Faq from '@/components/site/Faq';
import CtaBand from '@/components/site/CtaBand';
import Icon from '@/components/site/Icon';

export default function HomePage() {
  return (
    <>
      <Hero />
      <Operators />
      <Audiences />
      <HowItWorks />
      <section className="bg-ink py-24">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <div className="flex flex-col justify-between gap-6 md:flex-row md:items-end">
            <SectionTitle
              dark
              eyebrow="Fonctionnalités"
              title="Tout ce que vos SMS savent déjà, enfin lisible."
            />
            <Link href="/features" className="group inline-flex items-center gap-2 text-sm font-semibold text-white">
              Toutes les fonctionnalités
              <Icon name="arrowRight" className="h-4 w-4 transition-transform group-hover:translate-x-0.5" strokeWidth={2} />
            </Link>
          </div>
          <div className="mt-12">
            <FeatureGrid dark limit={6} />
          </div>
        </div>
      </section>
      <Stats />
      <Pricing />
      <Faq />
      <CtaBand />
    </>
  );
}
