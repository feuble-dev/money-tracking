from rest_framework import serializers
from .models import Client, Agence, PricingTier, Licence, DemandeActivation, Notification


class ClientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Client
        fields = '__all__'


class AgenceSerializer(serializers.ModelSerializer):
    telephone_client = serializers.CharField(
        source='client.telephone', read_only=True
    )

    class Meta:
        model = Agence
        fields = ['id', 'nom', 'telephone_client', 'is_active', 'created_at']


class PricingTierSerializer(serializers.ModelSerializer):
    montant = serializers.SerializerMethodField()

    class Meta:
        model = PricingTier
        fields = [
            'id', 'duree_mois', 'remise_pct', 'is_essai',
            'essai_duree_mois', 'is_active', 'montant',
        ]

    def get_montant(self, obj):
        return obj.montant()


class LicenceSerializer(serializers.ModelSerializer):
    telephone_client = serializers.CharField(
        source='agence.client.telephone', read_only=True
    )
    agence_nom = serializers.CharField(
        source='agence.nom', read_only=True
    )
    account_type = serializers.CharField(
        source='agence.client.account_type', read_only=True
    )
    # Clé hors ligne signée (Ed25519) à transmettre à l'agent — voir
    # licences/signature.py.
    cle_hors_ligne = serializers.SerializerMethodField()

    def get_cle_hors_ligne(self, obj):
        from .signature import cle_pour_licence
        return cle_pour_licence(obj)

    class Meta:
        model = Licence
        fields = [
            'id', 'code', 'cle_hors_ligne', 'agence', 'agence_nom',
            'telephone_client', 'account_type', 'device_id',
            'date_debut', 'date_fin', 'duree_mois',
            'montant_paye', 'statut', 'created_at',
        ]


class DemandeActivationSerializer(serializers.ModelSerializer):
    agence_nom = serializers.CharField(
        source='agence.nom', read_only=True, default=None
    )

    class Meta:
        model = DemandeActivation
        fields = '__all__'


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'titre', 'message', 'cible', 'telephones', 'created_at']
