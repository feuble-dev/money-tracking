"""
Clés de licence hors ligne signées Ed25519 (format `MT2-…`).

L'ancien format `MT-XXXXXXXX-XXXXXXXXAAAAMMJJ` ne pouvait pas être vérifié
par l'app sans y embarquer le secret HMAC : hors ligne, l'app n'en
contrôlait que le format, donc n'importe quelle clé bien formée l'activait.
Avec une signature asymétrique, l'app ne détient que la clé PUBLIQUE :
elle vérifie sans pouvoir signer.

Contenu signé (13 octets) : agence_id (u32) · date de fin en jours depuis
2020-01-01 (u16) · empreinte de l'appareil (6 octets) · statut (u8).
Clé = `MT2-` + base64url(contenu + signature de 64 octets), ~107 caractères :
à transmettre par copier-coller (WhatsApp) ou QR code, pas à recopier.

La clé privée est dérivée de LICENCE_SECRET (déjà configuré en
production) : aucune nouvelle variable d'environnement.
"""
import base64
import hashlib
import struct
from datetime import date, timedelta
from functools import lru_cache

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from django.conf import settings

PREFIXE = 'MT2-'
EPOCH = date(2020, 1, 1)
_FORMAT = '>IH6sB'
_TAILLE = struct.calcsize(_FORMAT)  # 13
STATUTS = {'active': 1, 'essai': 2}
_STATUTS_INV = {v: k for k, v in STATUTS.items()}


@lru_cache(maxsize=2)
def _cle_depuis(secret: str) -> Ed25519PrivateKey:
    graine = hashlib.sha256(f'moneytracking-ed25519:{secret}'.encode()).digest()
    return Ed25519PrivateKey.from_private_bytes(graine)


def _cle_privee() -> Ed25519PrivateKey:
    # Mise en cache : la liste admin signe une clé par ligne.
    return _cle_depuis(settings.LICENCE_SECRET)


def cle_publique_b64() -> str:
    brut = _cle_privee().public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    return base64.b64encode(brut).decode()


def empreinte_appareil(device_id: str) -> bytes:
    return hashlib.sha256(device_id.encode()).digest()[:6]


def signer(agence_id: int, device_id: str, date_fin: date, statut: str) -> str:
    contenu = struct.pack(
        _FORMAT, agence_id, (date_fin - EPOCH).days,
        empreinte_appareil(device_id), STATUTS.get(statut, 1),
    )
    signature = _cle_privee().sign(contenu)
    return PREFIXE + base64.urlsafe_b64encode(contenu + signature).decode().rstrip('=')


def verifier(cle: str, device_id: str):
    """Renvoie {agence_id, date_fin, statut} si la clé est authentique et
    émise pour cet appareil, sinon None. N'examine pas l'expiration."""
    cle = cle.strip()
    if not cle.startswith(PREFIXE):
        return None
    corps = cle[len(PREFIXE):]
    try:
        brut = base64.urlsafe_b64decode(corps + '=' * (-len(corps) % 4))
    except (ValueError, TypeError):
        return None
    if len(brut) != _TAILLE + 64:
        return None
    contenu, signature = brut[:_TAILLE], brut[_TAILLE:]
    try:
        _cle_privee().public_key().verify(signature, contenu)
    except InvalidSignature:
        return None
    agence_id, jours, empreinte, statut = struct.unpack(_FORMAT, contenu)
    if empreinte != empreinte_appareil(device_id):
        return None
    return {
        'agence_id': agence_id,
        'date_fin': EPOCH + timedelta(days=jours),
        'statut': _STATUTS_INV.get(statut, 'active'),
    }


def cle_pour_licence(licence) -> str:
    return signer(licence.agence_id, licence.device_id, licence.date_fin, licence.statut)
