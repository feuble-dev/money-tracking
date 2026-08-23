from rest_framework import serializers
from .models import Country, Operator, TransactionType, OperatorTransactionType, SmsPattern


# --- Public (catalogue consommé par le mobile) ---------------------------

class CountrySerializer(serializers.ModelSerializer):
    class Meta:
        model = Country
        fields = ['id', 'code', 'name', 'dial_code', 'catalog_version']


class SmsPatternPublicSerializer(serializers.ModelSerializer):
    direction = serializers.SerializerMethodField()

    class Meta:
        model = SmsPattern
        fields = ['id', 'raw_example', 'tagged_zones', 'direction_override', 'direction', 'cible_compte']

    def get_direction(self, obj):
        # Direction effective (D1) : override du pattern sinon défaut du type
        return obj.direction_override or obj.operator_transaction_type.transaction_type.default_direction


class OperatorTransactionTypePublicSerializer(serializers.ModelSerializer):
    code = serializers.CharField(source='transaction_type.code', read_only=True)
    label = serializers.CharField(source='transaction_type.label', read_only=True)
    default_direction = serializers.CharField(source='transaction_type.default_direction', read_only=True)
    sms_patterns = SmsPatternPublicSerializer(many=True, read_only=True)

    class Meta:
        model = OperatorTransactionType
        fields = ['id', 'code', 'label', 'default_direction', 'ussd_code', 'commission_taux', 'sms_patterns']


class OperatorPublicSerializer(serializers.ModelSerializer):
    transaction_types = OperatorTransactionTypePublicSerializer(source='operator_types', many=True, read_only=True)

    class Meta:
        model = Operator
        fields = ['id', 'name', 'logo', 'sms_sender', 'transaction_types']


# --- Admin (CRUD) ----------------------------------------------------------

class AdminCountrySerializer(serializers.ModelSerializer):
    class Meta:
        model = Country
        fields = ['id', 'code', 'name', 'dial_code', 'is_active', 'catalog_version', 'created_at']
        read_only_fields = ['catalog_version']


class AdminOperatorSerializer(serializers.ModelSerializer):
    country_name = serializers.CharField(source='country.name', read_only=True)

    class Meta:
        model = Operator
        fields = ['id', 'country', 'country_name', 'name', 'logo', 'sms_sender', 'is_active', 'created_at']


class AdminTransactionTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = TransactionType
        fields = ['id', 'code', 'label', 'default_direction', 'is_active', 'created_at']


class AdminOperatorTransactionTypeSerializer(serializers.ModelSerializer):
    operator_name = serializers.CharField(source='operator.name', read_only=True)
    transaction_type_label = serializers.CharField(source='transaction_type.label', read_only=True)
    transaction_type_code = serializers.CharField(source='transaction_type.code', read_only=True)
    transaction_type_direction = serializers.CharField(source='transaction_type.default_direction', read_only=True)

    class Meta:
        model = OperatorTransactionType
        fields = [
            'id', 'operator', 'operator_name', 'transaction_type',
            'transaction_type_label', 'transaction_type_code', 'transaction_type_direction',
            'ussd_code', 'commission_taux', 'is_active', 'created_at',
        ]


class AdminSmsPatternSerializer(serializers.ModelSerializer):
    class Meta:
        model = SmsPattern
        fields = [
            'id', 'operator_transaction_type', 'raw_example',
            'tagged_zones', 'direction_override', 'cible_compte', 'is_active', 'created_at',
        ]
