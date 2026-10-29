from datetime import date

from django.db import migrations


def particuliers_gratuits(apps, schema_editor):
    """Les comptes Particulier deviennent gratuits : leurs licences (essai
    ou payées) passent en licence permanente."""
    Licence = apps.get_model('licences', 'Licence')
    Licence.objects.filter(agence__client__account_type='particulier').update(
        statut='active', date_fin=date(2099, 12, 31),
    )


class Migration(migrations.Migration):
    dependencies = [('licences', '0007_appareil_autorise')]
    operations = [migrations.RunPython(particuliers_gratuits, migrations.RunPython.noop)]
