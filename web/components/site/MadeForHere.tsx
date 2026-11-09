import React from 'react';
import Reveal from './motion/Reveal';

const facts = [
  {
    k: '0 Mo',
    title: 'Pas besoin de forfait',
    text: 'Les SMS sont lus sur le téléphone. Internet ne sert qu’à la synchronisation, quand il y en a.',
  },
  {
    k: '4',
    title: 'Opérateurs déjà configurés',
    text: 'Orange Money, Moov Money, Coris Money et Wave : leurs SMS sont reconnus dès l’installation.',
  },
  {
    k: 'FCFA',
    title: 'Les montants comme chez nous',
    text: '« 1 521,00 », « 25 000 F », « 7000 FCFA » : chaque façon d’écrire un montant est bien lue.',
  },
  {
    k: 'Android 6+',
    title: 'Fait pour les téléphones d’ici',
    text: 'Tecno, Infinix, Itel, Samsung : un réglage guidé empêche le téléphone de couper l’app pour économiser la batterie.',
  },
  {
    k: '*144#',
    title: 'Vos codes USSD en un geste',
    text: 'Choisissez l’opération et le montant : le code est composé, le SMS de confirmation fait le reste.',
  },
  {
    k: '100 %',
    title: 'Vos dépenses restent chez vous',
    text: 'Ce que vous achetez ne quitte pas votre téléphone. Même pas pour nous.',
  },
];

/** Ce qui rend l'application adaptée au Burkina Faso, concrètement. */
export default function MadeForHere() {
  return (
    <div className="grid gap-x-10 gap-y-12 sm:grid-cols-2 lg:grid-cols-3">
      {facts.map((f, i) => (
        <Reveal key={f.title} delay={(i % 3) * 80}>
          <p className="font-display text-4xl font-bold tracking-tight text-clay">{f.k}</p>
          <p className="mt-3 font-display text-lg font-bold text-ink">{f.title}</p>
          <p className="mt-1.5 leading-relaxed text-muted">{f.text}</p>
        </Reveal>
      ))}
    </div>
  );
}
