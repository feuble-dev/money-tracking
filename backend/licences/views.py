from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from datetime import date, timedelta
from .models import Client, Licence, DemandeActivation, Notification, AchatHistorique
from .services import LicenceService, HistoriqueService
from .serializers import NotificationSerializer


class DemanderActivationView(APIView):
    """
    POST /api/licence/demander/
    Body: { telephone, device_id, duree_mois }
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        duree_mois = int(request.data.get('duree_mois', 1))

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        Client.objects.get_or_create(telephone=telephone)

        demande_existante = DemandeActivation.objects.filter(
            telephone=telephone,
            device_id=device_id,
            statut='en_attente'
        ).first()

        if demande_existante:
            return Response({
                'message': 'Demande déjà en attente',
                'demande_id': demande_existante.id,
                'statut': 'en_attente',
            })

        demande = DemandeActivation.objects.create(
            telephone=telephone,
            device_id=device_id,
            duree_mois=duree_mois,
        )

        montant = LicenceService.montant_pour_duree(duree_mois)

        return Response({
            'message': 'Demande envoyée avec succès',
            'demande_id': demande.id,
            'montant_a_payer': montant,
            'instructions': (
                f'Envoyez {montant} FCFA via Orange Money '
                f'et attendez la validation.'
            ),
        }, status=status.HTTP_201_CREATED)


class RecupererLicenceView(APIView):
    """
    POST /api/licence/recuperer/
    Body: { telephone, device_id }
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        licence = Licence.objects.filter(
            client__telephone=telephone,
            device_id=device_id,
            statut__in=['active', 'essai'],
            date_fin__gte=date.today()
        ).order_by('-date_fin').first()

        if not licence:
            demande = DemandeActivation.objects.filter(
                telephone=telephone,
                device_id=device_id,
                statut='en_attente'
            ).first()

            if demande:
                return Response({
                    'statut': 'en_attente',
                    'message': (
                        'Votre demande est en cours de validation. '
                        'Vous serez notifié dès que c\'est prêt.'
                    ),
                })

            return Response({
                'statut': 'aucune_licence',
                'message': (
                    'Aucune licence trouvée. '
                    'Contactez MoneyTracking pour souscrire.'
                ),
            }, status=status.HTTP_404_NOT_FOUND)

        jours_restants = (licence.date_fin - date.today()).days

        return Response({
            'statut': licence.statut,
            'code': licence.code,
            'date_debut': str(licence.date_debut),
            'date_fin': str(licence.date_fin),
            'jours_restants': jours_restants,
            'duree_mois': licence.duree_mois,
            'message': (
                f'Licence active — '
                f'expire dans {jours_restants} jours'
            ),
        })


class VerifierCleView(APIView):
    """
    POST /api/licence/verifier-cle/
    Body: { code, device_id }
    """
    def post(self, request):
        code = request.data.get('code', '').strip()
        device_id = request.data.get('device_id', '').strip()

        if not code or not device_id:
            return Response(
                {'erreur': 'code et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        resultat = LicenceService.verifier_code(code, device_id)
        return Response(resultat)


class EssaiGratuitView(APIView):
    """
    POST /api/licence/essai/
    Body: { telephone, device_id }
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        essai_existant = Licence.objects.filter(
            device_id=device_id,
            statut='essai'
        ).first()

        if essai_existant:
            return Response({
                'erreur': 'Essai gratuit déjà utilisé sur cet appareil'
            }, status=status.HTTP_400_BAD_REQUEST)

        client, _ = Client.objects.get_or_create(
            telephone=telephone
        )

        date_fin = date.today() + timedelta(days=30)
        code = LicenceService.generer_code(
            device_id, telephone, date_fin
        )

        licence = Licence.objects.create(
            client=client,
            code=code,
            device_id=device_id,
            date_debut=date.today(),
            date_fin=date_fin,
            duree_mois=1,
            montant_paye=0,
            statut='essai',
        )

        return Response({
            'statut': 'essai',
            'code': licence.code,
            'date_fin': str(date_fin),
            'jours_restants': 30,
            'message': 'Essai gratuit activé pour 30 jours',
        }, status=status.HTTP_201_CREATED)


class NotificationsView(APIView):
    """
    GET /api/licence/notifications/?telephone=70123456&after=2026-01-01T00:00:00
    Récupère les notifications pour un utilisateur.
    """
    def get(self, request):
        telephone = request.query_params.get('telephone', '').strip()
        after = request.query_params.get('after', '')

        if not telephone:
            return Response(
                {'erreur': 'telephone requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        qs = Notification.objects.all()
        if after:
            qs = qs.filter(created_at__gt=after)

        # Filtrer: cible='all' OU téléphone dans la liste
        from django.db.models import Q
        notifs = qs.filter(
            Q(cible='all') |
            Q(telephones__contains=telephone)
        ).order_by('-created_at')[:50]

        serializer = NotificationSerializer(notifs, many=True)
        return Response(serializer.data)


class DemanderHistoriqueView(APIView):
    """POST /api/licence/historique/demander/"""
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        client, _ = Client.objects.get_or_create(telephone=telephone)

        achat_existant = AchatHistorique.objects.filter(
            device_id=device_id, statut='active'
        ).first()
        if achat_existant:
            return Response({
                'statut': 'deja_active',
                'token': achat_existant.token,
                'message': 'Import historique déjà activé sur cet appareil',
            })

        demande_existante = AchatHistorique.objects.filter(
            device_id=device_id, statut='en_attente'
        ).first()
        if demande_existante:
            return Response({
                'statut': 'en_attente',
                'message': 'Demande déjà en attente de validation',
            })

        AchatHistorique.objects.create(
            client=client,
            device_id=device_id,
            montant_paye=HistoriqueService.PRIX,
        )
        return Response({
            'statut': 'en_attente',
            'montant': HistoriqueService.PRIX,
            'message': f'Envoyez {HistoriqueService.PRIX} FCFA via Orange Money et attendez la validation.',
        }, status=status.HTTP_201_CREATED)


class RecupererTokenHistoriqueView(APIView):
    """POST /api/licence/historique/recuperer/"""
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()

        achat = AchatHistorique.objects.filter(
            client__telephone=telephone,
            device_id=device_id,
            statut='active'
        ).first()

        if achat:
            return Response({
                'statut': 'active',
                'token': achat.token,
                'message': 'Import historique activé !',
            })
        return Response({
            'statut': 'en_attente',
            'message': 'Pas encore validé',
        }, status=status.HTTP_404_NOT_FOUND)


class VerifierTokenHistoriqueView(APIView):
    """POST /api/licence/historique/verifier/"""
    def post(self, request):
        token = request.data.get('token', '').strip()
        device_id = request.data.get('device_id', '').strip()
        valide = HistoriqueService.verifier_token(token, device_id)
        return Response({'valide': valide})
