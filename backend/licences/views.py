from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.throttling import ScopedRateThrottle
from datetime import date
from django.utils import timezone
from django.contrib.auth.hashers import make_password, check_password
from .models import Client, Agence, Licence, DemandeActivation, Notification, AchatHistorique
from .services import LicenceService, HistoriqueService
from .serializers import NotificationSerializer
from . import signature
from .auth import (
    ERREUR_APPAREIL, appareil_authentifie, appareil_connu,
    appareil_proprietaire, client_proprietaire, emettre_jeton, exige_jeton,
)


class EssaiGratuitView(APIView):
    """
    POST /api/licence/essai/
    Body: { telephone, device_id, account_type, agence_nom, password }
    Crée le compte (si nouveau) + sa première agence + l'essai gratuit de cette agence.
    `password` (D13) est obligatoire pour tout nouveau compte — c'est ce qui
    permet ensuite une connexion instantanée depuis un autre appareil
    (LoginView) sans passer par l'affiliation/approbation.
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        account_type = request.data.get('account_type', 'agence').strip()
        agence_nom = request.data.get('agence_nom', '').strip() or 'Agence principale'
        password = request.data.get('password', '').strip()

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if account_type not in dict(Client.ACCOUNT_TYPE_CHOICES):
            account_type = 'agence'

        client_existant = Client.objects.filter(telephone=telephone).first()
        if client_existant is not None:
            # Avant : n'importe qui connaissant le numéro pouvait créer une
            # agence (et une licence pour SON appareil) sur le compte d'un
            # autre, sans mot de passe. On exige soit un appareil déjà
            # autorisé par le propriétaire, soit le bon mot de passe.
            mot_de_passe_ok = bool(
                password and client_existant.password_hash
                and check_password(password, client_existant.password_hash)
            )
            appareil_ok = (appareil_authentifie(request, device_id)
                           and appareil_proprietaire(client_existant, device_id))
            if not (mot_de_passe_ok or appareil_ok):
                return Response(
                    {'erreur': (
                        'Ce numéro a déjà un compte MoneyTracking. '
                        'Choisissez « J\'ai déjà un compte » pour vous connecter.'
                    )},
                    status=status.HTTP_403_FORBIDDEN
                )
        if client_existant is None and not password:
            return Response(
                {'erreur': 'password requis pour créer un compte'},
                status=status.HTTP_400_BAD_REQUEST
            )

        client, cree = Client.objects.get_or_create(
            telephone=telephone,
            defaults={'account_type': account_type}
        )
        if cree and password:
            client.password_hash = make_password(password)
            client.save(update_fields=['password_hash'])

        resultat = LicenceService.creer_agence_avec_essai(client, agence_nom, device_id)
        agence = resultat['agence']
        licence = resultat['licence']
        jours_restants = (licence.date_fin - date.today()).days

        reponse = {
            'agence_id': agence.id,
            'agence_nom': agence.nom,
            'account_type': client.account_type,
            'statut': licence.statut,
            'code': licence.code,
            'cle_hors_ligne': signature.cle_pour_licence(licence),
            'date_fin': str(licence.date_fin),
            'jours_restants': jours_restants,
            'message': (
                'Compte créé — MoneyTracking est gratuit pour les particuliers'
                if client.account_type == 'particulier'
                else f'Essai gratuit activé pour {licence.duree_mois} mois'
            ),
        }
        # Un appareil déjà authentifié garde son jeton ; sinon on en émet un.
        if not appareil_authentifie(request, device_id):
            reponse['device_token'] = emettre_jeton(
                device_id, 'creation' if cree else 'connexion', client)
        return Response(reponse, status=status.HTTP_201_CREATED)


class AgenceCreerView(APIView):
    """
    POST /api/licence/agences/creer/
    Body: { telephone, device_id, nom }
    Ajoute une nouvelle agence à un compte existant, avec son propre essai gratuit (D10).
    """
    @exige_jeton
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
        if not appareil_proprietaire(client, device_id):
            return Response({'erreur': ERREUR_APPAREIL},
                            status=status.HTTP_403_FORBIDDEN)

        resultat = LicenceService.creer_agence_avec_essai(client, nom, device_id)
        agence = resultat['agence']
        licence = resultat['licence']
        jours_restants = (licence.date_fin - date.today()).days

        return Response({
            'agence_id': agence.id,
            'agence_nom': agence.nom,
            'statut': licence.statut,
            'code': licence.code,
            'cle_hors_ligne': signature.cle_pour_licence(licence),
            'date_fin': str(licence.date_fin),
            'jours_restants': jours_restants,
            'message': f'Agence créée avec un essai gratuit de {licence.duree_mois} mois',
        }, status=status.HTTP_201_CREATED)


class AgencesListView(APIView):
    """
    GET /api/licence/agences/?telephone=70123456&device_id=...
    Liste les agences d'un compte avec le statut de licence de chacune
    (utilisé pour le sélecteur multi-agence mobile et la resynchronisation
    après réinstallation). Réservé aux appareils du propriétaire : la
    réponse contient les codes de licence.
    """
    @exige_jeton
    def get(self, request):
        telephone = request.query_params.get('telephone', '').strip()
        device_id = request.query_params.get('device_id', '').strip()
        if not telephone:
            return Response(
                {'erreur': 'telephone requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        client = client_proprietaire(telephone, device_id)
        if client is None:
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


class LoginView(APIView):
    """
    POST /api/licence/login/
    Body: { telephone, password, device_id }

    Connexion instantanée à un compte existant depuis un nouvel appareil
    (D13) : le mot de passe prouve la propriété du compte, ce qui évite de
    passer par l'affiliation/approbation manuelle du patron
    (sync.AffiliationRequest — toujours valable pour un agent qui n'est PAS
    le propriétaire du compte). Émet, pour chaque agence du client, une
    licence dédiée à ce device_id si aucune n'existe déjà
    (LicenceService.cloner_licence_pour_device, déjà utilisé pour
    l'affiliation) — après ça, le flux licence normal fonctionne pour ce
    device sans rien savoir de la façon dont il a été autorisé.
    """
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'login'

    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        password = request.data.get('password', '').strip()
        device_id = request.data.get('device_id', '').strip()

        if not telephone or not password or not device_id:
            return Response(
                {'erreur': 'telephone, password et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            client = Client.objects.get(telephone=telephone)
        except Client.DoesNotExist:
            return Response(
                {'erreur': 'Identifiants incorrects'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        if not client.password_hash or not check_password(password, client.password_hash):
            return Response(
                {'erreur': 'Identifiants incorrects'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        today = date.today()
        agences_data = []
        for agence in client.agences.filter(is_active=True).order_by('created_at'):
            licence = Licence.objects.filter(
                agence=agence, device_id=device_id
            ).order_by('-date_fin').first()
            if licence is None:
                licence = LicenceService.cloner_licence_pour_device(agence, device_id)

            if licence is None:
                # Agence sans aucune licence active/essai à cloner — on la
                # liste quand même comme expirée, cohérent avec AgencesListView.
                agences_data.append({
                    'id': agence.id,
                    'nom': agence.nom,
                    'statut': 'expiree',
                    'code': None,
                    'date_fin': None,
                    'jours_restants': 0,
                })
                continue

            agences_data.append({
                'id': agence.id,
                'nom': agence.nom,
                'statut': licence.statut,
                'code': licence.code,
                'cle_hors_ligne': signature.cle_pour_licence(licence),
                'date_fin': str(licence.date_fin),
                'jours_restants': (licence.date_fin - today).days,
            })

        reponse = {
            'account_type': client.account_type,
            'agences': agences_data,
        }
        if not appareil_authentifie(request, device_id):
            reponse['device_token'] = emettre_jeton(device_id, 'connexion', client)
        return Response(reponse)


class DemanderActivationView(APIView):
    """
    POST /api/licence/demander/
    Body: { telephone, device_id, agence_id, duree_mois }
    """
    @exige_jeton
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
        # Le payeur peut être le patron ou l'agent affilié qui opère
        # l'agence : il suffit que CET appareil y ait déjà une licence.
        if not Licence.objects.filter(agence=agence, device_id=device_id).exists():
            return Response({'erreur': ERREUR_APPAREIL},
                            status=status.HTTP_403_FORBIDDEN)

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

    Le filtre n'exige PAS que `telephone` corresponde au client propriétaire
    de l'agence : un agent affilié (voir sync.AffiliationRequest) opère une
    agence dont le propriétaire ("patron") a un numéro différent du sien.
    L'autorisation réelle est device_id+agence_id — c'est justement pour ça
    que LicenceService.cloner_licence_pour_device émet une Licence dédiée au
    device de l'agent affilié plutôt que de réutiliser celle du patron.
    """
    @exige_jeton
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
            'cle_hors_ligne': signature.cle_pour_licence(licence),
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

    La clé doit correspondre à une licence réellement émise pour cet
    appareil. Avant, seul le FORMAT était contrôlé (la signature n'était
    jamais recalculée) : « MT-00000000-0000000020991231 » était acceptée.
    """
    @exige_jeton
    def post(self, request):
        code = request.data.get('code', '').strip().upper()
        device_id = request.data.get('device_id', '').strip()

        if not code or not device_id:
            return Response(
                {'erreur': 'code et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if code.startswith(signature.PREFIXE.upper()):
            # Clé signée : on la re-lit avec sa casse d'origine (base64url).
            infos = signature.verifier(request.data.get('code', '').strip(), device_id)
            if infos is None:
                return Response({'valide': False, 'message': 'Clé invalide pour cet appareil'})
            licence = Licence.objects.filter(
                agence_id=infos['agence_id'], device_id=device_id,
                date_fin=infos['date_fin'],
            ).first()
        else:
            format_ok = LicenceService.verifier_code(code, device_id)
            if not format_ok.get('valide'):
                return Response(format_ok)
            licence = Licence.objects.filter(code=code, device_id=device_id).first()
        if licence is None:
            return Response({
                'valide': False,
                'message': "Clé inconnue pour cet appareil",
            })
        if licence.statut not in ('active', 'essai'):
            return Response({
                'valide': False,
                'message': f"Licence {licence.get_statut_display().lower()}",
            })
        jours_restants = (licence.date_fin - date.today()).days
        if jours_restants < 0:
            return Response({
                'valide': False,
                'date_fin': str(licence.date_fin),
                'message': f'Licence expirée le {licence.date_fin}',
            })
        return Response({
            'valide': True,
            'statut': licence.statut,
            'agence_id': licence.agence_id,
            'date_fin': str(licence.date_fin),
            'jours_restants': jours_restants,
            'message': f'Licence valide — expire dans {jours_restants} jours',
        })


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
    @exige_jeton
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

        # Un achat ne couvre que la période demandée : avant, n'importe quel
        # achat actif (même l'import GRATUIT ≤ 1 an) débloquait ensuite
        # l'import de n'importe quelle période — 5 ans compris — sans payer.
        couverture = HistoriqueService.couverture(device_id)
        if couverture and (couverture[0] is None or couverture[0] <= date_debut):
            date_couverte, achat_couvrant = couverture
            return Response({
                'statut': 'deja_active',
                'token': achat_couvrant.token,
                'date_debut_couverte': str(date_couverte) if date_couverte else None,
                'message': 'Cette période est déjà couverte par votre achat',
            })

        demande_existante = AchatHistorique.objects.filter(
            device_id=device_id, statut='en_attente'
        ).first()
        if demande_existante:
            return Response({
                'statut': 'en_attente',
                'montant': demande_existante.montant_paye,
                'message': 'Demande déjà en attente de validation',
            })

        # On ne refacture pas les années déjà payées : seul l'écart entre la
        # nouvelle période et celle déjà couverte est dû.
        montant = HistoriqueService.calculer_cout(date_debut)
        if client.account_type == 'particulier':
            montant = 0  # MoneyTracking est gratuit pour les particuliers
        if couverture:
            montant = max(0, montant - HistoriqueService.calculer_cout_couverture(couverture[0]))

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
                'date_debut_couverte': str(date_debut),
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
    @exige_jeton
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()

        achat = AchatHistorique.objects.filter(
            client__telephone=telephone,
            device_id=device_id,
            statut='active'
        ).order_by('-activated_at').first()

        if achat:
            couverture = HistoriqueService.couverture(device_id)
            return Response({
                'statut': 'active',
                'token': achat.token,
                'date_debut_couverte': (
                    str(couverture[0]) if couverture and couverture[0] else None
                ),
                'message': 'Import historique activé !',
            })
        return Response({
            'statut': 'en_attente',
            'message': 'Pas encore validé',
        }, status=status.HTTP_404_NOT_FOUND)


class VerifierTokenHistoriqueView(APIView):
    """POST /api/licence/historique/verifier/"""
    @exige_jeton
    def post(self, request):
        token = request.data.get('token', '').strip()
        device_id = request.data.get('device_id', '').strip()
        valide = HistoriqueService.verifier_token(token, device_id)
        return Response({'valide': valide})


class AppareilEnregistrerView(APIView):
    """
    POST /api/licence/appareil/enregistrer/
    Body: { device_id }

    Migration des installations antérieures au jeton d'appareil : un
    appareil qui a déjà une licence ou une demande d'affiliation, mais aucun
    jeton, en reçoit un — UNE seule fois (le premier qui le réclame). Ensuite,
    un nouveau jeton pour ce device_id ne s'obtient qu'en se connectant avec
    le mot de passe du compte (/login/).
    """
    def post(self, request):
        device_id = request.data.get('device_id', '').strip()
        if not device_id:
            return Response({'erreur': 'device_id requis'},
                            status=status.HTTP_400_BAD_REQUEST)
        if appareil_authentifie(request, device_id):
            return Response({'message': 'Appareil déjà authentifié'})
        if appareil_connu(device_id):
            return Response(
                {'erreur': ERREUR_APPAREIL, 'code': 'connexion_requise'},
                status=status.HTTP_403_FORBIDDEN)
        from sync.models import AffiliationRequest
        installe = (
            Licence.objects.filter(device_id=device_id).exists()
            or AffiliationRequest.objects.filter(demandeur_device_id=device_id).exists()
        )
        if not installe:
            return Response({'erreur': 'Appareil inconnu'},
                            status=status.HTTP_404_NOT_FOUND)
        licence = Licence.objects.filter(device_id=device_id).select_related(
            'agence__client').first()
        client = licence.agence.client if licence else None
        return Response({
            'device_token': emettre_jeton(device_id, 'migration', client),
        }, status=status.HTTP_201_CREATED)


class ClePubliqueView(APIView):
    """GET /api/licence/cle-publique/ — clé Ed25519 qui permet à l'app de
    vérifier HORS LIGNE les clés `MT2-…` (voir licences/signature.py)."""
    def get(self, request):
        return Response({'algorithme': 'ed25519', 'cle': signature.cle_publique_b64()})
