from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from datetime import date
from django.utils import timezone
from .models import Client, Agence, Licence, DemandeActivation, Notification, AchatHistorique
from .services import LicenceService, HistoriqueService
from .serializers import NotificationSerializer


class EssaiGratuitView(APIView):
    """
    POST /api/licence/essai/
    Body: { telephone, device_id, account_type, agence_nom }
    Crée le compte (si nouveau) + sa première agence + l'essai gratuit de cette agence.
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        account_type = request.data.get('account_type', 'agence').strip()
        agence_nom = request.data.get('agence_nom', '').strip() or 'Agence principale'

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if account_type not in dict(Client.ACCOUNT_TYPE_CHOICES):
            account_type = 'agence'

        client, _ = Client.objects.get_or_create(
            telephone=telephone,
            defaults={'account_type': account_type}
        )

        resultat = LicenceService.creer_agence_avec_essai(client, agence_nom, device_id)
        agence = resultat['agence']
        licence = resultat['licence']
        jours_restants = (licence.date_fin - date.today()).days

        return Response({
            'agence_id': agence.id,
            'agence_nom': agence.nom,
            'account_type': client.account_type,
            'statut': 'essai',
            'code': licence.code,
            'date_fin': str(licence.date_fin),
            'jours_restants': jours_restants,
            'message': f'Essai gratuit activé pour {licence.duree_mois} mois',
        }, status=status.HTTP_201_CREATED)


class AgenceCreerView(APIView):
    """
    POST /api/licence/agences/creer/
    Body: { telephone, device_id, nom }
    Ajoute une nouvelle agence à un compte existant, avec son propre essai gratuit (D10).
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        nom = request.data.get('nom', '').strip()

        if not telephone or not device_id or not nom:
            return Response(
                {'erreur': 'telephone, device_id et nom requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            client = Client.objects.get(telephone=telephone)
        except Client.DoesNotExist:
            return Response(
                {'erreur': 'Compte introuvable — utilisez /essai/ pour créer un compte'},
                status=status.HTTP_404_NOT_FOUND
            )

        resultat = LicenceService.creer_agence_avec_essai(client, nom, device_id)
        agence = resultat['agence']
        licence = resultat['licence']
        jours_restants = (licence.date_fin - date.today()).days

        return Response({
            'agence_id': agence.id,
            'agence_nom': agence.nom,
            'statut': 'essai',
            'code': licence.code,
            'date_fin': str(licence.date_fin),
            'jours_restants': jours_restants,
            'message': f'Agence créée avec un essai gratuit de {licence.duree_mois} mois',
        }, status=status.HTTP_201_CREATED)


class AgencesListView(APIView):
    """
    GET /api/licence/agences/?telephone=70123456
    Liste les agences d'un compte avec le statut de licence de chacune
    (utilisé pour le sélecteur multi-agence mobile et la resynchronisation
    après réinstallation).
    """
    def get(self, request):
        telephone = request.query_params.get('telephone', '').strip()
        if not telephone:
            return Response(
                {'erreur': 'telephone requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            client = Client.objects.get(telephone=telephone)
        except Client.DoesNotExist:
            return Response({'account_type': None, 'agences': []})

        today = date.today()
        agences_data = []
        for agence in client.agences.filter(is_active=True).order_by('created_at'):
            licence = agence.licences.filter(
                statut__in=['active', 'essai'], date_fin__gte=today
            ).order_by('-date_fin').first()
            agences_data.append({
                'id': agence.id,
                'nom': agence.nom,
                'statut': licence.statut if licence else 'expiree',
                'code': licence.code if licence else None,
                'date_fin': str(licence.date_fin) if licence else None,
                'jours_restants': (licence.date_fin - today).days if licence else 0,
            })

        return Response({
            'account_type': client.account_type,
            'agences': agences_data,
        })


class DemanderActivationView(APIView):
    """
    POST /api/licence/demander/
    Body: { telephone, device_id, agence_id, duree_mois }
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        agence_id = request.data.get('agence_id')
        duree_mois = int(request.data.get('duree_mois', 1))

        if not telephone or not device_id or not agence_id:
            return Response(
                {'erreur': 'telephone, device_id et agence_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            agence = Agence.objects.get(id=agence_id, client__telephone=telephone)
        except Agence.DoesNotExist:
            return Response(
                {'erreur': 'Agence introuvable pour ce compte'},
                status=status.HTTP_404_NOT_FOUND
            )

        demande_existante = DemandeActivation.objects.filter(
            agence=agence,
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
            agence=agence,
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
    Body: { telephone, device_id, agence_id }
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        agence_id = request.data.get('agence_id')

        if not telephone or not device_id or not agence_id:
            return Response(
                {'erreur': 'telephone, device_id et agence_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        licence = Licence.objects.filter(
            agence_id=agence_id,
            agence__client__telephone=telephone,
            device_id=device_id,
            statut__in=['active', 'essai'],
            date_fin__gte=date.today()
        ).order_by('-date_fin').first()

        if not licence:
            demande = DemandeActivation.objects.filter(
                agence_id=agence_id,
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
                    'Aucune licence trouvée pour cette agence. '
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
    """
    POST /api/licence/historique/demander/
    Body: { telephone, device_id, date_debut }  (date_debut format YYYY-MM-DD,
    la date la plus ancienne à importer — détermine le coût)
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        date_debut_str = request.data.get('date_debut', '').strip()

        if not telephone or not device_id or not date_debut_str:
            return Response(
                {'erreur': 'telephone, device_id et date_debut requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            date_debut = date.fromisoformat(date_debut_str)
        except ValueError:
            return Response(
                {'erreur': 'date_debut invalide (format YYYY-MM-DD)'},
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

        montant = HistoriqueService.calculer_cout(date_debut)

        achat = AchatHistorique.objects.create(
            client=client,
            device_id=device_id,
            date_debut_demandee=date_debut,
            montant_paye=montant,
        )

        if montant == 0:
            achat.token = HistoriqueService.generer_token(device_id, telephone)
            achat.statut = 'active'
            achat.activated_at = timezone.now()
            achat.save()
            return Response({
                'statut': 'active',
                'token': achat.token,
                'montant': 0,
                'message': 'Import historique activé gratuitement (moins d\'un an)',
            }, status=status.HTTP_201_CREATED)

        return Response({
            'statut': 'en_attente',
            'montant': montant,
            'message': f'Envoyez {montant} FCFA via Orange Money et attendez la validation.',
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
