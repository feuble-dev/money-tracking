from django.db.models import RestrictedError
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAdminUser

from .models import Country, Operator, TransactionType, OperatorTransactionType, SmsPattern
from .serializers import (
    AdminCountrySerializer, AdminOperatorSerializer, AdminTransactionTypeSerializer,
    AdminOperatorTransactionTypeSerializer, AdminSmsPatternSerializer,
)


def safe_delete(instance):
    """
    Toutes les FK du catalogue sont en RESTRICT (jamais de suppression en
    cascade silencieuse) — ce helper transforme le RestrictedError levé par
    Django en réponse HTTP claire plutôt qu'un 500.
    """
    try:
        instance.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    except RestrictedError:
        return Response(
            {'erreur': "Impossible de supprimer : des éléments en dépendent encore. Supprimez-les d'abord."},
            status=status.HTTP_409_CONFLICT,
        )


class AdminCountriesView(APIView):
    """GET/POST /api/admin/catalog/countries/"""
    permission_classes = [IsAdminUser]

    def get(self, request):
        countries = Country.objects.all()
        return Response(AdminCountrySerializer(countries, many=True).data)

    def post(self, request):
        serializer = AdminCountrySerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminCountryDetailView(APIView):
    """PATCH/DELETE /api/admin/catalog/countries/<id>/"""
    permission_classes = [IsAdminUser]

    def patch(self, request, pk):
        try:
            country = Country.objects.get(id=pk)
        except Country.DoesNotExist:
            return Response({'erreur': 'Pays introuvable'}, status=status.HTTP_404_NOT_FOUND)
        serializer = AdminCountrySerializer(country, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            country = Country.objects.get(id=pk)
        except Country.DoesNotExist:
            return Response({'erreur': 'Pays introuvable'}, status=status.HTTP_404_NOT_FOUND)
        return safe_delete(country)


class AdminOperatorsView(APIView):
    """GET/POST /api/admin/catalog/operators/?country_id=... — POST accepte multipart (logo)."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        operators = Operator.objects.select_related('country').all()
        country_id = request.query_params.get('country_id')
        if country_id:
            operators = operators.filter(country_id=country_id)
        return Response(AdminOperatorSerializer(operators, many=True, context={'request': request}).data)

    def post(self, request):
        serializer = AdminOperatorSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminOperatorDetailView(APIView):
    """GET/PATCH/DELETE /api/admin/catalog/operators/<id>/"""
    permission_classes = [IsAdminUser]

    def get(self, request, pk):
        try:
            operator = Operator.objects.select_related('country').get(id=pk)
        except Operator.DoesNotExist:
            return Response({'erreur': 'Opérateur introuvable'}, status=status.HTTP_404_NOT_FOUND)
        data = AdminOperatorSerializer(operator, context={'request': request}).data
        links = OperatorTransactionType.objects.filter(operator=operator).select_related('transaction_type')
        data['transaction_types'] = AdminOperatorTransactionTypeSerializer(links, many=True).data
        return Response(data)

    def patch(self, request, pk):
        try:
            operator = Operator.objects.get(id=pk)
        except Operator.DoesNotExist:
            return Response({'erreur': 'Opérateur introuvable'}, status=status.HTTP_404_NOT_FOUND)
        serializer = AdminOperatorSerializer(operator, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            operator = Operator.objects.get(id=pk)
        except Operator.DoesNotExist:
            return Response({'erreur': 'Opérateur introuvable'}, status=status.HTTP_404_NOT_FOUND)
        return safe_delete(operator)


class AdminTransactionTypesView(APIView):
    """
    GET/POST /api/admin/catalog/transaction-types/
    Catalogue GLOBAL de types (D3) — indépendant des opérateurs.
    """
    permission_classes = [IsAdminUser]

    def get(self, request):
        types = TransactionType.objects.all()
        return Response(AdminTransactionTypeSerializer(types, many=True).data)

    def post(self, request):
        serializer = AdminTransactionTypeSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminTransactionTypeDetailView(APIView):
    """PATCH/DELETE /api/admin/catalog/transaction-types/<id>/"""
    permission_classes = [IsAdminUser]

    def patch(self, request, pk):
        try:
            t = TransactionType.objects.get(id=pk)
        except TransactionType.DoesNotExist:
            return Response({'erreur': 'Type introuvable'}, status=status.HTTP_404_NOT_FOUND)
        serializer = AdminTransactionTypeSerializer(t, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            t = TransactionType.objects.get(id=pk)
        except TransactionType.DoesNotExist:
            return Response({'erreur': 'Type introuvable'}, status=status.HTTP_404_NOT_FOUND)
        return safe_delete(t)


class AdminOperatorTransactionTypesView(APIView):
    """
    GET/POST /api/admin/catalog/operator-types/?operator_id=...
    Attache un TransactionType existant à un Operator (D3) avec son
    USSD/commission propres à cette paire.
    """
    permission_classes = [IsAdminUser]

    def get(self, request):
        links = OperatorTransactionType.objects.select_related('operator', 'transaction_type').all()
        operator_id = request.query_params.get('operator_id')
        if operator_id:
            links = links.filter(operator_id=operator_id)
        return Response(AdminOperatorTransactionTypeSerializer(links, many=True).data)

    def post(self, request):
        serializer = AdminOperatorTransactionTypeSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminOperatorTransactionTypeDetailView(APIView):
    """PATCH/DELETE /api/admin/catalog/operator-types/<id>/"""
    permission_classes = [IsAdminUser]

    def patch(self, request, pk):
        try:
            link = OperatorTransactionType.objects.get(id=pk)
        except OperatorTransactionType.DoesNotExist:
            return Response({'erreur': 'Association introuvable'}, status=status.HTTP_404_NOT_FOUND)
        serializer = AdminOperatorTransactionTypeSerializer(link, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            link = OperatorTransactionType.objects.get(id=pk)
        except OperatorTransactionType.DoesNotExist:
            return Response({'erreur': 'Association introuvable'}, status=status.HTTP_404_NOT_FOUND)
        return safe_delete(link)


class AdminSmsPatternsView(APIView):
    """GET/POST /api/admin/catalog/sms-patterns/?operator_transaction_type_id=..."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        patterns = SmsPattern.objects.select_related(
            'operator_transaction_type__operator', 'operator_transaction_type__transaction_type'
        ).all()
        link_id = request.query_params.get('operator_transaction_type_id')
        if link_id:
            patterns = patterns.filter(operator_transaction_type_id=link_id)
        return Response(AdminSmsPatternSerializer(patterns, many=True).data)

    def post(self, request):
        serializer = AdminSmsPatternSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminSmsPatternDetailView(APIView):
    """PATCH/DELETE /api/admin/catalog/sms-patterns/<id>/"""
    permission_classes = [IsAdminUser]

    def patch(self, request, pk):
        try:
            pattern = SmsPattern.objects.get(id=pk)
        except SmsPattern.DoesNotExist:
            return Response({'erreur': 'Pattern introuvable'}, status=status.HTTP_404_NOT_FOUND)
        serializer = AdminSmsPatternSerializer(pattern, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            pattern = SmsPattern.objects.get(id=pk)
        except SmsPattern.DoesNotExist:
            return Response({'erreur': 'Pattern introuvable'}, status=status.HTTP_404_NOT_FOUND)
        return safe_delete(pattern)
