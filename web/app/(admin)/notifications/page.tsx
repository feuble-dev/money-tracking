'use client';

import React, { useEffect, useState } from 'react';
import { getNotifications, envoyerNotification, getClients } from '@/lib/api';

interface Notif {
  id: number;
  titre: string;
  message: string;
  cible: string;
  telephones: string;
  created_at: string;
}

interface Client {
  id: number;
  telephone: string;
  nom: string;
  prenom: string;
}

export default function NotificationsPage() {
  const [notifs, setNotifs] = useState<Notif[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [sending, setSending] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');

  // Form state
  const [titre, setTitre] = useState('');
  const [message, setMessage] = useState('');
  const [cible, setCible] = useState<'all' | 'individual' | 'group'>('all');
  const [selectedTels, setSelectedTels] = useState<string[]>([]);
  const [searchTel, setSearchTel] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [n, c] = await Promise.all([getNotifications(), getClients()]);
      setNotifs(n);
      setClients(c);
    } catch {
      setNotifs([]);
      setClients([]);
    } finally {
      setLoading(false);
    }
  };

  const handleSend = async () => {
    if (!titre.trim() || !message.trim()) return;
    setSending(true);
    setSuccessMsg('');
    try {
      const telephones = cible === 'all' ? '' : selectedTels.join(',');
      const res = await envoyerNotification({
        titre: titre.trim(),
        message: message.trim(),
        cible,
        telephones,
      });
      setSuccessMsg(res.message || 'Notification envoyée');
      setTitre('');
      setMessage('');
      setSelectedTels([]);
      setShowForm(false);
      loadData();
    } catch {
      setSuccessMsg('Erreur lors de l\'envoi');
    } finally {
      setSending(false);
    }
  };

  const toggleTel = (tel: string) => {
    setSelectedTels(prev =>
      prev.includes(tel) ? prev.filter(t => t !== tel) : [...prev, tel]
    );
  };

  const filteredClients = clients.filter(c =>
    c.telephone.includes(searchTel) ||
    `${c.nom} ${c.prenom}`.toLowerCase().includes(searchTel.toLowerCase())
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-12 h-12 rounded-full border-4 border-primary/20 border-t-primary animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-extrabold text-dark">Notifications</h1>
          <p className="text-muted text-sm mt-1">Envoyez des messages à vos utilisateurs</p>
        </div>
        <button onClick={() => setShowForm(!showForm)}
          className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-primary to-primary-light text-white font-bold rounded-xl shadow-blue hover:shadow-xl transition-all text-sm">
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Nouvelle notification
        </button>
      </div>

      {/* Success message */}
      {successMsg && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 text-emerald-700 rounded-2xl text-sm flex items-center gap-2">
          <svg className="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          {successMsg}
        </div>
      )}

      {/* Send form */}
      {showForm && (
        <div className="bg-white rounded-2xl border border-gray-100 p-6 shadow-soft">
          <h3 className="text-lg font-bold text-dark mb-4">Envoyer une notification</h3>

          <div className="space-y-4">
            {/* Titre */}
            <div>
              <label className="block text-sm font-semibold text-dark mb-1.5">Titre *</label>
              <input type="text" value={titre} onChange={e => setTitre(e.target.value)}
                placeholder="Ex: Mise à jour disponible"
                className="w-full px-4 py-3 bg-soft border border-gray-200 rounded-xl outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-sm" />
            </div>

            {/* Message */}
            <div>
              <label className="block text-sm font-semibold text-dark mb-1.5">Message *</label>
              <textarea value={message} onChange={e => setMessage(e.target.value)}
                rows={3} placeholder="Contenu de la notification..."
                className="w-full px-4 py-3 bg-soft border border-gray-200 rounded-xl outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-sm resize-none" />
            </div>

            {/* Cible */}
            <div>
              <label className="block text-sm font-semibold text-dark mb-1.5">Destinataires</label>
              <div className="flex gap-3">
                {([
                  { value: 'all' as const, label: 'Tout le monde', icon: '🌍' },
                  { value: 'individual' as const, label: 'Un utilisateur', icon: '👤' },
                  { value: 'group' as const, label: 'Un groupe', icon: '👥' },
                ]).map(opt => (
                  <button key={opt.value}
                    onClick={() => { setCible(opt.value); setSelectedTels([]); }}
                    className={`flex-1 flex items-center gap-2 px-4 py-3 rounded-xl border text-sm font-medium transition-all ${
                      cible === opt.value
                        ? 'border-primary bg-primary-50 text-primary'
                        : 'border-gray-200 text-muted hover:border-gray-300'
                    }`}>
                    <span>{opt.icon}</span>
                    {opt.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Selection clients */}
            {cible !== 'all' && (
              <div>
                <label className="block text-sm font-semibold text-dark mb-1.5">
                  Sélectionner les destinataires ({selectedTels.length} sélectionné{selectedTels.length > 1 ? 's' : ''})
                </label>
                <input type="text" value={searchTel} onChange={e => setSearchTel(e.target.value)}
                  placeholder="Rechercher par téléphone ou nom..."
                  className="w-full px-4 py-2.5 bg-soft border border-gray-200 rounded-xl outline-none focus:ring-2 focus:ring-primary/20 text-sm mb-3" />

                {/* Selected badges */}
                {selectedTels.length > 0 && (
                  <div className="flex flex-wrap gap-2 mb-3">
                    {selectedTels.map(tel => (
                      <span key={tel}
                        className="inline-flex items-center gap-1 px-3 py-1 bg-primary-50 text-primary text-xs font-semibold rounded-full">
                        {tel}
                        <button onClick={() => toggleTel(tel)} className="hover:text-red-500">×</button>
                      </span>
                    ))}
                  </div>
                )}

                <div className="max-h-48 overflow-y-auto border border-gray-100 rounded-xl divide-y divide-gray-50">
                  {filteredClients.length === 0 ? (
                    <div className="p-4 text-center text-muted text-sm">Aucun client trouvé</div>
                  ) : (
                    filteredClients.slice(0, 20).map(c => (
                      <label key={c.id}
                        className="flex items-center gap-3 px-4 py-3 hover:bg-soft cursor-pointer transition-colors">
                        <input type="checkbox"
                          checked={selectedTels.includes(c.telephone)}
                          onChange={() => toggleTel(c.telephone)}
                          className="rounded border-gray-300 text-primary focus:ring-primary" />
                        <div className="flex-1">
                          <div className="text-sm font-medium text-dark">
                            {c.nom} {c.prenom}
                          </div>
                          <div className="text-xs text-muted">{c.telephone}</div>
                        </div>
                      </label>
                    ))
                  )}
                </div>
              </div>
            )}

            {/* Buttons */}
            <div className="flex gap-3 pt-2">
              <button onClick={() => setShowForm(false)}
                className="px-5 py-2.5 border border-gray-200 text-muted font-medium rounded-xl hover:bg-gray-50 text-sm">
                Annuler
              </button>
              <button onClick={handleSend} disabled={sending || !titre.trim() || !message.trim()}
                className="flex-1 px-5 py-2.5 bg-gradient-to-r from-primary to-primary-light text-white font-bold rounded-xl shadow-blue hover:shadow-xl transition-all text-sm disabled:opacity-50">
                {sending ? (
                  <span className="flex items-center justify-center gap-2">
                    <span className="w-4 h-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />
                    Envoi...
                  </span>
                ) : (
                  `Envoyer${cible === 'all' ? ' à tout le monde' : ` à ${selectedTels.length} personne(s)`}`
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Notifications list */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-soft">
        <div className="p-6 border-b border-gray-50">
          <h3 className="text-lg font-bold text-dark">Historique des notifications</h3>
          <p className="text-sm text-muted mt-0.5">{notifs.length} notification(s) envoyée(s)</p>
        </div>

        {notifs.length === 0 ? (
          <div className="p-12 text-center">
            <svg className="w-16 h-16 text-gray-200 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
            </svg>
            <p className="text-muted">Aucune notification envoyée</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-50">
            {notifs.map(n => (
              <div key={n.id} className="p-5 hover:bg-soft/50 transition-colors">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <h4 className="text-sm font-bold text-dark">{n.titre}</h4>
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                        n.cible === 'all'
                          ? 'bg-blue-50 text-blue-600'
                          : n.cible === 'individual'
                          ? 'bg-violet-50 text-violet-600'
                          : 'bg-emerald-50 text-emerald-600'
                      }`}>
                        {n.cible === 'all' ? 'Tous' : n.cible === 'individual' ? 'Individuel' : 'Groupe'}
                      </span>
                    </div>
                    <p className="text-sm text-muted leading-relaxed">{n.message}</p>
                    {n.telephones && (
                      <div className="flex flex-wrap gap-1 mt-2">
                        {n.telephones.split(',').filter(Boolean).map((t, i) => (
                          <span key={i} className="px-2 py-0.5 bg-gray-100 text-gray-600 text-[10px] rounded-full">
                            {t.trim()}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                  <span className="text-xs text-muted whitespace-nowrap">
                    {new Date(n.created_at).toLocaleDateString('fr-FR', {
                      day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit'
                    })}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
