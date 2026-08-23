from django.db.models import F
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver

from .models import Country, Operator, OperatorTransactionType, SmsPattern


def _bump(country_id):
    if country_id is None:
        return
    Country.objects.filter(id=country_id).update(
        catalog_version=F('catalog_version') + 1
    )


@receiver([post_save, post_delete], sender=Operator)
def bump_on_operator_change(sender, instance, **kwargs):
    _bump(instance.country_id)


@receiver([post_save, post_delete], sender=OperatorTransactionType)
def bump_on_link_change(sender, instance, **kwargs):
    # En cascade (suppression de l'opérateur parent), la ligne opérateur peut
    # déjà avoir disparu de la DB au moment du signal — le bump n'est qu'une
    # optimisation de cache, pas critique, donc on l'ignore plutôt que de
    # faire échouer la suppression.
    try:
        _bump(instance.operator.country_id)
    except Operator.DoesNotExist:
        pass


@receiver([post_save, post_delete], sender=SmsPattern)
def bump_on_pattern_change(sender, instance, **kwargs):
    try:
        _bump(instance.operator_transaction_type.operator.country_id)
    except (OperatorTransactionType.DoesNotExist, Operator.DoesNotExist):
        pass
