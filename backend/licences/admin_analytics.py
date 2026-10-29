"""
Tableau de bord admin : indicateurs, recherche globale, fiche client et
actions rapides (suspendre une licence, révoquer un appareil).

Séparé de admin_views.py (CRUD historique) pour garder chaque module lisible.
Toutes les vues exigent un compte staff (IsAdminUser).
"""
from datetime import date, datetime, time, timedelta

from django.db.models import Count, Q, Sum
from django.db.models.functions import TruncDate, TruncWeek
from rest_framework import status
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    AchatHistorique, Agence, AppareilAutorise, Client, DemandeActivation, Licence,
)


def _period(request, default=30):
    try:
        days = int(request.query_params.get('jours', default))
    except ValueError:
        days = default
    return max(7, min(days, 366))


def _since(days):
    return datetime.combine(date.today() - timedelta(days=days - 1), time.min)


def _delta(current, previous):
    """Variation en % (None si pas de base de comparaison)."""
    if not previous:
        return None
    return round((current - previous) / previous * 100, 1)


def _series(qs, field, days, value='count', amount_field=None):
    """Série continue jour par jour (ou semaine par semaine au-delà de
    90 jours) : chaque point existe, même à zéro, pour un graphe régulier."""
    weekly = days > 90
    trunc = TruncWeek(field) if weekly else TruncDate(field)
    rows = qs.annotate(p=trunc).values('p')
    rows = rows.annotate(v=Sum(amount_field) if value == 'sum' else Count('id'))
    found = {}
    for r in rows:
        key = r['p']
        if isinstance(key, datetime):  # TruncWeek renvoie un datetime
            key = key.date()
        found[key] = float(r['v'] or 0)
    start = date.today() - timedelta(days=days - 1)
    points = []
    if weekly:
        cursor = start - timedelta(days=start.weekday())
        step = timedelta(days=7)
    else:
        cursor = start
        step = timedelta(days=1)
    while cursor <= date.today():
        points.append({'date': cursor.isoformat(), 'value': found.get(cursor, 0)})
        cursor += step
    return points


