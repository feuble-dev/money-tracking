from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAdminUser
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from datetime import date
from django.db.models import Sum
from .models import Client, Licence, DemandeActivation, Notification, AchatHistorique
from .services import LicenceService, HistoriqueService
from .serializers import LicenceSerializer, DemandeActivationSerializer, ClientSerializer, NotificationSerializer


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
        ).select_related('client').order_by('date_fin')[:10]

        licences_expirant = [{
            'id': l.id,
            'tel': l.client.telephone,
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
        recent_licences = Licence.objects.select_related('client').order_by('-created_at')[:5]
        recent_demandes = DemandeActivation.objects.order_by('-created_at')[:5]

        activite = []
        for l in recent_licences:
            ago = (today - l.created_at.date()).days
            time_str = "Aujourd'hui" if ago == 0 else f"Il y a {ago}j" if ago < 7 else l.created_at.strftime('%d/%m/%Y')
            activite.append({
                'type': 'essai' if l.statut == 'essai' else 'licence',
                'text': f"{'Essai gratuit' if l.statut == 'essai' else 'Licence générée'} — {l.client.telephone}",
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

        return Response({
            'licences_actives': licences_actives,
            'clients_total': Client.objects.count(),
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
            'activite': activite,
        })


class AdminLicencesListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        licences = Licence.objects.select_related('client').all()
        serializer = LicenceSerializer(licences, many=True)
        return Response(serializer.data)


class AdminGenererLicenceView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        duree_mois = int(request.data.get('duree_mois', 1))
        montant = int(request.data.get('montant_paye', 0))

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        client, _ = Client.objects.get_or_create(
            telephone=telephone
        )

        licence_actuelle = Licence.objects.filter(
            client=client,
            device_id=device_id,
            statut='active'
        ).order_by('-date_fin').first()

        date_fin = LicenceService.calculer_date_fin(
            duree_mois,
            licence_actuelle.date_fin if licence_actuelle else None
        )
        code = LicenceService.generer_code(
            device_id, telephone, date_fin
        )
        licence = Licence.objects.create(
            client=client,
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
        demandes = DemandeActivation.objects.all()
        serializer = DemandeActivationSerializer(demandes, many=True)
        return Response(serializer.data)


class AdminValiderDemandeView(APIView):
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

        client, _ = Client.objects.get_or_create(
            telephone=demande.telephone
        )

        licence_actuelle = Licence.objects.filter(
            client=client,
            device_id=demande.device_id,
            statut='active'
        ).order_by('-date_fin').first()

        date_fin = LicenceService.calculer_date_fin(
            demande.duree_mois,
            licence_actuelle.date_fin if licence_actuelle else None
        )

        code = LicenceService.generer_code(
            demande.device_id, demande.telephone, date_fin
        )

        licence = Licence.objects.create(
            client=client,
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

        demande.statut = 'rejetee'
        demande.save()

        return Response({'message': 'Demande rejetée'})


class AdminClientsListView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        clients = Client.objects.all()
        serializer = ClientSerializer(clients, many=True)
        return Response(serializer.data)


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
