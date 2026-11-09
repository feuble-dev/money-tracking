'use client';

import React, { useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import Button from '@/components/ui/Button';
import Field, { FormError, inputCls } from '@/components/admin/ui/Field';
import { login } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const data = await login(username.trim(), password);
      localStorage.setItem('admin_token', data.token);
      router.replace('/dashboard');
    } catch (err) {
      const status = (err as { response?: { status?: number } }).response?.status;
      setError(
        status === 429
          ? 'Trop de tentatives. Patientez une minute.'
          : status
            ? 'Identifiant ou mot de passe incorrect.'
            : 'Le serveur ne répond pas. Vérifiez votre connexion.',
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen bg-soft">
      <div className="relative hidden w-[42%] flex-col justify-between overflow-hidden bg-ink p-10 text-white lg:flex">
        <div className="bg-grid absolute inset-0 opacity-[0.08] invert" />
        <Link href="/" className="relative flex items-center gap-2.5">
          <Image src="/logo.png" alt="" width={34} height={34} className="rounded-lg" />
          <span className="font-display text-lg font-bold">MoneyTracking</span>
        </Link>
        <div className="relative">
          <p className="font-display text-3xl font-bold leading-tight">
            Licences, agences et catalogue,
            <br />
            au même endroit.
          </p>
          <p className="mt-4 max-w-sm text-white/60">
            Validez les paiements, suivez l’activité et corrigez un modèle de SMS : la correction arrive sur tous les
            téléphones au démarrage suivant.
          </p>
        </div>
        <p className="relative text-xs text-white/40">© {new Date().getFullYear()} FEUBLE-TechBuilder</p>
      </div>

      <div className="flex flex-1 items-center justify-center p-6">
        <form onSubmit={submit} className="fade-up w-full max-w-sm space-y-5">
          <div className="lg:hidden">
            <Image src="/logo.png" alt="" width={40} height={40} className="rounded-xl" />
          </div>
          <div>
            <h1 className="font-display text-2xl font-bold text-ink">Administration</h1>
            <p className="mt-1 text-sm text-muted">Connectez-vous avec votre compte administrateur.</p>
          </div>
          <FormError>{error}</FormError>
          <Field label="Identifiant">
            <input
              autoFocus
              autoComplete="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className={`${inputCls} h-11`}
              required
            />
          </Field>
          <Field label="Mot de passe">
            <input
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={`${inputCls} h-11`}
              required
            />
          </Field>
          <Button type="submit" size="lg" loading={loading} className="w-full">
            Se connecter
          </Button>
        </form>
      </div>
    </div>
  );
}
