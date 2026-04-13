from django.contrib import admin
from django.utils.html import format_html
from datetime import date
from .models import Client, Licence, DemandeActivation, Notification, AchatHistorique
from .services import LicenceService, HistoriqueService


@admin.register(DemandeActivation)
class DemandeActivationAdmin(admin.ModelAdmin):
    list_display = [
        'telephone', 'device_id_court', 'duree_mois',
        'statut_badge', 'created_at', 'actions_rapides'
    ]
    list_filter = ['statut', 'duree_mois']
    search_fields = ['telephone']
    ordering = ['-created_at']
    actions = ['valider_demandes']

    def device_id_court(self, obj):
        return obj.device_id[:12] + '...'
    device_id_court.short_description = 'Device ID'

    def statut_badge(self, obj):
        colors = {
            'en_attente': '#FF9800',
            'validee': '#4CAF50',
            'rejetee': '#F44336',
        }
        color = colors.get(obj.statut, 'gray')
        return format_html(
            '<span style="background:{}; color:white; '
            'padding:3px 8px; border-radius:4px;">{}</span>',
            color, obj.get_statut_display()
        )
    statut_badge.short_description = 'Statut'

    def actions_rapides(self, obj):
        if obj.statut == 'en_attente':
            return format_html(
                '<a href="/admin/licences/demandeactivation/'
                '{}/valider/" style="background:#4CAF50; '
                'color:white; padding:4px 10px; '
                'border-radius:4px; text-decoration:none;">'
                'Valider</a>',
                obj.id
            )
        return '—'
    actions_rapides.short_description = 'Action'

    def valider_demandes(self, request, queryset):
        count = 0
        for demande in queryset.filter(statut='en_attente'):
            self._valider(demande)
            count += 1
        self.message_user(request, f'{count} licence(s) générée(s)')
    valider_demandes.short_description = 'Valider les demandes sélectionnées'

    def _valider(self, demande):
        client, _ = Client.objects.get_or_create(
            telephone=demande.telephone
        )

        licence_actuelle = Licence.objects.filter(
            client=client,
            device_id=demande.device_id,
            statut='active'
        ).order_by('-date_fin').first()

        date_fin = LicenceService.calculer_date_fin(
            demande.duree_mois,
            licence_actuelle.date_fin if licence_actuelle else None
        )

        code = LicenceService.generer_code(
            demande.device_id,
            demande.telephone,
            date_fin
        )

        licence = Licence.objects.create(
            client=client,
            code=code,
            device_id=demande.device_id,
            date_debut=date.today(),
            date_fin=date_fin,
            duree_mois=demande.duree_mois,
            montant_paye=LicenceService.montant_pour_duree(
                demande.duree_mois
            ),
            statut='active',
        )

        demande.statut = 'validee'
        demande.licence = licence
        demande.save()


@admin.register(Licence)
class LicenceAdmin(admin.ModelAdmin):
    list_display = [
        'code', 'telephone_client', 'statut',
        'date_fin', 'jours_restants', 'duree_mois'
    ]
    list_filter = ['statut', 'duree_mois']
    search_fields = ['client__telephone', 'code']

    def telephone_client(self, obj):
        return obj.client.telephone
    telephone_client.short_description = 'Téléphone'

    def jours_restants(self, obj):
        jours = (obj.date_fin - date.today()).days
        color = '#4CAF50' if jours > 7 else '#FF9800' if jours > 0 else '#F44336'
        return format_html(
            '<span style="color:{}; font-weight:bold;">{} jours</span>',
            color, max(jours, 0)
        )
    jours_restants.short_description = 'Jours restants'


@admin.register(Client)
class ClientAdmin(admin.ModelAdmin):
    list_display = ['telephone', 'nom', 'prenom', 'created_at']
    search_fields = ['telephone', 'nom']


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['titre', 'cible', 'created_at']
    list_filter = ['cible']
    search_fields = ['titre', 'message']


@admin.register(AchatHistorique)
class AchatHistoriqueAdmin(admin.ModelAdmin):
    list_display = [
        'telephone_client', 'device_id_court',
        'statut_badge', 'montant_paye', 'created_at',
        'action_valider'
    ]
    list_filter = ['statut']
    ordering = ['-created_at']
    actions = ['valider_achats']

    def telephone_client(self, obj):
        return obj.client.telephone
    telephone_client.short_description = 'Téléphone'

    def device_id_court(self, obj):
        return obj.device_id[:12] + '...'
    device_id_court.short_description = 'Device'

    def statut_badge(self, obj):
        colors = {
            'en_attente': '#FF9800',
            'active': '#4CAF50',
            'rejete': '#F44336',
        }
        return format_html(
            '<span style="background:{}; color:white; '
            'padding:3px 8px; border-radius:4px;">{}</span>',
            colors.get(obj.statut, 'gray'),
            obj.get_statut_display()
        )
    statut_badge.short_description = 'Statut'

    def action_valider(self, obj):
        if obj.statut == 'en_attente':
            return format_html(
                '<a href="/admin/licences/achathistorique/'
                '{}/valider/" style="background:#4CAF50;'
                'color:white; padding:4px 10px;'
                'border-radius:4px; text-decoration:none;">'
                'Valider</a>', obj.id
            )
        if obj.token:
            return format_html(
                '<code style="font-size:11px">{}</code>', obj.token
            )
        return '—'
    action_valider.short_description = 'Action / Token'

    def get_urls(self):
        from django.urls import path as url_path
        urls = super().get_urls()
        custom = [
            url_path('<int:pk>/valider/',
                     self.admin_site.admin_view(self._valider_achat),
                     name='valider_achat_historique'),
        ]
        return custom + urls

    def _valider_achat(self, request, pk):
        from django.shortcuts import redirect
        from django.utils import timezone
        achat = AchatHistorique.objects.get(pk=pk)
        if achat.statut == 'en_attente':
            achat.token = HistoriqueService.generer_token(
                achat.device_id, achat.client.telephone
            )
            achat.statut = 'active'
            achat.activated_at = timezone.now()
            achat.save()
        return redirect('/admin/licences/achathistorique/')

    def valider_achats(self, request, queryset):
        from django.utils import timezone
        count = 0
        for achat in queryset.filter(statut='en_attente'):
            achat.token = HistoriqueService.generer_token(
                achat.device_id, achat.client.telephone
            )
            achat.statut = 'active'
            achat.activated_at = timezone.now()
            achat.save()
            count += 1
        self.message_user(request, f'{count} achat(s) validé(s)')
    valider_achats.short_description = 'Valider les achats sélectionnés'
