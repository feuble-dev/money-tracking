from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAdminUser
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from datetime import date
from django.db.models import Sum
from .models import Client, Agence, PricingTier, Licence, DemandeActivation, Notification, AchatHistorique
from .services import LicenceService, HistoriqueService
from .serializers import (
    LicenceSerializer, DemandeActivationSerializer, ClientSerializer,
    NotificationSerializer, AgenceSerializer, PricingTierSerializer,
)


class AdminLoginView(APIView):
    """POST /api/admin/login/ — Authentification admin"""
    def post(self, request):
        username = request.data.get('username', '').strip()
        password = request.data.get('password', '').strip()

        if not username or not password:
            return Response(
                {'erreur': 'username et password requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = authenticate(username=username, password=password)
        if user is None or not user.is_staff:
            return Response(
                {'erreur': 'Identifiants incorrects'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'username': user.username,
        })


class AdminStatsView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        from datetime import timedelta
        from django.db.models.functions import TruncMonth
        from django.db.models import Count

        today = date.today()

        # Stats de base
        licences_actives = Licence.objects.filter(
            statut__in=['active', 'essai'],
            date_fin__gte=today
        ).count()

        # Licences expirant dans 30 jours
        expiring = Licence.objects.filter(
            statut__in=['active', 'essai'],
            date_fin__gte=today,
            date_fin__lte=today + timedelta(days=30)
        ).select_related('agence__client').order_by('date_fin')[:10]

        licences_expirant = [{
            'id': l.id,
            'tel': l.agence.client.telephone,
            'agence': l.agence.nom,
            'code': l.code,
            'expire': str(l.date_fin),
            'jours': (l.date_fin - today).days,
        } for l in expiring]

        # Stats mensuelles (12 derniers mois)
        monthly = (
            Licence.objects
            .filter(created_at__gte=today - timedelta(days=365))
            .annotate(month=TruncMonth('created_at'))
            .values('month')
            .annotate(count=Count('id'), revenue=Sum('montant_paye'))
            .order_by('month')
        )
        monthly_data = [{
            'month': m['month'].strftime('%b'),
            'value': m['count'],
            'revenue': m['revenue'] or 0,
        } for m in monthly]

        # Répartition par type
        repartition = {
            'annuel': Licence.objects.filter(duree_mois__gte=12, statut__in=['active', 'essai'], date_fin__gte=today).count(),
            'mensuel': Licence.objects.filter(duree_mois=1, statut='active', date_fin__gte=today).count(),
            'essai': Licence.objects.filter(statut='essai', date_fin__gte=today).count(),
        }

        # Activité récente
        recent_licences = Licence.objects.select_related('agence__client').order_by('-created_at')[:5]
        recent_demandes = DemandeActivation.objects.order_by('-created_at')[:5]

        activite = []
        for l in recent_licences:
            ago = (today - l.created_at.date()).days
            time_str = "Aujourd'hui" if ago == 0 else f"Il y a {ago}j" if ago < 7 else l.created_at.strftime('%d/%m/%Y')
            activite.append({
                'type': 'essai' if l.statut == 'essai' else 'licence',
                'text': f"{'Essai gratuit' if l.statut == 'essai' else 'Licence générée'} — {l.agence.client.telephone} ({l.agence.nom})",
                'time': time_str,
                'color': 'bg-emerald-500' if l.statut == 'essai' else 'bg-blue-500',
            })
        for d in recent_demandes:
            ago = (today - d.created_at.date()).days
            time_str = "Aujourd'hui" if ago == 0 else f"Il y a {ago}j" if ago < 7 else d.created_at.strftime('%d/%m/%Y')
            activite.append({
                'type': 'demande',
                'text': f"Demande {d.get_statut_display()} — {d.telephone}",
                'time': time_str,
                'color': 'bg-orange-500' if d.statut == 'en_attente' else 'bg-green-500' if d.statut == 'validee' else 'bg-red-500',
            })
        activite.sort(key=lambda x: x['time'], reverse=False)
        activite = activite[:8]

        # Répartition Particulier / Agence (D7)
        comptes_repartition = {
            'particulier': Client.objects.filter(account_type='particulier').count(),
            'agence': Client.objects.filter(account_type='agence').count(),
        }

        # Couverture du catalogue (Pays/Opérateurs/Types, D3)
        from catalog.models import Country, Operator, TransactionType
        catalog_coverage = {
            'countries': Country.objects.filter(is_active=True).count(),
            'operators': Operator.objects.filter(is_active=True).count(),
            'transaction_types': TransactionType.objects.filter(is_active=True).count(),
        }

        # Croissance des agences (12 derniers mois) — unité facturable, D8
        agences_monthly = (
            Agence.objects
            .filter(created_at__gte=today - timedelta(days=365))
            .annotate(month=TruncMonth('created_at'))
            .values('month')
            .annotate(count=Count('id'))
            .order_by('month')
        )
        agences_growth = [{
            'month': m['month'].strftime('%b'),
            'value': m['count'],
        } for m in agences_monthly]

        return Response({
            'licences_actives': licences_actives,
            'clients_total': Client.objects.count(),
            'agences_total': Agence.objects.filter(is_active=True).count(),
            'demandes_en_attente': DemandeActivation.objects.filter(
                statut='en_attente'
            ).count(),
            'revenus_mois': Licence.objects.filter(
                created_at__month=today.month,
                created_at__year=today.year,
                statut='active'
            ).aggregate(total=Sum('montant_paye'))['total'] or 0,
            'licences_expirant': licences_expirant,
            'monthly_data': monthly_data,
            'repartition': repartition,
            'comptes_repartition': comptes_repartition,
            'catalog_coverage': catalog_coverage,
            'agences_growth': agences_growth,
            'activite': activite,
        })


class AdminLicencesListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        licences = Licence.objects.select_related('agence__client').all()
        serializer = LicenceSerializer(licences, many=True)
        return Response(serializer.data)


class AdminGenererLicenceView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request):
        agence_id = request.data.get('agence_id')
        duree_mois = int(request.data.get('duree_mois', 1))
        montant = request.data.get('montant_paye')
        device_id_fallback = request.data.get('device_id', '').strip()

        if not agence_id:
            return Response(
                {'erreur': 'agence_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            agence = Agence.objects.select_related('client').get(id=agence_id)
        except Agence.DoesNotExist:
            return Response(
                {'erreur': 'Agence introuvable'},
                status=status.HTTP_404_NOT_FOUND
            )

        licence_actuelle = agence.licences.filter(
            statut__in=['active', 'essai']
        ).order_by('-date_fin').first()

        device_id = licence_actuelle.device_id if licence_actuelle else device_id_fallback
        if not device_id:
            return Response(
                {'erreur': 'device_id requis (aucune licence existante pour cette agence)'},
                status=status.HTTP_400_BAD_REQUEST
            )

        montant = int(montant) if montant is not None else LicenceService.montant_pour_duree(duree_mois)

        date_fin = LicenceService.calculer_date_fin(
            duree_mois,
            licence_actuelle.date_fin if licence_actuelle else None
        )
        code = LicenceService.generer_code(
            device_id, agence.client.telephone, date_fin, agence.id
        )
        licence = Licence.objects.create(
            agence=agence,
            code=code,
            device_id=device_id,
            date_debut=date.today(),
            date_fin=date_fin,
            duree_mois=duree_mois,
            montant_paye=montant,
            statut='active',
        )
        return Response({
            'code': licence.code,
            'date_fin': str(licence.date_fin),
            'message': 'Licence générée avec succès',
        }, status=status.HTTP_201_CREATED)


class AdminDemandesListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        demandes = DemandeActivation.objects.select_related('agence').all()
        serializer = DemandeActivationSerializer(demandes, many=True)
        return Response(serializer.data)


class AdminValiderDemandeView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, demande_id):
        try:
            demande = DemandeActivation.objects.select_related('agence__client').get(
                id=demande_id, statut='en_attente'
            )
        except DemandeActivation.DoesNotExist:
            return Response(
                {'erreur': 'Demande non trouvée ou déjà traitée'},
                status=status.HTTP_404_NOT_FOUND
            )

        if not demande.agence:
            return Response(
                {'erreur': "Demande sans agence associée — impossible de générer la licence"},
                status=status.HTTP_400_BAD_REQUEST
            )

        agence = demande.agence
        licence_actuelle = agence.licences.filter(
            statut__in=['active', 'essai']
        ).order_by('-date_fin').first()

        date_fin = LicenceService.calculer_date_fin(
            demande.duree_mois,
            licence_actuelle.date_fin if licence_actuelle else None
        )

        code = LicenceService.generer_code(
            demande.device_id, demande.telephone, date_fin, agence.id
        )

        licence = Licence.objects.create(
            agence=agence,
            code=code,
            device_id=demande.device_id,
            date_debut=date.today(),
            date_fin=date_fin,
            duree_mois=demande.duree_mois,
            montant_paye=LicenceService.montant_pour_duree(
                demande.duree_mois
            ),
            statut='active',
        )

        note = request.data.get('note', '')
        demande.statut = 'validee'
        demande.licence = licence
        if note:
            demande.note = note
        demande.save()

        return Response({
            'code': licence.code,
            'date_fin': str(licence.date_fin),
            'message': 'Licence générée et demande validée',
        })


class AdminRejeterDemandeView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, demande_id):
        try:
            demande = DemandeActivation.objects.get(
                id=demande_id, statut='en_attente'
            )
        except DemandeActivation.DoesNotExist:
            return Response(
                {'erreur': 'Demande non trouvée ou déjà traitée'},
                status=status.HTTP_404_NOT_FOUND
            )

        motif = request.data.get('motif', '').strip()
        demande.statut = 'rejetee'
        if motif:
            demande.note = motif
        demande.save()

        return Response({'message': 'Demande rejetée'})


class AdminClientsListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        clients = Client.objects.all()
        serializer = ClientSerializer(clients, many=True)
        return Response(serializer.data)


class AdminAgencesListView(APIView):
    """GET /api/admin/agences/?client_id=... — toutes les agences, ou filtrées par client."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        client_id = request.query_params.get('client_id')
        agences = Agence.objects.select_related('client').all()
        if client_id:
            agences = agences.filter(client_id=client_id)
        serializer = AgenceSerializer(agences, many=True)
        return Response(serializer.data)


class AdminPricingTiersView(APIView):
    """GET/POST /api/admin/pricing-tiers/ — grille tarifaire éditable."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        tiers = PricingTier.objects.all()
        serializer = PricingTierSerializer(tiers, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = PricingTierSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminPricingTierDetailView(APIView):
    """PATCH /api/admin/pricing-tiers/<id>/"""
    permission_classes = [IsAdminUser]

    def patch(self, request, tier_id):
        try:
            tier = PricingTier.objects.get(id=tier_id)
        except PricingTier.DoesNotExist:
            return Response({'erreur': 'Palier introuvable'}, status=status.HTTP_404_NOT_FOUND)

        serializer = PricingTierSerializer(tier, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminNotificationsListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        notifs = Notification.objects.all()[:100]
        serializer = NotificationSerializer(notifs, many=True)
        return Response(serializer.data)


class AdminEnvoyerNotificationView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request):
        titre = request.data.get('titre', '').strip()
        message = request.data.get('message', '').strip()
        cible = request.data.get('cible', 'all').strip()
        telephones = request.data.get('telephones', '').strip()

        if not titre or not message:
            return Response(
                {'erreur': 'titre et message requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if cible in ('individual', 'group') and not telephones:
            return Response(
                {'erreur': 'telephones requis pour cible individual/group'},
                status=status.HTTP_400_BAD_REQUEST
            )

        notif = Notification.objects.create(
            titre=titre,
            message=message,
            cible=cible,
            telephones=telephones,
        )

        # Compter les destinataires
        if cible == 'all':
            count = Client.objects.count()
        else:
            count = len([t for t in telephones.split(',') if t.strip()])

        return Response({
            'id': notif.id,
            'destinataires': count,
            'message': f'Notification envoyée à {count} utilisateur(s)',
        }, status=status.HTTP_201_CREATED)


class AdminAchatsHistoriqueListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        achats = AchatHistorique.objects.select_related('client').all()
        return Response([{
            'id': a.id,
            'telephone': a.client.telephone,
            'device_id': a.device_id[:16],
            'date_debut_demandee': str(a.date_debut_demandee) if a.date_debut_demandee else None,
            'statut': a.statut,
            'token': a.token,
            'montant_paye': a.montant_paye,
            'created_at': a.created_at.isoformat(),
        } for a in achats])


class AdminValiderAchatHistoriqueView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, achat_id):
        from django.utils import timezone
        try:
            achat = AchatHistorique.objects.get(id=achat_id, statut='en_attente')
        except AchatHistorique.DoesNotExist:
            return Response(
                {'erreur': 'Achat non trouvé ou déjà traité'},
                status=status.HTTP_404_NOT_FOUND
            )

        achat.token = HistoriqueService.generer_token(
            achat.device_id, achat.client.telephone
        )
        achat.statut = 'active'
        achat.activated_at = timezone.now()
        achat.save()

        return Response({
            'token': achat.token,
            'message': 'Achat validé avec succès',
        })
