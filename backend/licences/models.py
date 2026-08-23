from django.db import models


class Client(models.Model):
    ACCOUNT_TYPE_CHOICES = [
        ('particulier', 'Particulier'),
        ('agence', 'Agence'),
    ]

    telephone = models.CharField(
        max_length=20, unique=True,
        help_text="Numéro BF ex: 70123456"
    )
    nom = models.CharField(max_length=100, blank=True)
    prenom = models.CharField(max_length=100, blank=True)
    account_type = models.CharField(
        max_length=20,
        choices=ACCOUNT_TYPE_CHOICES,
        default='agence',
        help_text="Particulier: suivi personnel multi-opérateur. Agence: usage professionnel avec commissions."
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.telephone} — {self.nom} {self.prenom}"

    class Meta:
        verbose_name = "Client"
        verbose_name_plural = "Clients"


class Agence(models.Model):
    """
    Unité facturable : un compte (Client) peut avoir plusieurs agences,
    chacune avec son propre cycle de vie de licence (essai/active/expirée).
    """
    client = models.ForeignKey(
        Client, on_delete=models.CASCADE,
        related_name='agences'
    )
    nom = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nom} — {self.client.telephone}"

    class Meta:
        verbose_name = "Agence"
        verbose_name_plural = "Agences"
        ordering = ['-created_at']


class PricingTier(models.Model):
    """
    Grille tarifaire éditable depuis l'admin (remplace l'ancien dict TARIFS codé en dur).
    Base : 450 FCFA/mois/agence. Un palier essai (is_essai=True) définit la durée d'essai gratuit.
    """
    duree_mois = models.PositiveIntegerField(
        unique=True,
        help_text="Durée du palier en mois (1, 12, 24...)"
    )
    remise_pct = models.DecimalField(
        max_digits=5, decimal_places=2, default=0,
        help_text="Remise en % appliquée au tarif de base mensuel"
    )
    is_essai = models.BooleanField(
        default=False,
        help_text="Coché uniquement pour le palier d'essai gratuit"
    )
    essai_duree_mois = models.PositiveIntegerField(
        default=0,
        help_text="Utilisé seulement si is_essai=True (ex: 3 mois)"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    BASE_MENSUEL = 450

    def montant(self) -> int:
        brut = self.BASE_MENSUEL * self.duree_mois
        return round(float(brut) * (1 - float(self.remise_pct) / 100))

    def __str__(self):
        if self.is_essai:
            return f"Essai — {self.essai_duree_mois} mois gratuits"
        return f"{self.duree_mois} mois — {self.montant()} FCFA (-{self.remise_pct}%)"

    class Meta:
        verbose_name = "Palier tarifaire"
        verbose_name_plural = "Paliers tarifaires"
        ordering = ['duree_mois']


class Licence(models.Model):
    STATUT_CHOICES = [
        ('essai', 'Essai gratuit'),
        ('active', 'Active'),
        ('expiree', 'Expirée'),
        ('suspendue', 'Suspendue'),
    ]

    agence = models.ForeignKey(
        Agence, on_delete=models.CASCADE,
        related_name='licences'
    )
    code = models.CharField(
        max_length=100, unique=True,
        help_text="Ex: MT-A3F9-KL82MN7P20260330"
    )
    device_id = models.CharField(
        max_length=200,
        help_text="Identifiant unique de l'appareil"
    )
    date_debut = models.DateField()
    date_fin = models.DateField()
    duree_mois = models.IntegerField(
        help_text="1, 12, ou 24 mois"
    )
    montant_paye = models.IntegerField(
        default=0,
        help_text="Montant en FCFA"
    )
    statut = models.CharField(
        max_length=20,
        choices=STATUT_CHOICES,
        default='active'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.code} — {self.agence.nom} ({self.agence.client.telephone})"

    class Meta:
        verbose_name = "Licence"
        verbose_name_plural = "Licences"
        ordering = ['-created_at']


class DemandeActivation(models.Model):
    STATUT_CHOICES = [
        ('en_attente', 'En attente'),
        ('validee', 'Validée'),
        ('rejetee', 'Rejetée'),
    ]

    telephone = models.CharField(max_length=20)
    device_id = models.CharField(max_length=200)
    agence = models.ForeignKey(
        Agence, null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='demandes',
        help_text="Agence pour laquelle l'activation est demandée"
    )
    duree_mois = models.IntegerField(default=1)
    statut = models.CharField(
        max_length=20,
        choices=STATUT_CHOICES,
        default='en_attente'
    )
    licence = models.ForeignKey(
        Licence, null=True, blank=True,
        on_delete=models.SET_NULL
    )
    note = models.TextField(
        blank=True,
        help_text="Note admin (référence paiement, etc.)"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.telephone} — {self.statut}"

    class Meta:
        verbose_name = "Demande d'activation"
        verbose_name_plural = "Demandes d'activation"
        ordering = ['-created_at']


class Notification(models.Model):
    CIBLE_CHOICES = [
        ('all', 'Tous les utilisateurs'),
        ('individual', 'Un utilisateur'),
        ('group', 'Un groupe'),
    ]

    titre = models.CharField(max_length=200)
    message = models.TextField()
    cible = models.CharField(
        max_length=20, choices=CIBLE_CHOICES, default='all'
    )
    # Pour cible 'individual': un seul téléphone
    # Pour cible 'group': liste de téléphones séparés par virgule
    telephones = models.TextField(
        blank=True,
        help_text="Téléphone(s) cible. Vide = tout le monde."
    )
    lu_par = models.TextField(
        blank=True, default='',
        help_text="Téléphones ayant lu la notif (séparés par virgule)"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.titre} ({self.get_cible_display()})"

    def est_pour(self, telephone: str) -> bool:
        if self.cible == 'all':
            return True
        tels = [t.strip() for t in self.telephones.split(',') if t.strip()]
        return telephone in tels

    class Meta:
        verbose_name = "Notification"
        verbose_name_plural = "Notifications"
        ordering = ['-created_at']


class AchatHistorique(models.Model):
    """
    Achat de l'import des anciens SMS. Gratuit jusqu'à 1 an en arrière,
    puis 200 FCFA par année supplémentaire (voir HistoriqueService.calculer_cout).
    """
    client = models.ForeignKey(
        Client, on_delete=models.CASCADE,
        related_name='achats_historique'
    )
    device_id = models.CharField(max_length=200)
    date_debut_demandee = models.DateField(
        null=True, blank=True,
        help_text="Date la plus ancienne à importer — détermine le coût"
    )
    statut = models.CharField(
        max_length=20,
        choices=[
            ('en_attente', 'En attente'),
            ('active', 'Activé'),
            ('rejete', 'Rejeté'),
        ],
        default='en_attente'
    )
    token = models.CharField(
        max_length=100, unique=True, blank=True, null=True
    )
    montant_paye = models.IntegerField(default=0)
    note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    activated_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.client.telephone} — {self.statut}"

    class Meta:
        verbose_name = "Achat Historique SMS"
        verbose_name_plural = "Achats Historique SMS"
        ordering = ['-created_at']