class AdminAnalyticsView(APIView):
    """GET /api/admin/analytics/?jours=30 — tout le tableau de bord en un appel."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        from sync.models import SyncedTransaction

        days = _period(request)
        today = date.today()
        since = _since(days)
        prev_since = _since(days * 2)

        paid = Licence.objects.filter(montant_paye__gt=0)
        clients = Client.objects.all()

        # --- Revenus
        revenue = paid.filter(created_at__gte=since).aggregate(t=Sum('montant_paye'))['t'] or 0
        revenue_prev = paid.filter(created_at__gte=prev_since, created_at__lt=since) \
            .aggregate(t=Sum('montant_paye'))['t'] or 0
        # Revenu mensuel récurrent estimé : licences payantes en cours,
        # ramenées à un mois.
        mrr = 0.0
        for l in paid.filter(statut='active', date_fin__gte=today).only('montant_paye', 'duree_mois'):
            mrr += l.montant_paye / max(l.duree_mois, 1)

        # --- Comptes
        new_clients = clients.filter(created_at__gte=since).count()
        new_clients_prev = clients.filter(created_at__gte=prev_since, created_at__lt=since).count()

        # --- Licences d'agence (les Particuliers sont gratuits : exclus)
        agence_licences = Licence.objects.exclude(agence__client__account_type='particulier')
        live = agence_licences.filter(date_fin__gte=today)
        licence_status = {
            'payantes': live.filter(statut='active', montant_paye__gt=0).values('agence').distinct().count(),
            'essai': live.filter(statut='essai').values('agence').distinct().count(),
            'suspendues': agence_licences.filter(statut='suspendue').values('agence').distinct().count(),
            'expirees': Agence.objects.exclude(client__account_type='particulier')
            .exclude(licences__date_fin__gte=today).filter(is_active=True).count(),
        }
        # Conversion : agences créées il y a plus de 3 mois (essai terminé)
        # qui ont un jour payé.
        mature = Agence.objects.exclude(client__account_type='particulier') \
            .filter(created_at__lt=datetime.combine(today - timedelta(days=90), time.min))
        mature_count = mature.count()
        converted = mature.filter(licences__montant_paye__gt=0).distinct().count()

        expiring = agence_licences.filter(
            statut__in=['active', 'essai'], date_fin__gte=today,
            date_fin__lte=today + timedelta(days=14),
        ).select_related('agence__client').order_by('date_fin')[:12]

        # --- Activité réelle (synchronisée par les agences)
        synced = SyncedTransaction.objects.filter(transaction_created_at__gte=since)
        synced_prev = SyncedTransaction.objects.filter(
            transaction_created_at__gte=prev_since, transaction_created_at__lt=since)
        volume = synced.aggregate(t=Sum('amount'))['t'] or 0
        volume_prev = synced_prev.aggregate(t=Sum('amount'))['t'] or 0

        top_agences = (
            synced.values('agence_id', 'agence__nom', 'agence__client__telephone')
            .annotate(volume=Sum('amount'), n=Count('id'))
            .order_by('-volume')[:6]
        )
        operators = (
            synced.exclude(operator_name='').values('operator_name')
            .annotate(volume=Sum('amount'), n=Count('id'))
            .order_by('-volume')[:6]
        )

        active_devices = AppareilAutorise.objects.filter(
            last_used_at__gte=datetime.combine(today - timedelta(days=30), time.min)
        ).count()

        return Response({
            'periode_jours': days,
            'kpis': {
                'revenus': {'value': revenue, 'delta': _delta(revenue, revenue_prev)},
                'mrr': round(mrr),
                'nouveaux_comptes': {'value': new_clients, 'delta': _delta(new_clients, new_clients_prev)},
                'comptes_total': clients.count(),
                'particuliers': clients.filter(account_type='particulier').count(),
                'agences_comptes': clients.filter(account_type='agence').count(),
                'agences_actives': Agence.objects.filter(is_active=True)
                .exclude(client__account_type='particulier').count(),
                'volume_synchronise': {'value': float(volume), 'delta': _delta(float(volume), float(volume_prev))},
                'transactions_synchronisees': synced.count(),
                'appareils_actifs_30j': active_devices,
                'conversion_essai': round(converted / mature_count * 100, 1) if mature_count else None,
                'demandes_en_attente': DemandeActivation.objects.filter(statut='en_attente').count(),
                'achats_en_attente': AchatHistorique.objects.filter(statut='en_attente').count(),
            },
            'series': {
                'revenus': _series(paid.filter(created_at__gte=since), 'created_at', days,
                                   value='sum', amount_field='montant_paye'),
                'inscriptions_particulier': _series(
                    clients.filter(created_at__gte=since, account_type='particulier'), 'created_at', days),
                'inscriptions_agence': _series(
                    clients.filter(created_at__gte=since, account_type='agence'), 'created_at', days),
                'volume': _series(synced, 'transaction_created_at', days, value='sum', amount_field='amount'),
            },
            'licences': licence_status,
            'expirent_bientot': [{
                'id': l.id,
                'agence_id': l.agence_id,
                'agence': l.agence.nom,
                'telephone': l.agence.client.telephone,
                'statut': l.statut,
                'date_fin': str(l.date_fin),
                'jours': (l.date_fin - today).days,
            } for l in expiring],
            'top_agences': [{
                'id': a['agence_id'],
                'nom': a['agence__nom'],
                'telephone': a['agence__client__telephone'],
                'volume': float(a['volume'] or 0),
                'transactions': a['n'],
            } for a in top_agences],
            'operateurs': [{
                'nom': o['operator_name'],
                'volume': float(o['volume'] or 0),
                'transactions': o['n'],
            } for o in operators],
            'activite': _activity(),
        })


def _activity(limit=12):
    """Derniers événements, triés par date réelle (l'ancienne version triait
    des libellés « Il y a 2j » comme du texte)."""
    events = []
    for c in Client.objects.order_by('-created_at')[:limit]:
        events.append({
            'type': 'compte',
            'texte': f"Nouveau compte {'particulier' if c.account_type == 'particulier' else 'agence'}",
            'detail': c.telephone,
            'date': c.created_at.isoformat(),
        })
    for l in Licence.objects.filter(montant_paye__gt=0).select_related('agence__client').order_by('-created_at')[:limit]:
        events.append({
            'type': 'paiement',
            'texte': f"Licence {l.duree_mois} mois — {l.montant_paye:,} FCFA".replace(',', ' '),
            'detail': f"{l.agence.nom} · {l.agence.client.telephone}",
            'date': l.created_at.isoformat(),
        })
    for d in DemandeActivation.objects.order_by('-created_at')[:limit]:
        events.append({
            'type': 'demande',
            'texte': f"Demande d'activation {d.get_statut_display().lower()}",
            'detail': d.telephone,
            'date': d.created_at.isoformat(),
        })
    events.sort(key=lambda e: e['date'], reverse=True)
    return events[:limit]


class AdminSearchView(APIView):
    """GET /api/admin/recherche/?q=… — recherche globale (palette Ctrl+K)."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        q = request.query_params.get('q', '').strip()
        if len(q) < 2:
            return Response({'clients': [], 'agences': [], 'licences': []})
        clients = Client.objects.filter(
            Q(telephone__icontains=q) | Q(nom__icontains=q) | Q(prenom__icontains=q)
        )[:6]
        agences = Agence.objects.select_related('client').filter(
            Q(nom__icontains=q) | Q(client__telephone__icontains=q))[:6]
        licences = Licence.objects.select_related('agence').filter(code__icontains=q)[:6]
        return Response({
            'clients': [{'id': c.id, 'telephone': c.telephone,
                         'nom': f'{c.prenom} {c.nom}'.strip(), 'type': c.account_type} for c in clients],
            'agences': [{'id': a.id, 'nom': a.nom, 'client_id': a.client_id,
                         'telephone': a.client.telephone} for a in agences],
            'licences': [{'id': l.id, 'code': l.code, 'agence': l.agence.nom,
                          'client_id': l.agence.client_id} for l in licences],
        })


