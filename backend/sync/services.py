from django.utils import timezone
from licences.models import Agence
from licences.services import LicenceService
from .models import AffiliationRequest


class AffiliationService:

    @staticmethod
    def approuver(demande: AffiliationRequest, agence: Agence):
        """
        Assigne l'agence choisie par le patron et émet une licence pour le
        device du demandeur — après ça, le flux licence normal (verifier-cle,
        recuperer) fonctionne pour ce device sans rien savoir de
        l'affiliation (D8: c'est juste une agence de plus opérée par un
        deuxième appareil).
        """
        licence = LicenceService.cloner_licence_pour_device(
            agence, demande.demandeur_device_id
        )
        if licence is None:
            raise ValueError(
                "Cette agence n'a pas de licence active — activez-la avant d'y affilier un agent."
            )
        demande.agence = agence
        demande.statut = 'approuve'
        demande.resolved_at = timezone.now()
        demande.save()
        return licence

    @staticmethod
    def rejeter(demande: AffiliationRequest):
        demande.statut = 'rejete'
        demande.resolved_at = timezone.now()
        demande.save()
