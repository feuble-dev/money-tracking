import React from 'react';
import Hero from '@/components/site/Hero';
import Operators from '@/components/site/Operators';
import Chapter from '@/components/site/Chapter';
import SmsDecoder from '@/components/site/SmsDecoder';
import { AgenceShowcase, ParticulierShowcase } from '@/components/site/Showcase';
import MadeForHere from '@/components/site/MadeForHere';
import Comparison from '@/components/site/Comparison';
import Privacy from '@/components/site/Privacy';
import Pricing from '@/components/site/Pricing';
import Faq from '@/components/site/Faq';
import CtaBand from '@/components/site/CtaBand';

export default function HomePage() {
  return (
    <>
      <Hero />
      <Operators />

      <section className="bg-white py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter
            mark="Comment ça marche"
            title="Un SMS arrive. Il est déjà rangé."
            text="L’application repère dans chaque SMS de votre opérateur le montant, le numéro, le solde et la référence — et crée l’opération pour vous. Choisissez un opérateur pour voir."
          />
          <div className="mt-14">
            <SmsDecoder />
          </div>
        </div>
      </section>

      <section className="overflow-hidden bg-sand py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <ParticulierShowcase />
        </div>
      </section>

      <section className="overflow-hidden bg-ink py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <AgenceShowcase />
        </div>
      </section>

      <section className="bg-white py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter
            mark="Fait ici, pour ici"
            title="Pensé pour Ouaga, Bobo et Koudougou — pas pour la Silicon Valley."
          />
          <div className="mt-14">
            <MadeForHere />
          </div>
        </div>
      </section>

      <section className="bg-soft py-24 sm:py-28">
        <div className="mx-auto max-w-6xl px-4 sm:px-6">
          <Chapter
            mark="Agents Mobile Money"
            title="Le cahier a bien servi. Il peut prendre sa retraite."
            text="Ce que vous faites déjà chaque jour, sans rien recopier."
          />
          <div className="mt-12">
            <Comparison />
          </div>
        </div>
      </section>

      <Privacy />
      <Pricing />
      <Faq />
      <CtaBand />
    </>
  );
}
