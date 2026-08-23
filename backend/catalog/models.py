from django.db import models


class Country(models.Model):
    code = models.CharField(
        max_length=2, unique=True,
        help_text="Code ISO 3166-1 alpha-2, ex: BF"
    )
    name = models.CharField(max_length=100)
    dial_code = models.CharField(max_length=5, help_text="Ex: +226")
    is_active = models.BooleanField(default=True)
    catalog_version = models.PositiveIntegerField(
        default=1,
        help_text="Incrémenté à chaque changement d'un opérateur/type/pattern de ce pays — sert au resync mobile (ETag)."
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        # Normalisé en majuscule pour que la recherche par code dans
        # CountryOperatorsView (insensible à la saisie admin) soit fiable.
        self.code = self.code.upper()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.code})"

    class Meta:
        verbose_name = "Pays"
        verbose_name_plural = "Pays"
        ordering = ['name']


class Operator(models.Model):
    country = models.ForeignKey(
        Country, on_delete=models.RESTRICT, related_name='operators'
    )
    name = models.CharField(max_length=100)
    logo = models.ImageField(
        upload_to='operators/logos/', null=True, blank=True
    )
    sms_sender = models.CharField(
        max_length=50, blank=True,
        help_text="Expéditeur SMS tel qu'il apparaît sur l'appareil, ex: OrangeMoney"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.name} — {self.country.code}"

    class Meta:
        verbose_name = "Opérateur"
        verbose_name_plural = "Opérateurs"
        ordering = ['country', 'name']


class TransactionType(models.Model):
    """
    Catalogue GLOBAL de types de transaction (Dépôt, Retrait, Transfert,
    Paiement marchand, Envoi d'unités...), réutilisable par tous les
    opérateurs — voir OperatorTransactionType pour les attributs propres
    à une paire (opérateur, type).
    """
    DIRECTION_CHOICES = [
        ('in', 'Entrant'),
        ('out', 'Sortant'),
    ]

    code = models.SlugField(
        max_length=50, unique=True,
        help_text="Identifiant stable, ex: deposit, transfert, paiement_marchand"
    )
    label = models.CharField(max_length=100)
    default_direction = models.CharField(
        max_length=3, choices=DIRECTION_CHOICES,
        help_text="Sens par défaut — peut être surchargé par un SmsPattern spécifique"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.label

    class Meta:
        verbose_name = "Type de transaction"
        verbose_name_plural = "Types de transaction"
        ordering = ['label']


class OperatorTransactionType(models.Model):
    """
    Table de liaison : attributs propres à la paire (opérateur, type) —
    l'USSD et la commission diffèrent d'un opérateur à l'autre même pour
    un type conceptuellement identique.
    """
    operator = models.ForeignKey(
        Operator, on_delete=models.RESTRICT, related_name='operator_types'
    )
    transaction_type = models.ForeignKey(
        TransactionType, on_delete=models.RESTRICT, related_name='operator_links'
    )
    ussd_code = models.CharField(max_length=100, blank=True)
    commission_taux = models.DecimalField(
        max_digits=6, decimal_places=3, default=0,
        help_text="Taux de commission en %, un seul taux par type (D9 — sens non pris en compte pour l'instant)"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.operator.name} — {self.transaction_type.label}"

    class Meta:
        verbose_name = "Type activé par opérateur"
        verbose_name_plural = "Types activés par opérateur"
        unique_together = [('operator', 'transaction_type')]
        ordering = ['operator', 'transaction_type']


class SmsPattern(models.Model):
    """
    Modèle de SMS pour une paire (opérateur, type) : le texte d'exemple
    et les zones taguées (même schéma que TaggedZone côté mobile). Le
    backend ne compile jamais de regex (D2) — c'est le mobile qui le fait
    à la synchronisation, via SmsPatternBuilder.buildRegex().
    """
    CIBLE_COMPTE_CHOICES = [
        ('tous', 'Tous'),
        ('particulier', 'Particulier'),
        ('agence', 'Agence'),
    ]

    operator_transaction_type = models.ForeignKey(
        OperatorTransactionType, on_delete=models.RESTRICT, related_name='sms_patterns'
    )
    raw_example = models.TextField(help_text="Exemple de SMS réel (anonymisé si besoin)")
    tagged_zones = models.JSONField(
        help_text="Liste de {start, end, fieldName} — mêmes noms de champs que TaggedZone côté mobile"
    )
    direction_override = models.CharField(
        max_length=3, choices=TransactionType.DIRECTION_CHOICES,
        null=True, blank=True,
        help_text="Si renseigné, prime sur le sens par défaut du type (D1) — ex: 'Transfert reçu' vs 'Transfert envoyé'"
    )
    cible_compte = models.CharField(
        max_length=12, choices=CIBLE_COMPTE_CHOICES, default='tous',
        help_text="Le SMS d'un compte Particulier diffère souvent de celui d'un compte Agence pour la même transaction — ce champ cible le pattern en conséquence."
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Pattern — {self.operator_transaction_type}"

    class Meta:
        verbose_name = "Pattern SMS"
        verbose_name_plural = "Patterns SMS"
        ordering = ['-created_at']
