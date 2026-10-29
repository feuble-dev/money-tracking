'use client';

import React, { useMemo, useState } from 'react';
import Icon from '@/components/site/Icon';
import Badge from '@/components/ui/Badge';
import Button from '@/components/ui/Button';
import Card from '@/components/admin/ui/Card';
import PageHeader from '@/components/admin/ui/PageHeader';
import Segmented from '@/components/admin/ui/Segmented';
import Field, { FormError, inputCls } from '@/components/admin/ui/Field';
import { useAdmin } from '@/components/admin/shell/AdminContext';
import { envoyerNotification, getClients, getNotifications } from '@/lib/api';
import { useAsync } from '@/lib/useAsync';
import { apiError, type ClientRow, type NotificationRow } from '@/lib/admin-types';
import { ago, dateFr } from '@/lib/format';

type Cible = 'all' | 'choix';

const TITRE_MAX = 60;
const MESSAGE_MAX = 300;

export default function NotificationsPage() {
  const { toast } = useAdmin();
  const history = useAsync(getNotifications);
  const clients = useAsync(getClients);

  const [titre, setTitre] = useState('');
  const [message, setMessage] = useState('');
  const [cible, setCible] = useState<Cible>('all');
  const [selected, setSelected] = useState<string[]>([]);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');

  const send = async (e: React.FormEvent) => {
    e.preventDefault();
    if (cible === 'choix' && selected.length === 0) return setError('Choisissez au moins un destinataire.');
    setSending(true);
    setError('');
    try {
      const r = await envoyerNotification({
        titre: titre.trim(),
        message: message.trim(),
        cible: cible === 'all' ? 'all' : selected.length === 1 ? 'individual' : 'group',
        telephones: cible === 'all' ? undefined : selected.join(','),
      });
      toast(r.message ?? 'Notification envoyée');
      setTitre('');
      setMessage('');
      setSelected([]);
      history.reload();
    } catch (err) {
      setError(apiError(err, 'L’envoi a échoué'));
    } finally {
      setSending(false);
    }
  };

  const total = clients.data?.length ?? 0;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Notifications"
        description="Un message qui s’affiche dans l’application des utilisateurs choisis, à leur prochaine connexion."
      />

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-5">
        <Card title="Nouveau message" className="xl:col-span-3">
          <form onSubmit={send} className="space-y-4">
            <FormError>{error}</FormError>
            <div>
              <p className="mb-1.5 text-sm font-medium text-gray-700">Destinataires</p>
              <Segmented
                value={cible}
                onChange={setCible}
                options={[
                  { value: 'all', label: `Tout le monde${total ? ` · ${total}` : ''}` },
                  { value: 'choix', label: 'Choisir…' },
                ]}
              />
            </div>
            {cible === 'choix' && (
              <RecipientPicker clients={clients.data ?? []} selected={selected} onChange={setSelected} />
            )}
            <Field label="Titre" hint={`${titre.length}/${TITRE_MAX}`}>
              <input
                value={titre}
                maxLength={TITRE_MAX}
                onChange={(e) => setTitre(e.target.value)}
                placeholder="Ex. : Nouvelle version disponible"
                className={inputCls}
                required
              />
            </Field>
            <Field label="Message" hint={`${message.length}/${MESSAGE_MAX}`}>
              <textarea
                value={message}
                maxLength={MESSAGE_MAX}
                onChange={(e) => setMessage(e.target.value)}
                rows={4}
                placeholder="Ce que l’utilisateur doit savoir, en une ou deux phrases."
                className={`${inputCls} h-auto resize-none py-2.5`}
                required
              />
            </Field>
            <div className="flex justify-end">
              <Button type="submit" loading={sending} disabled={!titre.trim() || !message.trim()}>
                <Icon name="send" className="h-4 w-4" strokeWidth={2} />
                {cible === 'all' ? 'Envoyer à tout le monde' : `Envoyer à ${selected.length} personne${selected.length > 1 ? 's' : ''}`}
              </Button>
            </div>
          </form>
        </Card>

        <Card title="Aperçu" subtitle="Tel qu’il apparaîtra sur le téléphone" className="xl:col-span-2">
          <div className="rounded-2xl bg-[#0E1621] p-4">
            <div className="rounded-xl bg-white p-3.5 shadow-sm">
              <div className="flex items-center gap-2 text-[11px] text-muted">
                <span className="flex h-5 w-5 items-center justify-center rounded-md bg-primary text-white">
                  <Icon name="bell" className="h-3 w-3" strokeWidth={2} />
                </span>
                <span className="font-semibold text-ink">MoneyTracking</span>
                <span>· maintenant</span>
              </div>
              <p className="mt-2 break-words text-sm font-semibold text-ink">{titre || 'Titre du message'}</p>
              <p className="mt-0.5 whitespace-pre-line break-words text-sm text-gray-600">{message || 'Le texte du message apparaît ici.'}</p>
            </div>
          </div>
        </Card>
      </div>

      <Card title="Déjà envoyées" padded={false}>
        <History rows={history.data} loading={history.loading} error={history.error} />
      </Card>
    </div>
  );
}

