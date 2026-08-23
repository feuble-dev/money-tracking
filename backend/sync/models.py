from django.db import models
from licences.models import Client, Agence


class AffiliationRequest(models.Model):
    """
    Un agent (nouveau device, éventuellement nouveau numéro) demande à
    opérer une agence appartenant à un "patron" — identifié par son numéro
    de téléphone (mécanisme de rattachement confirmé : saisie du numéro,
    pas de code d'invitation). Le patron approuve et assigne l'agence
    concernée ; seulement alors le demandeur peut l'opérer. Concerne
    uniquement les comptes Agence (pas les Particuliers).
    """
    STATUT_CHOICES = [
        ('en_attente', 'En attente'),
        ('approuve', 'Approuvé'),
        ('rejete', 'Rejeté'),
    ]

    demandeur_telephone = models.CharField(max_length=20)
    demandeur_device_id = models.CharField(max_length=200)
    patron = models.ForeignKey(
        Client, on_delete=models.RESTRICT,
        related_name='demandes_affiliation_recues',
        help_text="Compte propriétaire des agences (identifié par son numéro)"
    )
    agence = models.ForeignKey(
        Agence, null=True, blank=True,
        on_delete=models.RESTRICT,
        related_name='affiliations',
        help_text="Assignée par le patron au moment de l'approbation"
    )
    statut = models.CharField(
        max_length=20, choices=STATUT_CHOICES, default='en_attente'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.demandeur_telephone} -> {self.patron.telephone} ({self.statut})"

    class Meta:
        verbose_name = "Demande d'affiliation"
        verbose_name_plural = "Demandes d'affiliation"
        ordering = ['-created_at']


class SyncedTransaction(models.Model):
    """
    Copie serveur (lecture seule pour le patron) des transactions d'une
    agence, poussées en continu par le mobile qui l'opère. Dénormalisée
    (operator_name, pas de FK catalogue) — le patron veut le détail complet
    d'un coup d'œil, pas un graphe à parcourir (visibilité confirmée:
    "détail complet", droits: "lecture seule").
    """
    agence = models.ForeignKey(
        Agence, on_delete=models.RESTRICT,
        related_name='synced_transactions'
    )
    local_id = models.CharField(max_length=64, help_text="id local (mobile) de la transaction")
    operator_name = models.CharField(max_length=100, blank=True)
    transaction_type_code = models.CharField(max_length=50, blank=True)
    transaction_type_label = models.CharField(max_length=100, blank=True)
    direction = models.CharField(max_length=3, blank=True)
    amount = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    commission = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    client_phone = models.CharField(max_length=20, blank=True)
    client_name = models.CharField(max_length=150, blank=True)
    status = models.CharField(max_length=20, blank=True)
    source = models.CharField(max_length=20, blank=True)
    transaction_created_at = models.DateTimeField(help_text="created_at côté mobile")
    synced_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Transaction synchronisée"
        verbose_name_plural = "Transactions synchronisées"
        unique_together = [('agence', 'local_id')]
        ordering = ['-transaction_created_at']


class SyncedClient(models.Model):
    agence = models.ForeignKey(
        Agence, on_delete=models.RESTRICT,
        related_name='synced_clients'
    )
    local_id = models.CharField(max_length=64)
    first_name = models.CharField(max_length=100, blank=True)
    last_name = models.CharField(max_length=100, blank=True)
    phone_number = models.CharField(max_length=20, blank=True)
    client_created_at = models.DateTimeField(help_text="created_at côté mobile")
    synced_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Client synchronisé"
        verbose_name_plural = "Clients synchronisés"
        unique_together = [('agence', 'local_id')]
        ordering = ['-client_created_at']


class SyncedCaisseOperation(models.Model):
    agence = models.ForeignKey(
        Agence, on_delete=models.RESTRICT,
        related_name='synced_caisse_operations'
    )
    local_id = models.CharField(max_length=64)
    operator_name = models.CharField(max_length=100, blank=True)
    type = models.CharField(max_length=30, blank=True)
    montant = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    note = models.TextField(blank=True)
    operation_created_at = models.DateTimeField(help_text="created_at côté mobile")
    synced_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Opération caisse synchronisée"
        verbose_name_plural = "Opérations caisse synchronisées"
        unique_together = [('agence', 'local_id')]
        ordering = ['-operation_created_at']
