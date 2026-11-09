"""
Contrôle d'accès des endpoints client (`/api/licence/`, `/api/sync/`).

Deux niveaux :

1. **Authentifier l'appareil** — un `device_id` ne prouve rien (il se
   devine : les anciennes versions envoyaient `Build.ID`, identique sur tous
   les téléphones d'un même firmware). L'appareil présente donc un jeton
   secret (`X-Device-Token`) émis par le serveur à la création du compte,
   à la connexion par mot de passe, à une demande d'affiliation, ou une
   seule fois pour une installation antérieure (`AppareilAutorise`).

2. **Autoriser l'action** — un numéro de téléphone n'est pas un secret.
   Une action « en tant que propriétaire du compte » exige en plus que
   l'appareil ait été autorisé par le propriétaire lui-même (création ou
   connexion par mot de passe) et NON via une affiliation : un agent
   affilié opère une agence du patron mais n'agit pas en son nom.
"""
import hashlib
import secrets
from functools import wraps

from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response

from .models import AppareilAutorise, Client, Licence

ENTETE_JETON = 'HTTP_X_DEVICE_TOKEN'

ERREUR_APPAREIL = (
    "Cet appareil n'est pas autorisé sur ce compte. "
    "Connectez-vous avec votre mot de passe."
)
ERREUR_JETON = (
    "Appareil non authentifié. Mettez à jour l'application, "
    "puis reconnectez-vous si besoin."
)


def _hash(jeton: str) -> str:
    return hashlib.sha256(jeton.encode()).hexdigest()


# --- Jetons d'appareil -------------------------------------------------------

def emettre_jeton(device_id: str, origine: str, client=None) -> str:
    """Crée un jeton pour cet appareil et le renvoie EN CLAIR (une seule
    fois : seul son hash est conservé)."""
    jeton = secrets.token_urlsafe(32)
    AppareilAutorise.objects.create(
        device_id=device_id, jeton_hash=_hash(jeton),
        client=client, origine=origine,
    )
    return jeton


def appareil_authentifie(request, device_id: str) -> bool:
    jeton = request.META.get(ENTETE_JETON, '').strip()
    if not jeton or not device_id:
        return False
    cred = AppareilAutorise.objects.filter(
        device_id=device_id, jeton_hash=_hash(jeton)
    ).first()
    if cred is None:
        return False
    # Pas plus d'une écriture par heure et par appareil.
    now = timezone.now()
    if cred.last_used_at is None or (now - cred.last_used_at).total_seconds() > 3600:
        AppareilAutorise.objects.filter(pk=cred.pk).update(last_used_at=now)
    return True


def appareil_connu(device_id: str) -> bool:
    return AppareilAutorise.objects.filter(device_id=device_id).exists()


def _device_id_de(request) -> str:
    for source in (request.data if hasattr(request, 'data') else {}, request.query_params):
        for cle in ('device_id', 'demandeur_device_id'):
            valeur = source.get(cle) if hasattr(source, 'get') else None
            if valeur:
                return str(valeur).strip()
    return ''


def exige_jeton(methode):
    """Décorateur de méthode de vue : 401 si l'appareil (`device_id` du
    corps ou de la query string) ne présente pas un jeton valide."""
    @wraps(methode)
    def wrapper(self, request, *args, **kwargs):
        if not appareil_authentifie(request, _device_id_de(request)):
            return Response(
                {'erreur': ERREUR_JETON, 'code': 'jeton_appareil'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        return methode(self, request, *args, **kwargs)
    return wrapper


# --- Propriétaire du compte --------------------------------------------------

def appareil_proprietaire(client: Client, device_id: str) -> bool:
    if not client or not device_id:
        return False
    if not Licence.objects.filter(
        agence__client=client, device_id=device_id
    ).exists():
        return False
    # Import local : sync dépend déjà de licences.
    from sync.models import AffiliationRequest
    return not AffiliationRequest.objects.filter(
        patron=client, demandeur_device_id=device_id, statut='approuve'
    ).exists()


def client_proprietaire(telephone: str, device_id: str):
    """Le Client propriétaire de `telephone` si `device_id` est l'un de ses
    appareils autorisés, sinon None (même réponse que « compte inconnu »,
    pour ne pas révéler quels numéros sont inscrits). L'authenticité de
    l'appareil (jeton) est vérifiée en amont par `exige_jeton`."""
    if not telephone or not device_id:
        return None
    client = Client.objects.filter(telephone=telephone).first()
    if client and appareil_proprietaire(client, device_id):
        return client
    return None
