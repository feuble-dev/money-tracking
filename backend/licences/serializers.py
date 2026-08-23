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

    class Meta:
        model = Licence
        fields = [
            'id', 'code', 'agence', 'agence_nom', 'telephone_client', 'device_id',
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
