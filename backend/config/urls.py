from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/licence/', include('licences.urls')),
    path('api/admin/', include('licences.admin_urls')),
]
