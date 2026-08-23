from django.urls import path
from . import admin_views

urlpatterns = [
    path('countries/', admin_views.AdminCountriesView.as_view()),
    path('countries/<int:pk>/', admin_views.AdminCountryDetailView.as_view()),
    path('operators/', admin_views.AdminOperatorsView.as_view()),
    path('operators/<int:pk>/', admin_views.AdminOperatorDetailView.as_view()),
    path('transaction-types/', admin_views.AdminTransactionTypesView.as_view()),
    path('transaction-types/<int:pk>/', admin_views.AdminTransactionTypeDetailView.as_view()),
    path('operator-types/', admin_views.AdminOperatorTransactionTypesView.as_view()),
    path('operator-types/<int:pk>/', admin_views.AdminOperatorTransactionTypeDetailView.as_view()),
    path('sms-patterns/', admin_views.AdminSmsPatternsView.as_view()),
    path('sms-patterns/<int:pk>/', admin_views.AdminSmsPatternDetailView.as_view()),
]
