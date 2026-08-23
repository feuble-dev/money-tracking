from django.urls import path
from . import views

urlpatterns = [
    path('demander-affiliation/', views.DemanderAffiliationView.as_view()),
    path('affiliation-statut/', views.AffiliationStatutView.as_view()),
    path('demandes-en-attente/', views.DemandesEnAttenteView.as_view()),
    path('affiliation/<int:pk>/approuver/', views.ApprouverAffiliationView.as_view()),
    path('affiliation/<int:pk>/rejeter/', views.RejeterAffiliationView.as_view()),
    path('mes-agences/', views.MesAgencesView.as_view()),
    path('agence-detail/<int:pk>/', views.AgenceSyncDetailView.as_view()),
    path('push/', views.PushSyncView.as_view()),
]
