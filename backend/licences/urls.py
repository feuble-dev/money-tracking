from django.urls import path
from . import views

urlpatterns = [
    path('essai/', views.EssaiGratuitView.as_view()),
    path('agences/', views.AgencesListView.as_view()),
    path('agences/creer/', views.AgenceCreerView.as_view()),
    path('login/', views.LoginView.as_view()),
    path('demander/', views.DemanderActivationView.as_view()),
    path('recuperer/', views.RecupererLicenceView.as_view()),
    path('verifier-cle/', views.VerifierCleView.as_view()),
    path('notifications/', views.NotificationsView.as_view()),
    path('historique/demander/', views.DemanderHistoriqueView.as_view()),
    path('historique/recuperer/', views.RecupererTokenHistoriqueView.as_view()),
    path('historique/verifier/', views.VerifierTokenHistoriqueView.as_view()),
]
