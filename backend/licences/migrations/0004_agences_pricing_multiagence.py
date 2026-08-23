# Pivot vers la facturation par agence : chaque Licence se rattache
# désormais à une Agence (unité facturable) plutôt qu'à un Client directement.
from datetime import date, timedelta
from django.db import migrations, models
import django.db.models.deletion


def backfill_agences(apps, schema_editor):
    Client = apps.get_model('licences', 'Client')
    Agence = apps.get_model('licences', 'Agence')
    Licence = apps.get_model('licences', 'Licence')
    DemandeActivation = apps.get_model('licences', 'DemandeActivation')
    PricingTier = apps.get_model('licences', 'PricingTier')

    # Une agence par défaut par client ayant déjà des licences, on y rattache
    # toutes ses licences existantes — zéro perte de données pour la prod actuelle.
    for client in Client.objects.filter(licences__isnull=False).distinct():
        agence_defaut = Agence.objects.create(
            client=client, nom='Agence principale'
        )
        Licence.objects.filter(client=client, agence__isnull=True).update(
            agence=agence_defaut
        )
        # Best-effort : les demandes en attente de ce client rejoignent la même agence
        DemandeActivation.objects.filter(
            telephone=client.telephone, agence__isnull=True
        ).update(agence=agence_defaut)

    # Grille tarifaire de base : 450 FCFA/mois/agence, essai 3 mois (D4/D10)
    PricingTier.objects.get_or_create(
        duree_mois=1, defaults={'remise_pct': 0, 'is_essai': False}
    )
    PricingTier.objects.get_or_create(
        duree_mois=12, defaults={'remise_pct': 17}
    )
    PricingTier.objects.get_or_create(
        duree_mois=24, defaults={'remise_pct': 25}
    )
    PricingTier.objects.get_or_create(
        duree_mois=3, defaults={'remise_pct': 0, 'is_essai': True, 'essai_duree_mois': 3}
    )


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('licences', '0003_achathistorique'),
    ]

    operations = [
        migrations.AddField(
            model_name='client',
            name='account_type',
            field=models.CharField(
                choices=[('particulier', 'Particulier'), ('agence', 'Agence')],
                default='agence',
                help_text='Particulier: suivi personnel multi-opérateur. Agence: usage professionnel avec commissions.',
                max_length=20,
            ),
        ),
        migrations.CreateModel(
            name='Agence',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('nom', models.CharField(max_length=100)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('client', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='agences', to='licences.client')),
            ],
            options={
                'verbose_name': 'Agence',
                'verbose_name_plural': 'Agences',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='PricingTier',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('duree_mois', models.PositiveIntegerField(help_text='Durée du palier en mois (1, 12, 24...)', unique=True)),
                ('remise_pct', models.DecimalField(decimal_places=2, default=0, help_text='Remise en % appliquée au tarif de base mensuel', max_digits=5)),
                ('is_essai', models.BooleanField(default=False, help_text="Coché uniquement pour le palier d'essai gratuit")),
                ('essai_duree_mois', models.PositiveIntegerField(default=0, help_text='Utilisé seulement si is_essai=True (ex: 3 mois)')),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Palier tarifaire',
                'verbose_name_plural': 'Paliers tarifaires',
                'ordering': ['duree_mois'],
            },
        ),
        migrations.AddField(
            model_name='licence',
            name='agence',
            field=models.ForeignKey(null=True, blank=True, on_delete=django.db.models.deletion.CASCADE, related_name='licences', to='licences.agence'),
        ),
        migrations.AddField(
            model_name='demandeactivation',
            name='agence',
            field=models.ForeignKey(
                blank=True, null=True,
                help_text="Agence pour laquelle l'activation est demandée",
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='demandes', to='licences.agence',
            ),
        ),
        migrations.AddField(
            model_name='achathistorique',
            name='date_debut_demandee',
            field=models.DateField(blank=True, null=True, help_text="Date la plus ancienne à importer — détermine le coût"),
        ),
        migrations.AlterField(
            model_name='achathistorique',
            name='montant_paye',
            field=models.IntegerField(default=0),
        ),
        migrations.RunPython(backfill_agences, noop_reverse),
        migrations.AlterField(
            model_name='licence',
            name='agence',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='licences', to='licences.agence'),
        ),
        migrations.RemoveField(
            model_name='licence',
            name='client',
        ),
    ]
