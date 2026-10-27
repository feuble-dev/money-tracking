"""
Contrôle d'accès des endpoints client (`/api/licence/`, `/api/sync/`).

L'identité côté client reste telephone + device_id (pas de jeton), mais un
numéro de téléphone n'est PAS un secret : n'importe qui peut le connaître.
Avant ce module, de nombreux endpoints se contentaient du numéro, ce qui
permettait à un tiers de lire tout le détail d'une agence (transactions,
clients), d'approuver sa propre demande d'affiliation sur le compte d'un
autre, ou de rattacher son téléphone au compte de quelqu'un via /essai/.

Règle appliquée : une action « en tant que propriétaire du compte » exige
que le device_id appelant ait été autorisé par le propriétaire lui-même —
création du compte (/essai/), création d'agence, ou connexion par mot de
passe (/login/, D13) — et NON via une affiliation (un agent affilié opère
une agence du patron mais n'agit pas en son nom).
"""
from .models import Client, Licence


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
    pour ne pas révéler quels numéros sont inscrits)."""
    if not telephone or not device_id:
        return None
    client = Client.objects.filter(telephone=telephone).first()
    if client and appareil_proprietaire(client, device_id):
        return client
    return None


ERREUR_APPAREIL = (
    "Cet appareil n'est pas autorisé sur ce compte. "
    "Connectez-vous avec votre mot de passe."
)
