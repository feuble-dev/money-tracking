from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Prefetch
from django.utils.http import quote_etag

from .models import Country, Operator, OperatorTransactionType, SmsPattern
from .serializers import CountrySerializer, OperatorPublicSerializer


class CountriesListView(APIView):
    """GET /api/catalog/countries/ — pays actifs disponibles pour l'onboarding mobile."""

    def get(self, request):
        countries = Country.objects.filter(is_active=True)
        serializer = CountrySerializer(countries, many=True)
        return Response(serializer.data)


class CountryOperatorsView(APIView):
    """
    GET /api/catalog/countries/<code>/operators/?account_type=particulier|agence
    Catalogue complet (opérateurs -> types -> patterns) pour un pays, en un
    seul appel (le mobile est souvent en réseau faible). ETag basé sur
    Country.catalog_version pour permettre un resync incrémental (D6) via
    If-None-Match.

    account_type filtre les patterns SMS par cible_compte (un SMS Particulier
    diffère souvent de son équivalent Agence pour la même transaction) — les
    patterns cible_compte='tous' sont toujours inclus. Omis, le catalogue
    complet est renvoyé sans filtre (comportement historique conservé).
    """

    def get(self, request, code):
        try:
            country = Country.objects.get(code=code.upper(), is_active=True)
        except Country.DoesNotExist:
            return Response(
                {'erreur': 'Pays introuvable'},
                status=status.HTTP_404_NOT_FOUND
            )

        account_type = request.query_params.get('account_type', '').strip()
        if account_type not in ('particulier', 'agence'):
            account_type = None

        # L'ETag doit varier avec le filtre : deux account_type différents
        # partagent la même catalog_version mais pas le même contenu — sans
        # ça un 304 pourrait renvoyer le mauvais résultat mis en cache.
        etag = quote_etag(f"{country.catalog_version}:{account_type or 'all'}")
        if request.META.get('HTTP_IF_NONE_MATCH') == etag:
            return Response(status=status.HTTP_304_NOT_MODIFIED)

        patterns_queryset = SmsPattern.objects.filter(is_active=True)
        if account_type:
            patterns_queryset = patterns_queryset.filter(
                cible_compte__in=['tous', account_type]
            )

        operators = Operator.objects.filter(
            country=country, is_active=True
        ).prefetch_related(
            Prefetch(
                'operator_types',
                queryset=(
                    OperatorTransactionType.objects
                    .filter(is_active=True, transaction_type__is_active=True)
                    .select_related('transaction_type')
                    .prefetch_related(
                        Prefetch('sms_patterns', queryset=patterns_queryset)
                    )
                )
            )
        )
        serializer = OperatorPublicSerializer(operators, many=True, context={'request': request})
        response = Response({
            'catalog_version': country.catalog_version,
            'operators': serializer.data,
        })
        response['ETag'] = etag
        return response
