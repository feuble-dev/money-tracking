from datetime import datetime
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from licences.models import Client, Agence, Licence
from .models import AffiliationRequest, SyncedTransaction, SyncedClient, SyncedCaisseOperation
from .services import AffiliationService


class DemanderAffiliationView(APIView):
    """
    POST /api/sync/demander-affiliation/
    Body: { demandeur_telephone, demandeur_device_id, patron_telephone }
    Le demandeur saisit le numéro de son "patron" (mécanisme confirmé :
    saisie du numéro, pas de code d'invitation) pour demander à opérer une
    de ses agences.
    """
    def post(self, request):
        demandeur_telephone = request.data.get('demandeur_telephone', '').strip()
        demandeur_device_id = request.data.get('demandeur_device_id', '').strip()
        patron_telephone = request.data.get('patron_telephone', '').strip()

        if not demandeur_telephone or not demandeur_device_id or not patron_telephone:
            return Response(
                {'erreur': 'demandeur_telephone, demandeur_device_id et patron_telephone requis'},
                status=status.HTTP_400_BAD_REQUEST
            )
        if demandeur_telephone == patron_telephone:
            return Response(
                {'erreur': 'Vous ne pouvez pas vous affilier à votre propre numéro'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            patron = Client.objects.get(telephone=patron_telephone)
        except Client.DoesNotExist:
            return Response(
                {'erreur': 'Ce numéro n\'est pas enregistré sur MoneyTracking'},
                status=status.HTTP_404_NOT_FOUND
            )
        if patron.account_type != 'agence':
            return Response(
                {'erreur': 'Ce numéro n\'est pas un compte Agence'},
                status=status.HTTP_400_BAD_REQUEST
            )

        existante = AffiliationRequest.objects.filter(
            demandeur_device_id=demandeur_device_id,
            patron=patron,
            statut='en_attente',
        ).first()
        if existante:
            return Response({
                'demande_id': existante.id,
                'statut': 'en_attente',
                'message': 'Demande déjà en attente de validation',
            })

        demande = AffiliationRequest.objects.create(
            demandeur_telephone=demandeur_telephone,
            demandeur_device_id=demandeur_device_id,
            patron=patron,
        )
        return Response({
            'demande_id': demande.id,
            'statut': 'en_attente',
            'message': f'Demande envoyée à {patron_telephone} — en attente de validation',
        }, status=status.HTTP_201_CREATED)


class AffiliationStatutView(APIView):
    """
    GET /api/sync/affiliation-statut/?device_id=...
    Le mobile du demandeur poll cet endpoint jusqu'à approbation/rejet.
    """
    def get(self, request):
        device_id = request.query_params.get('device_id', '').strip()
        if not device_id:
            return Response({'erreur': 'device_id requis'}, status=status.HTTP_400_BAD_REQUEST)

        demande = AffiliationRequest.objects.filter(
            demandeur_device_id=device_id
        ).order_by('-created_at').first()
        if not demande:
            return Response({'statut': 'aucune'})

        data = {'demande_id': demande.id, 'statut': demande.statut}
        if demande.statut == 'approuve' and demande.agence:
            licence = Licence.objects.filter(
                agence=demande.agence, device_id=device_id
            ).order_by('-date_fin').first()
            data.update({
                'agence_id': demande.agence.id,
                'agence_nom': demande.agence.nom,
                'licence_code': licence.code if licence else None,
            })
        return Response(data)


class DemandesEnAttenteView(APIView):
    """
    GET /api/sync/demandes-en-attente/?telephone=patron_telephone
    Le patron consulte les demandes d'affiliation reçues, pour approuver
    depuis son propre téléphone.
    """
    def get(self, request):
        telephone = request.query_params.get('telephone', '').strip()
        if not telephone:
            return Response({'erreur': 'telephone requis'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            patron = Client.objects.get(telephone=telephone)
        except Client.DoesNotExist:
            return Response({'demandes': []})

        demandes = AffiliationRequest.objects.filter(
            patron=patron, statut='en_attente'
        ).order_by('-created_at')
        return Response({
            'demandes': [
                {
                    'id': d.id,
                    'demandeur_telephone': d.demandeur_telephone,
                    'created_at': d.created_at.isoformat(),
                }
                for d in demandes
            ],
        })


class ApprouverAffiliationView(APIView):
    """
    POST /api/sync/affiliation/<id>/approuver/
    Body: { telephone (patron), agence_id }
    """
    def post(self, request, pk):
        telephone = request.data.get('telephone', '').strip()
        agence_id = request.data.get('agence_id')

        try:
            demande = AffiliationRequest.objects.get(id=pk, patron__telephone=telephone)
        except AffiliationRequest.DoesNotExist:
            return Response({'erreur': 'Demande introuvable'}, status=status.HTTP_404_NOT_FOUND)
        if demande.statut != 'en_attente':
            return Response({'erreur': 'Demande déjà traitée'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            agence = Agence.objects.get(id=agence_id, client__telephone=telephone)
        except Agence.DoesNotExist:
            return Response({'erreur': 'Agence introuvable pour ce compte'}, status=status.HTTP_404_NOT_FOUND)

        try:
            AffiliationService.approuver(demande, agence)
        except ValueError as e:
            return Response({'erreur': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response({'message': f'{demande.demandeur_telephone} peut maintenant opérer {agence.nom}'})


class RejeterAffiliationView(APIView):
    """POST /api/sync/affiliation/<id>/rejeter/  Body: { telephone (patron) }"""
    def post(self, request, pk):
        telephone = request.data.get('telephone', '').strip()
        try:
            demande = AffiliationRequest.objects.get(id=pk, patron__telephone=telephone)
        except AffiliationRequest.DoesNotExist:
            return Response({'erreur': 'Demande introuvable'}, status=status.HTTP_404_NOT_FOUND)
        if demande.statut != 'en_attente':
            return Response({'erreur': 'Demande déjà traitée'}, status=status.HTTP_400_BAD_REQUEST)

        AffiliationService.rejeter(demande)
        return Response({'message': 'Demande rejetée'})


class MesAgencesView(APIView):
    """
    GET /api/sync/mes-agences/?telephone=patron_telephone
    Vue "patron" : toutes ses agences (qu'il les opère lui-même ou via un
    agent affilié) avec un résumé de synchronisation.
    """
    def get(self, request):
        telephone = request.query_params.get('telephone', '').strip()
        if not telephone:
            return Response({'erreur': 'telephone requis'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            patron = Client.objects.get(telephone=telephone)
        except Client.DoesNotExist:
            return Response({'agences': []})

        agences_data = []
        for agence in patron.agences.filter(is_active=True).order_by('nom'):
            last_sync = SyncedTransaction.objects.filter(agence=agence).order_by('-synced_at').first()
            agences_data.append({
                'id': agence.id,
                'nom': agence.nom,
                'tx_count': SyncedTransaction.objects.filter(agence=agence).count(),
                'last_synced_at': last_sync.synced_at.isoformat() if last_sync else None,
            })
        return Response({'agences': agences_data})


class AgenceSyncDetailView(APIView):
    """
    GET /api/sync/agence-detail/<id>/?telephone=patron_telephone
    Détail complet en lecture seule (droits confirmés) d'une agence pour
    son patron — transactions/clients/opérations caisse synchronisés.
    """
    def get(self, request, pk):
        telephone = request.query_params.get('telephone', '').strip()
        try:
            agence = Agence.objects.get(id=pk, client__telephone=telephone)
        except Agence.DoesNotExist:
            return Response({'erreur': 'Agence introuvable pour ce compte'}, status=status.HTTP_404_NOT_FOUND)

        transactions = SyncedTransaction.objects.filter(agence=agence)[:200]
        clients = SyncedClient.objects.filter(agence=agence)[:200]
        caisse_operations = SyncedCaisseOperation.objects.filter(agence=agence)[:200]

        return Response({
            'agence': {'id': agence.id, 'nom': agence.nom},
            'transactions': [
                {
                    'local_id': t.local_id,
                    'operator_name': t.operator_name,
                    'transaction_type_label': t.transaction_type_label,
                    'direction': t.direction,
                    'amount': str(t.amount),
                    'commission': str(t.commission),
                    'client_phone': t.client_phone,
                    'client_name': t.client_name,
                    'status': t.status,
                    'source': t.source,
                    'created_at': t.transaction_created_at.isoformat(),
                }
                for t in transactions
            ],
            'clients': [
                {
                    'local_id': c.local_id,
                    'first_name': c.first_name,
                    'last_name': c.last_name,
                    'phone_number': c.phone_number,
                    'created_at': c.client_created_at.isoformat(),
                }
                for c in clients
            ],
            'caisse_operations': [
                {
                    'local_id': o.local_id,
                    'operator_name': o.operator_name,
                    'type': o.type,
                    'montant': str(o.montant),
                    'note': o.note,
                    'created_at': o.operation_created_at.isoformat(),
                }
                for o in caisse_operations
            ],
        })


class PushSyncView(APIView):
    """
    POST /api/sync/push/
    Body: { agence_id, device_id, transactions: [...], clients: [...], caisse_operations: [...] }
    Push continu et automatique (fréquence confirmée) depuis le mobile —
    upsert idempotent par (agence, local_id) pour supporter les retries
    réseau sans dupliquer. N'existe que pour les comptes Agence : le mobile
    ne déclenche jamais ça pour un compte Particulier.
    """
    def post(self, request):
        agence_id = request.data.get('agence_id')
        device_id = request.data.get('device_id', '').strip()
        if not agence_id or not device_id:
            return Response({'erreur': 'agence_id et device_id requis'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            agence = Agence.objects.get(id=agence_id)
        except Agence.DoesNotExist:
            return Response({'erreur': 'Agence introuvable'}, status=status.HTTP_404_NOT_FOUND)

        autorise = Licence.objects.filter(agence=agence, device_id=device_id).exists()
        if not autorise:
            return Response(
                {'erreur': 'Ce device n\'a pas de licence pour cette agence'},
                status=status.HTTP_403_FORBIDDEN
            )

        counts = {'transactions': 0, 'clients': 0, 'caisse_operations': 0}

        for t in request.data.get('transactions', []):
            SyncedTransaction.objects.update_or_create(
                agence=agence, local_id=t['local_id'],
                defaults={
                    'operator_name': t.get('operator_name', ''),
                    'transaction_type_code': t.get('transaction_type_code', ''),
                    'transaction_type_label': t.get('transaction_type_label', ''),
                    'direction': t.get('direction', ''),
                    'amount': t.get('amount', 0),
                    'commission': t.get('commission', 0),
                    'client_phone': t.get('client_phone', ''),
                    'client_name': t.get('client_name', ''),
                    'status': t.get('status', ''),
                    'source': t.get('source', ''),
                    'transaction_created_at': _parse_dt(t.get('created_at')),
                },
            )
            counts['transactions'] += 1

        for c in request.data.get('clients', []):
            SyncedClient.objects.update_or_create(
                agence=agence, local_id=c['local_id'],
                defaults={
                    'first_name': c.get('first_name', ''),
                    'last_name': c.get('last_name', ''),
                    'phone_number': c.get('phone_number', ''),
                    'client_created_at': _parse_dt(c.get('created_at')),
                },
            )
            counts['clients'] += 1

        for o in request.data.get('caisse_operations', []):
            SyncedCaisseOperation.objects.update_or_create(
                agence=agence, local_id=o['local_id'],
                defaults={
                    'operator_name': o.get('operator_name', ''),
                    'type': o.get('type', ''),
                    'montant': o.get('montant', 0),
                    'note': o.get('note', ''),
                    'operation_created_at': _parse_dt(o.get('created_at')),
                },
            )
            counts['caisse_operations'] += 1

        return Response({'message': 'Synchronisé', 'counts': counts})


def _parse_dt(value):
    if not value:
        return datetime.now()
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return datetime.now()
