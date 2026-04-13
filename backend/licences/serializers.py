from rest_framework import serializers
from .models import Client, Licence, DemandeActivation, Notification


class ClientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Client
        fields = '__all__'


class LicenceSerializer(serializers.ModelSerializer):
    telephone_client = serializers.CharField(
        source='client.telephone', read_only=True
    )

    class Meta:
        model = Licence
        fields = [
            'id', 'code', 'telephone_client', 'device_id',
            'date_debut', 'date_fin', 'duree_mois',
            'montant_paye', 'statut', 'created_at',
        ]


class DemandeActivationSerializer(serializers.ModelSerializer):
    class Meta:
        model = DemandeActivation
        fields = '__all__'


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'titre', 'message', 'cible', 'telephones', 'created_at']
