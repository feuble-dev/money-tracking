'use client';

import React, { useState } from 'react';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { login } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const data = await login(username, password);
      localStorage.setItem('admin_token', data.token || data.key || 'demo-token');
      router.push('/dashboard');
    } catch {
      // Demo mode: accept admin/admin123
      if (username === 'admin' && password === 'admin123') {
        localStorage.setItem('admin_token', 'demo-token');
        router.push('/dashboard');
        return;
      }
      setError('Identifiants incorrects. Veuillez réessayer.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen gradient-hero flex items-center justify-center p-4 relative overflow-hidden">
      {/* Background elements */}
      <div className="absolute inset-0">
        <div className="absolute top-20 left-10 w-72 h-72 bg-white/5 rounded-full blur-3xl" />
        <div className="absolute bottom-20 right-10 w-96 h-96 bg-accent/10 rounded-full blur-3xl" />
        <div className="absolute inset-0 opacity-[0.05]" style={{
          backgroundImage: 'radial-gradient(circle at 1px 1px, white 1px, transparent 0)',
          backgroundSize: '40px 40px',
        }} />
      </div>

      <div className="relative w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <Image src="/logo.png" alt="MoneyTracking" width={64} height={64}
            className="mx-auto rounded-2xl shadow-2xl mb-4" />
          <h1 className="text-2xl font-extrabold text-white">Administration</h1>
          <p className="text-blue-200 text-sm mt-1">MoneyTracking - Gestion des licences</p>
        </div>

        {/* Form Card */}
        <div className="bg-white rounded-3xl shadow-2xl p-8">
          <h2 className="text-xl font-extrabold text-dark mb-1">Connexion</h2>
          <p className="text-muted text-sm mb-6">Entrez vos identifiants administrateur</p>

          {error && (
            <div className="mb-4 p-3 bg-red-50 text-red-700 text-sm rounded-xl flex items-center gap-2 border border-red-100">
              <svg className="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="block text-sm font-semibold text-dark mb-2">Nom d&apos;utilisateur</label>
              <input type="text" value={username} onChange={(e) => setUsername(e.target.value)}
                placeholder="admin" required
                className="w-full px-4 py-3.5 bg-soft border border-gray-200 rounded-2xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm" />
            </div>
            <div>
              <label className="block text-sm font-semibold text-dark mb-2">Mot de passe</label>
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••" required
                className="w-full px-4 py-3.5 bg-soft border border-gray-200 rounded-2xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all text-sm" />
            </div>

            <button type="submit" disabled={loading}
              className="w-full py-4 bg-gradient-to-r from-primary to-primary-light text-white font-bold rounded-2xl shadow-blue hover:shadow-xl hover:-translate-y-0.5 transition-all duration-300 disabled:opacity-60 disabled:pointer-events-none text-sm">
              {loading ? (
                <span className="flex items-center justify-center gap-2">
                  <span className="w-4 h-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />
                  Connexion...
                </span>
              ) : (
                'Se connecter'
              )}
            </button>
          </form>
        </div>

        <p className="text-center text-blue-300/60 text-xs mt-6">
          &copy; {new Date().getFullYear()} MoneyTracking par FEUBLE-TechBuilder
        </p>
      </div>
    </div>
  );
}