class AdminClientDetailView(APIView):
    """GET /api/admin/clients/<id>/ — fiche complète d'un compte."""
    permission_classes = [IsAdminUser]

    def get(self, request, client_id):
        from sync.models import SyncedTransaction
        try:
            c = Client.objects.get(id=client_id)
        except Client.DoesNotExist:
            return Response({'erreur': 'Compte introuvable'}, status=status.HTTP_404_NOT_FOUND)
        today = date.today()
        agences = []
        for a in c.agences.all().order_by('created_at'):
            lic = a.licences.order_by('-date_fin').first()
            stats = SyncedTransaction.objects.filter(agence=a).aggregate(n=Count('id'), v=Sum('amount'))
            agences.append({
                'id': a.id,
                'nom': a.nom,
                'is_active': a.is_active,
                'created_at': a.created_at.isoformat(),
                'licence': None if lic is None else {
                    'id': lic.id,
                    'statut': lic.statut if lic.date_fin >= today else 'expiree',
                    'date_fin': str(lic.date_fin),
                    'jours': (lic.date_fin - today).days,
                    'code': lic.code,
                },
                'appareils_licencies': a.licences.values('device_id').distinct().count(),
                'transactions_synchronisees': stats['n'] or 0,
                'volume_synchronise': float(stats['v'] or 0),
            })
        return Response({
            'id': c.id,
            'telephone': c.telephone,
            'nom': c.nom,
            'prenom': c.prenom,
            'account_type': c.account_type,
            'a_mot_de_passe': bool(c.password_hash),
            'created_at': c.created_at.isoformat(),
            'agences': agences,
            'appareils': [{
                'id': d.id,
                'device': d.device_id[:12] + '…',
                'origine': d.get_origine_display(),
                'created_at': d.created_at.isoformat(),
                'last_used_at': d.last_used_at.isoformat() if d.last_used_at else None,
            } for d in AppareilAutorise.objects.filter(client=c).order_by('-created_at')],
            'paiements': [{
                'id': l.id,
                'agence': l.agence.nom,
                'montant': l.montant_paye,
                'duree_mois': l.duree_mois,
                'date': l.created_at.isoformat(),
            } for l in Licence.objects.filter(agence__client=c, montant_paye__gt=0)
                .select_related('agence').order_by('-created_at')[:20]],
        })


class AdminLicenceStatutView(APIView):
    """POST /api/admin/licences/<id>/suspendre/ | reactiver/ — en cas de
    fraude ou de litige, sans supprimer l'historique."""
    permission_classes = [IsAdminUser]

    def post(self, request, licence_id, action):
        try:
            licence = Licence.objects.get(id=licence_id)
        except Licence.DoesNotExist:
            return Response({'erreur': 'Licence introuvable'}, status=status.HTTP_404_NOT_FOUND)
        if action == 'suspendre':
            if licence.statut not in ('active', 'essai'):
                return Response({'erreur': 'Seule une licence active ou en essai peut être suspendue'},
                                status=status.HTTP_400_BAD_REQUEST)
            licence.statut = 'suspendue'
        elif action == 'reactiver':
            if licence.statut != 'suspendue':
                return Response({'erreur': "Cette licence n'est pas suspendue"},
                                status=status.HTTP_400_BAD_REQUEST)
            licence.statut = 'active' if licence.montant_paye > 0 or licence.duree_mois == 0 else 'essai'
        else:
            return Response({'erreur': 'Action inconnue'}, status=status.HTTP_400_BAD_REQUEST)
        licence.save(update_fields=['statut', 'updated_at'])
        return Response({'id': licence.id, 'statut': licence.statut})


class AdminAppareilRevoquerView(APIView):
    """DELETE /api/admin/appareils/<id>/ — un téléphone perdu ou volé ne peut
    plus appeler l'API au nom du compte (il devra se reconnecter avec le mot
    de passe)."""
    permission_classes = [IsAdminUser]

    def delete(self, request, appareil_id):
        deleted, _ = AppareilAutorise.objects.filter(id=appareil_id).delete()
        if not deleted:
            return Response({'erreur': 'Appareil introuvable'}, status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)



class AdminCompteursView(APIView):
    """GET /api/admin/compteurs/ — badges de la barre latérale (léger,
    interrogé à chaque navigation, contrairement à /analytics/)."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        today = date.today()
        return Response({
            'demandes': DemandeActivation.objects.filter(statut='en_attente').count(),
            'achats': AchatHistorique.objects.filter(statut='en_attente').count(),
            'expirent': Licence.objects.exclude(agence__client__account_type='particulier')
            .filter(statut__in=['active', 'essai'], date_fin__gte=today,
                    date_fin__lte=today + timedelta(days=7)).count(),
        })
