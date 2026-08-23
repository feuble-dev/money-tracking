from django.urls import path
from . import views

urlpatterns = [
    path('countries/', views.CountriesListView.as_view()),
    path('countries/<str:code>/operators/', views.CountryOperatorsView.as_view()),
]
