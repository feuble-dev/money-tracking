"""
Suppression d'un compte à la demande de son titulaire (exigence Google Play :
une app qui crée des comptes doit permettre d'en demander la suppression
depuis l'app).

Tout ce qui appartient au compte est effacé, dans l'ordre imposé par les
clés étrangères RESTRICT (D12) : opérations synchronisées, demandes
d'affiliation, licences, agences, achats d'import, jetons d'appareil.

Seule exception : les demandes d'activation **validées** sont des pièces de
paiement (comptabilité). Elles sont gardées mais anonymisées — plus de
numéro ni d'identifiant d'appareil, agence et licence détachées (SET_NULL).
"""
from django.db import transaction

from sync.models import (
    AffiliationRequest, SyncedCaisseOperation, SyncedClient, SyncedTransaction,
)

from .models import AchatHistorique, AppareilAutorise, DemandeActivation, Licence


@transaction.atomic
def supprimer_compte(client) -> None:
    agences = list(client.agences.all())

    SyncedTransaction.objects.filter(agence__in=agences).delete()
    SyncedClient.objects.filter(agence__in=agences).delete()
    SyncedCaisseOperation.objects.filter(agence__in=agences).delete()

    # Demandes reçues par ce compte (patron) et demandes qu'il a envoyées.
    AffiliationRequest.objects.filter(patron=client).delete()
    AffiliationRequest.objects.filter(agence__in=agences).delete()
    AffiliationRequest.objects.filter(demandeur_telephone=client.telephone).delete()

    demandes = DemandeActivation.objects.filter(agence__in=agences) | \
        DemandeActivation.objects.filter(telephone=client.telephone)
    demandes.exclude(statut='validee').delete()
    demandes.filter(statut='validee').update(
        telephone='', device_id='', agence=None, licence=None,
    )

    Licence.objects.filter(agence__in=agences).delete()
    client.agences.all().delete()
    AchatHistorique.objects.filter(client=client).delete()
    AppareilAutorise.objects.filter(client=client).delete()
    client.delete()
