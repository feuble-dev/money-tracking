import hmac
import hashlib
import json
import base64
import re
from datetime import date, timedelta
from django.conf import settings


class LicenceService:

    # Tarifs en FCFA
    TARIFS = {
        1: 1000,
        12: 10000,
        24: 18000,
    }

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
        date_fin: date
    ) -> str:
        """
        Génère une clé de licence au format :
        MT-{SIGNATURE}-{PAYLOAD_B32}{DATE}

        Exemple : MT-A3F9BC12-KL82MN7P20260330
        """
        data = {
            "d": device_id[:8],
            "t": telephone[-4:],
            "f": date_fin.strftime("%Y%m%d"),
        }
        payload = json.dumps(data, sort_keys=True,
                             separators=(',', ':'))

        signature = LicenceService._signer(payload)

        device_part = base64.b32encode(
            f"{device_id[:4]}{telephone[-4:]}".encode()
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
        return LicenceService.TARIFS.get(duree_mois, 1000)


class HistoriqueService:
    PRIX = 2000  # FCFA

    @staticmethod
    def generer_token(device_id: str, telephone: str) -> str:
        import secrets
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
