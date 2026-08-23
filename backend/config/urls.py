from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/licence/', include('licences.urls')),
    path('api/admin/', include('licences.admin_urls')),
    path('api/catalog/', include('catalog.urls')),
    path('api/admin/catalog/', include('catalog.admin_urls')),
    path('api/sync/', include('sync.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
