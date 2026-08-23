from django.urls import path
from . import admin_views

urlpatterns = [
    path('login/', admin_views.AdminLoginView.as_view()),
    path('stats/', admin_views.AdminStatsView.as_view()),
    path('licences/', admin_views.AdminLicencesListView.as_view()),
    path('licences/generer/', admin_views.AdminGenererLicenceView.as_view()),
    path('demandes/', admin_views.AdminDemandesListView.as_view()),
    path('demandes/<int:demande_id>/valider/', admin_views.AdminValiderDemandeView.as_view()),
    path('demandes/<int:demande_id>/rejeter/', admin_views.AdminRejeterDemandeView.as_view()),
    path('clients/', admin_views.AdminClientsListView.as_view()),
    path('agences/', admin_views.AdminAgencesListView.as_view()),
    path('pricing-tiers/', admin_views.AdminPricingTiersView.as_view()),
    path('pricing-tiers/<int:tier_id>/', admin_views.AdminPricingTierDetailView.as_view()),
    path('notifications/', admin_views.AdminNotificationsListView.as_view()),
    path('notifications/envoyer/', admin_views.AdminEnvoyerNotificationView.as_view()),
    path('achats-historique/', admin_views.AdminAchatsHistoriqueListView.as_view()),
    path('achats-historique/<int:achat_id>/valider/', admin_views.AdminValiderAchatHistoriqueView.as_view()),
]
