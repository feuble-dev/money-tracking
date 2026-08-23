import hmac
import hashlib
import json
import base64
import math
import re
import secrets
from datetime import date, timedelta
from django.conf import settings


class LicenceService:

    @staticmethod
    def _get_secret() -> str:
        return settings.LICENCE_SECRET

    @staticmethod
    def _signer(payload: str) -> str:
        """Génère signature HMAC-SHA256 (8 premiers chars)"""
        return hmac.new(
            LicenceService._get_secret().encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()[:8].upper()

    @staticmethod
    def generer_code(
        device_id: str,
        telephone: str,
        date_fin: date,
        agence_id: int = None
    ) -> str:
        """
        Génère une clé de licence au format :
        MT-{SIGNATURE}-{PAYLOAD_B32}{DATE}

        Exemple : MT-A3F9BC12-KL82MN7P20260330

        agence_id est intégré au calcul pour éviter les collisions : un même
        device_id/telephone peut désormais générer plusieurs licences le même
        jour (une par agence, D8/D10), donc device_id+telephone+date_fin seuls
        ne suffisent plus à garantir l'unicité du code.
        """
        data = {
            "d": device_id[:8],
            "t": telephone[-4:],
            "f": date_fin.strftime("%Y%m%d"),
            "a": agence_id or 0,
        }
        payload = json.dumps(data, sort_keys=True,
                             separators=(',', ':'))

        signature = LicenceService._signer(payload)

        agence_part = str(agence_id or 0).zfill(4)[-4:]
        device_part = base64.b32encode(
            f"{device_id[:2]}{telephone[-2:]}{agence_part}".encode()
        ).decode().rstrip('=')[:8]

        date_str = date_fin.strftime("%Y%m%d")

        return f"MT-{signature}-{device_part}{date_str}"

    @staticmethod
    def verifier_code(code: str, device_id: str) -> dict:
        """
        Vérifie une clé de licence localement.
        Retourne { valide, date_fin, message }
        """
        try:
            pattern = r'^MT-([A-Z0-9]{8})-([A-Z0-9]{8})(\d{8})$'
            match = re.match(pattern, code.strip().upper())

            if not match:
                return {
                    'valide': False,
                    'message': 'Format de clé invalide'
                }

            date_str = match.group(3)

            date_fin = date(
                int(date_str[:4]),
                int(date_str[4:6]),
                int(date_str[6:8])
            )

            if date.today() > date_fin:
                return {
                    'valide': False,
                    'date_fin': str(date_fin),
                    'message': f'Licence expirée le {date_fin}'
                }

            jours_restants = (date_fin - date.today()).days

            return {
                'valide': True,
                'date_fin': str(date_fin),
                'jours_restants': jours_restants,
                'message': f'Licence valide — '
                           f'expire dans {jours_restants} jours'
            }

        except Exception as e:
            return {
                'valide': False,
                'message': f'Clé invalide : {str(e)}'
            }

    @staticmethod
    def calculer_date_fin(
        duree_mois: int,
        date_fin_actuelle: date = None
    ) -> date:
        """
        Calcule la nouvelle date de fin.
        Si licence existante non expirée -> prolonge.
        """
        base = max(
            date_fin_actuelle or date.today(),
            date.today()
        )
        return base + timedelta(days=30 * duree_mois)

    @staticmethod
    def montant_pour_duree(duree_mois: int) -> int:
        from .models import PricingTier
        tier = PricingTier.objects.filter(
            duree_mois=duree_mois, is_active=True
        ).first()
        if tier:
            return tier.montant()
        return round(PricingTier.BASE_MENSUEL * duree_mois)

    @staticmethod
    def creer_agence_avec_essai(client, nom_agence: str, device_id: str) -> dict:
        """
        Crée une nouvelle agence pour un compte et démarre son essai gratuit
        (durée lue depuis le palier PricingTier(is_essai=True), 3 mois par défaut).
        Chaque agence a droit à son propre essai (D10).
        """
        from .models import Agence, Licence, PricingTier

        essai_tier = PricingTier.objects.filter(
            is_essai=True, is_active=True
        ).first()
        duree_mois = essai_tier.essai_duree_mois if essai_tier else 3

        agence = Agence.objects.create(client=client, nom=nom_agence)

        date_fin = date.today() + timedelta(days=30 * duree_mois)
        code = LicenceService.generer_code(device_id, client.telephone, date_fin, agence.id)

        licence = Licence.objects.create(
            agence=agence,
            code=code,
            device_id=device_id,
            date_debut=date.today(),
            date_fin=date_fin,
            duree_mois=duree_mois,
            montant_paye=0,
            statut='essai',
        )
        return {'agence': agence, 'licence': licence}

    @staticmethod
    def cloner_licence_pour_device(agence, device_id: str):
        """
        Émet une licence pour un second appareil opérant la même agence
        (agent affilié — voir sync.AffiliationRequest). Reprend le statut et
        la date de fin de la licence active de l'agence : c'est la même
        agence, donc le même cycle de vie de licence (D8), juste un
        deuxième device_id autorisé à l'opérer. Ne consomme pas un nouvel
        essai (D10 ne s'applique qu'à la création d'une agence).
        """
        from .models import Licence

        reference = agence.licences.filter(
            statut__in=['active', 'essai']
        ).order_by('-date_fin').first()
        if reference is None:
            return None

        code = LicenceService.generer_code(
            device_id, agence.client.telephone, reference.date_fin, agence.id
        )
        return Licence.objects.create(
            agence=agence,
            code=code,
            device_id=device_id,
            date_debut=reference.date_debut,
            date_fin=reference.date_fin,
            duree_mois=reference.duree_mois,
            montant_paye=0,
            statut=reference.statut,
        )


class HistoriqueService:

    @staticmethod
    def calculer_cout(date_debut: date) -> int:
        """
        Gratuit jusqu'à 1 an en arrière, puis 200 FCFA par année entamée au-delà.
        """
        jours = (date.today() - date_debut).days
        annees_totales = math.ceil(jours / 365) if jours > 0 else 0
        annees_payantes = max(0, annees_totales - 1)
        return annees_payantes * 200

    @staticmethod
    def generer_token(device_id: str, telephone: str) -> str:
        hash_device = hashlib.sha256(
            f"{device_id}{telephone}".encode()
        ).hexdigest()[:8].upper()
        aleatoire = secrets.token_hex(8).upper()
        return f"HT-{hash_device}-{aleatoire}"

    @staticmethod
    def verifier_token(token: str, device_id: str) -> bool:
        from .models import AchatHistorique
        try:
            parts = token.strip().upper().split('-')
            if len(parts) != 3 or parts[0] != 'HT':
                return False
            return AchatHistorique.objects.filter(
                token=token.strip().upper(),
                device_id=device_id,
                statut='active'
            ).exists()
        except Exception:
            return False