/** Choix des destinataires : recherche + raccourcis par type de compte. */
function RecipientPicker({
  clients,
  selected,
  onChange,
}: {
  clients: ClientRow[];
  selected: string[];
  onChange: (tels: string[]) => void;
}) {
  const [q, setQ] = useState('');
  const set = useMemo(() => new Set(selected), [selected]);
  const matches = useMemo(() => {
    const term = q.trim().toLowerCase();
    if (!term) return [];
    return clients
      .filter((c) => !set.has(c.telephone) && `${c.telephone} ${c.nom} ${c.prenom}`.toLowerCase().includes(term))
      .slice(0, 6);
  }, [q, clients, set]);

  const addType = (t: ClientRow['account_type']) =>
    onChange(Array.from(new Set([...selected, ...clients.filter((c) => c.account_type === t).map((c) => c.telephone)])));

  return (
    <div className="space-y-3 rounded-xl border border-gray-200 p-3">
      <div className="flex flex-wrap gap-2">
        <Button type="button" size="sm" variant="subtle" onClick={() => addType('particulier')}>+ Tous les particuliers</Button>
        <Button type="button" size="sm" variant="subtle" onClick={() => addType('agence')}>+ Toutes les agences</Button>
        {selected.length > 0 && (
          <Button type="button" size="sm" variant="ghost" onClick={() => onChange([])}>Vider</Button>
        )}
      </div>
      <div className="relative">
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Ajouter un numéro ou un nom…"
          className={inputCls}
        />
        {matches.length > 0 && (
          <ul className="absolute inset-x-0 top-11 z-10 overflow-hidden rounded-lg border border-gray-200 bg-white shadow-lg">
            {matches.map((c) => (
              <li key={c.id}>
                <button
                  type="button"
                  onClick={() => {
                    onChange([...selected, c.telephone]);
                    setQ('');
                  }}
                  className="flex w-full items-center justify-between px-3 py-2 text-left text-sm hover:bg-soft"
                >
                  <span className="tabular-nums text-ink">{c.telephone}</span>
                  <span className="text-xs text-muted">{`${c.prenom} ${c.nom}`.trim() || (c.account_type === 'agence' ? 'Agence' : 'Particulier')}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
      {selected.length > 0 && (
        <div className="flex max-h-32 flex-wrap gap-1.5 overflow-y-auto">
          {selected.map((t) => (
            <span key={t} className="inline-flex items-center gap-1 rounded-md bg-soft py-1 pl-2 pr-1 text-xs tabular-nums text-ink">
              {t}
              <button type="button" aria-label={`Retirer ${t}`} onClick={() => onChange(selected.filter((x) => x !== t))} className="rounded p-0.5 text-muted hover:bg-gray-200 hover:text-ink">
                <Icon name="close" className="h-3 w-3" strokeWidth={2.2} />
              </button>
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

function History({ rows, loading, error }: { rows: NotificationRow[] | null; loading: boolean; error: string | null }) {
  if (error) return <p className="px-5 pb-6 pt-3 text-sm text-red-700">{error}</p>;
  if (loading && !rows) return <p className="px-5 pb-6 pt-3 text-sm text-muted">Chargement…</p>;
  if (!rows?.length) return <p className="px-5 pb-6 pt-3 text-sm text-muted">Aucune notification envoyée.</p>;
  return (
    <ul className="divide-y divide-gray-100">
      {rows.map((n) => {
        const nb = n.telephones ? n.telephones.split(',').filter(Boolean).length : 0;
        return (
          <li key={n.id} className="flex gap-4 px-5 py-4">
            <div className="min-w-0 flex-1">
              <p className="font-medium text-ink">{n.titre}</p>
              <p className="mt-0.5 line-clamp-2 text-sm text-muted">{n.message}</p>
            </div>
            <div className="flex flex-shrink-0 flex-col items-end gap-1.5">
              <Badge variant={n.cible === 'all' ? 'info' : 'violet'}>{n.cible === 'all' ? 'Tout le monde' : `${nb} destinataire${nb > 1 ? 's' : ''}`}</Badge>
              <span title={dateFr(n.created_at, true)} className="text-xs text-muted">{ago(n.created_at)}</span>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
