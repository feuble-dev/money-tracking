# 🔐 MoneyTracking — Backend Système de Licence

## Contexte
Créer un backend Django complet pour gérer les licences
de l'application Flutter MoneyTracking. Le backend doit
être créé dans un dossier `backend/` à la racine du projet
Flutter existant.

## Structure à créer
````
moneytracking/          ← racine projet Flutter existant
├── lib/                ← Flutter (existant, ne pas toucher)
├── android/            ← existant
├── backend/            ← ⭐ CRÉER ICI
│   ├── manage.py
│   ├── requirements.txt
│   ├── .env.example
│   ├── config/
│   │   ├── settings.py
│   │   ├── urls.py
│   │   └── wsgi.py
│   └── licences/
│       ├── models.py
│       ├── views.py
│       ├── serializers.py
│       ├── urls.py
│       ├── admin.py
│       └── services.py
└── pubspec.yaml        ← existant
````

---

## PARTIE 1 — Configuration Django

### requirements.txt
````
django==4.2
djangorestframework==3.14
django-cors-headers==4.3
python-dotenv==1.0
gunicorn==21.2
whitenoise==6.6
````

### settings.py
````python
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'change-moi')
DEBUG = os.getenv('DEBUG', 'False') == 'True'
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', '*').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'licences',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

CORS_ALLOW_ALL_ORIGINS = True
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Clé secrète pour signer les licences
# DOIT être la même dans Flutter (AppConfig.licenceSecret)
LICENCE_SECRET = os.getenv('LICENCE_SECRET', 'moneytracking-secret-key-2024')
````

### .env.example
````
DJANGO_SECRET_KEY=change-moi-en-production
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,ton-domaine.com
LICENCE_SECRET=moneytracking-secret-key-change-moi
````

---

## PARTIE 2 — Modèles

### models.py
````python
from django.db import models
import uuid

class Client(models.Model):
    telephone = models.CharField(
        max_length=20, unique=True,
        help_text="Numéro BF ex: 70123456"
    )
    nom = models.CharField(max_length=100, blank=True)
    prenom = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.telephone} — {self.nom} {self.prenom}"

    class Meta:
        verbose_name = "Client"
        verbose_name_plural = "Clients"


class Licence(models.Model):
    STATUT_CHOICES = [
        ('essai', 'Essai gratuit'),
        ('active', 'Active'),
        ('expiree', 'Expirée'),
        ('suspendue', 'Suspendue'),
    ]

    client = models.ForeignKey(
        Client, on_delete=models.CASCADE,
        related_name='licences'
    )
    code = models.CharField(
        max_length=100, unique=True,
        help_text="Ex: MT-A3F9-KL82MN7P20260330"
    )
    device_id = models.CharField(
        max_length=200,
        help_text="Identifiant unique de l'appareil"
    )
    date_debut = models.DateField()
    date_fin = models.DateField()
    duree_mois = models.IntegerField(
        help_text="1, 12, ou 24 mois"
    )
    montant_paye = models.IntegerField(
        default=0,
        help_text="Montant en FCFA"
    )
    statut = models.CharField(
        max_length=20,
        choices=STATUT_CHOICES,
        default='active'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.code} — {self.client.telephone}"

    class Meta:
        verbose_name = "Licence"
        verbose_name_plural = "Licences"
        ordering = ['-created_at']


class DemandeActivation(models.Model):
    STATUT_CHOICES = [
        ('en_attente', 'En attente'),
        ('validee', 'Validée'),
        ('rejetee', 'Rejetée'),
    ]

    telephone = models.CharField(max_length=20)
    device_id = models.CharField(max_length=200)
    duree_mois = models.IntegerField(default=1)
    statut = models.CharField(
        max_length=20,
        choices=STATUT_CHOICES,
        default='en_attente'
    )
    licence = models.ForeignKey(
        Licence, null=True, blank=True,
        on_delete=models.SET_NULL
    )
    note = models.TextField(
        blank=True,
        help_text="Note admin (référence paiement, etc.)"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.telephone} — {self.statut}"

    class Meta:
        verbose_name = "Demande d'activation"
        verbose_name_plural = "Demandes d'activation"
        ordering = ['-created_at']
````

---

## PARTIE 3 — Service de génération de licence

### services.py
````python
import hmac
import hashlib
import json
import base64
import re
from datetime import date, timedelta
from django.conf import settings


class LicenceService:

    # Tarifs en FCFA
    TARIFS = {
        1: 1000,
        12: 10000,
        24: 18000,
    }

    @staticmethod
    def _get_secret() -> str:
        return settings.LICENCE_SECRET

    @staticmethod
    def _signer(payload: str) -> str:
        """Génère signature HMAC-SHA256 (8 premiers chars)"""
        return hmac.new(
            LicenceService._get_secret().encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()[:8].upper()

    @staticmethod
    def generer_code(
        device_id: str,
        telephone: str,
        date_fin: date
    ) -> str:
        """
        Génère une clé de licence au format :
        MT-{SIGNATURE}-{PAYLOAD_B32}{DATE}

        Exemple : MT-A3F9BC12-KL82MN7P20260330

        La clé contient :
        - Signature HMAC (vérifie authenticité)
        - Device ID raccourci (8 chars)
        - 4 derniers chiffres du téléphone
        - Date d'expiration (YYYYMMDD)
        """
        # Données encodées dans la clé
        data = {
            "d": device_id[:8],
            "t": telephone[-4:],
            "f": date_fin.strftime("%Y%m%d"),
        }
        payload = json.dumps(data, sort_keys=True,
                           separators=(',', ':'))

        # Signature
        signature = LicenceService._signer(payload)

        # Encoder device+tel en base32 (8 chars)
        device_part = base64.b32encode(
            f"{device_id[:4]}{telephone[-4:]}".encode()
        ).decode().rstrip('=')[:8]

        # Date en clair à la fin
        date_str = date_fin.strftime("%Y%m%d")

        # Format final : MT-SIGNATURE-DEVICEPART+DATE
        return f"MT-{signature}-{device_part}{date_str}"

    @staticmethod
    def verifier_code(code: str, device_id: str) -> dict:
        """
        Vérifie une clé de licence localement.
        Retourne { valide, date_fin, message }
        """
        try:
            # Format : MT-XXXXXXXX-XXXXXXXX20260330
            pattern = r'^MT-([A-Z0-9]{8})-([A-Z0-9]{8})(\d{8})$'
            match = re.match(pattern, code.strip().upper())

            if not match:
                return {
                    'valide': False,
                    'message': 'Format de clé invalide'
                }

            signature_recue = match.group(1)
            device_part = match.group(2)
            date_str = match.group(3)

            # Extraire la date
            date_fin = date(
                int(date_str[:4]),
                int(date_str[4:6]),
                int(date_str[6:8])
            )

            # Vérifier expiration
            if date.today() > date_fin:
                return {
                    'valide': False,
                    'date_fin': str(date_fin),
                    'message': f'Licence expirée le {date_fin}'
                }

            # Vérifier device_id partiel
            device_encode = base64.b32encode(
                f"{device_id[:4]}{device_id[-4:]}".encode()
            ).decode().rstrip('=')[:8]

            # Reconstruire et vérifier signature
            data = {
                "d": device_id[:8],
                "f": date_fin.strftime("%Y%m%d"),
            }
            payload = json.dumps(data, sort_keys=True,
                               separators=(',', ':'))
            signature_attendue = LicenceService._signer(payload)

            jours_restants = (date_fin - date.today()).days

            return {
                'valide': True,
                'date_fin': str(date_fin),
                'jours_restants': jours_restants,
                'message': f'Licence valide — '
                           f'expire dans {jours_restants} jours'
            }

        except Exception as e:
            return {
                'valide': False,
                'message': f'Clé invalide : {str(e)}'
            }

    @staticmethod
    def calculer_date_fin(
        duree_mois: int,
        date_fin_actuelle: date = None
    ) -> date:
        """
        Calcule la nouvelle date de fin.
        Si licence existante non expirée → prolonge à partir
        de la date actuelle de fin (pas de jours perdus).
        """
        base = max(
            date_fin_actuelle or date.today(),
            date.today()
        )
        return base + timedelta(days=30 * duree_mois)

    @staticmethod
    def montant_pour_duree(duree_mois: int) -> int:
        return LicenceService.TARIFS.get(duree_mois, 1000)
````

---

## PARTIE 4 — API Views

### views.py
````python
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from datetime import date, timedelta
from .models import Client, Licence, DemandeActivation
from .services import LicenceService


class DemanderActivationView(APIView):
    """
    L'agent envoie une demande d'activation.
    POST /api/licence/demander/
    Body: { telephone, device_id, duree_mois }
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()
        duree_mois = int(request.data.get('duree_mois', 1))

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Créer client si inexistant
        client, _ = Client.objects.get_or_create(
            telephone=telephone
        )

        # Vérifier si demande déjà en attente
        demande_existante = DemandeActivation.objects.filter(
            telephone=telephone,
            device_id=device_id,
            statut='en_attente'
        ).first()

        if demande_existante:
            return Response({
                'message': 'Demande déjà en attente',
                'demande_id': demande_existante.id,
                'statut': 'en_attente',
            })

        # Créer la demande
        demande = DemandeActivation.objects.create(
            telephone=telephone,
            device_id=device_id,
            duree_mois=duree_mois,
        )

        montant = LicenceService.montant_pour_duree(duree_mois)

        return Response({
            'message': 'Demande envoyée avec succès',
            'demande_id': demande.id,
            'montant_a_payer': montant,
            'instructions': (
                f'Envoyez {montant} FCFA via Orange Money '
                f'et attendez la validation.'
            ),
        }, status=status.HTTP_201_CREATED)


class RecupererLicenceView(APIView):
    """
    L'agent vérifie si sa licence est prête (polling).
    POST /api/licence/recuperer/
    Body: { telephone, device_id }
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Chercher licence active pour ce device
        licence = Licence.objects.filter(
            client__telephone=telephone,
            device_id=device_id,
            statut='active',
            date_fin__gte=date.today()
        ).order_by('-date_fin').first()

        if not licence:
            # Vérifier si demande en attente
            demande = DemandeActivation.objects.filter(
                telephone=telephone,
                device_id=device_id,
                statut='en_attente'
            ).first()

            if demande:
                return Response({
                    'statut': 'en_attente',
                    'message': (
                        'Votre demande est en cours de validation. '
                        'Vous serez notifié dès que c\'est prêt.'
                    ),
                })

            return Response({
                'statut': 'aucune_licence',
                'message': (
                    'Aucune licence trouvée. '
                    'Contactez MoneyTracking pour souscrire.'
                ),
            }, status=status.HTTP_404_NOT_FOUND)

        jours_restants = (licence.date_fin - date.today()).days

        return Response({
            'statut': 'active',
            'code': licence.code,
            'date_debut': str(licence.date_debut),
            'date_fin': str(licence.date_fin),
            'jours_restants': jours_restants,
            'duree_mois': licence.duree_mois,
            'message': (
                f'Licence active — '
                f'expire dans {jours_restants} jours'
            ),
        })


class VerifierCleView(APIView):
    """
    Vérifie une clé entrée manuellement (mode offline).
    POST /api/licence/verifier-cle/
    Body: { code, device_id }
    """
    def post(self, request):
        code = request.data.get('code', '').strip()
        device_id = request.data.get('device_id', '').strip()

        if not code or not device_id:
            return Response(
                {'erreur': 'code et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        resultat = LicenceService.verifier_code(code, device_id)
        return Response(resultat)


class EssaiGratuitView(APIView):
    """
    Démarre le mois d'essai gratuit.
    POST /api/licence/essai/
    Body: { telephone, device_id }
    """
    def post(self, request):
        telephone = request.data.get('telephone', '').strip()
        device_id = request.data.get('device_id', '').strip()

        if not telephone or not device_id:
            return Response(
                {'erreur': 'telephone et device_id requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Vérifier si essai déjà utilisé sur ce device
        essai_existant = Licence.objects.filter(
            device_id=device_id,
            statut='essai'
        ).first()

        if essai_existant:
            return Response({
                'erreur': 'Essai gratuit déjà utilisé sur cet appareil'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Créer client
        client, _ = Client.objects.get_or_create(
            telephone=telephone
        )

        # Créer licence essai (30 jours)
        date_fin = date.today() + timedelta(days=30)
        code = LicenceService.generer_code(
            device_id, telephone, date_fin
        )

        licence = Licence.objects.create(
            client=client,
            code=code,
            device_id=device_id,
            date_debut=date.today(),
            date_fin=date_fin,
            duree_mois=1,
            montant_paye=0,
            statut='essai',
        )

        return Response({
            'statut': 'essai',
            'code': licence.code,
            'date_fin': str(date_fin),
            'jours_restants': 30,
            'message': 'Essai gratuit activé pour 30 jours',
        }, status=status.HTTP_201_CREATED)
````

---

## PARTIE 5 — URLs

### licences/urls.py
````python
from django.urls import path
from . import views

urlpatterns = [
    path('essai/', views.EssaiGratuitView.as_view()),
    path('demander/', views.DemanderActivationView.as_view()),
    path('recuperer/', views.RecupererLicenceView.as_view()),
    path('verifier-cle/', views.VerifierCleView.as_view()),
]
````

### config/urls.py
````python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/licence/', include('licences.urls')),
]
````

---

## PARTIE 6 — Dashboard Admin

### admin.py
````python
from django.contrib import admin
from django.utils.html import format_html
from datetime import date
from .models import Client, Licence, DemandeActivation
from .services import LicenceService


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
        color = colors.get(obj.statut, '#gray')
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
                '✅ Valider</a>',
                obj.id
            )
        return '—'
    actions_rapides.short_description = 'Action'

    def valider_demandes(self, request, queryset):
        """Action bulk pour valider plusieurs demandes"""
        for demande in queryset.filter(statut='en_attente'):
            self._valider(demande)
        self.message_user(request, f'{queryset.count()} licence(s) générée(s)')
    valider_demandes.short_description = '✅ Valider les demandes sélectionnées'

    def _valider(self, demande):
        from .models import Client
        client, _ = Client.objects.get_or_create(
            telephone=demande.telephone
        )

        # Licence existante ?
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
````

---

## PARTIE 7 — Script de démarrage

### Créer `backend/start.sh`
````bash
#!/bin/bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput

# Créer superuser admin si pas existant
echo "from django.contrib.auth import get_user_model; \
U = get_user_model(); \
U.objects.filter(username='admin').exists() or \
U.objects.create_superuser('admin', 'admin@moneytracking.com', 'admin123')" \
| python manage.py shell

gunicorn config.wsgi:application --bind 0.0.0.0:8000
````

### Créer `backend/README.md`
````markdown
# MoneyTracking Backend — Système de Licence

## Démarrage rapide
```bash
cp .env.example .env
# Éditer .env avec tes valeurs
bash start.sh
```

## URLs API
- POST /api/licence/essai/          → Démarrer essai gratuit
- POST /api/licence/demander/       → Demander activation
- POST /api/licence/recuperer/      → Récupérer licence (polling)
- POST /api/licence/verifier-cle/   → Vérifier clé manuelle

## Dashboard Admin
- URL : http://ton-domaine.com/admin/
- Login : admin / admin123 (changer en prod !)

## Tarifs configurés
- 1 mois  : 1 000 FCFA
- 12 mois : 10 000 FCFA
- 24 mois : 18 000 FCFA
````

---

## PARTIE 8 — Intégration Flutter

### Ajouter dans `pubspec.yaml`
````yaml
dependencies:
  device_info_plus: ^9.0.0
  flutter_secure_storage: ^9.0.0
  http: ^1.1.0
````

### Créer `lib/core/licence/licence_service.dart`
````dart
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class LicenceService {
  static const _baseUrl = 'https://ton-domaine.com/api/licence';
  static const _storage = FlutterSecureStorage();
  static const _licenceKey = 'moneytracking_licence';

  // ── Obtenir device_id unique ──────────────────────────────
  static Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.id; // ID unique Android
  }

  // ── Démarrer essai gratuit ────────────────────────────────
  static Future<Map<String, dynamic>> demarrerEssai(
      String telephone) async {
    final deviceId = await getDeviceId();
    final response = await http.post(
      Uri.parse('$_baseUrl/essai/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'telephone': telephone,
        'device_id': deviceId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await _sauvegarderLocalement(data);
    }
    return data;
  }

  // ── Envoyer demande d'activation ──────────────────────────
  static Future<Map<String, dynamic>> demanderActivation({
    required String telephone,
    required int dureeMois,
  }) async {
    final deviceId = await getDeviceId();
    final response = await http.post(
      Uri.parse('$_baseUrl/demander/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'telephone': telephone,
        'device_id': deviceId,
        'duree_mois': dureeMois,
      }),
    );
    return jsonDecode(response.body);
  }

  // ── Polling : récupérer la licence ────────────────────────
  static Future<bool> recupererLicence(String telephone) async {
    final deviceId = await getDeviceId();
    final response = await http.post(
      Uri.parse('$_baseUrl/recuperer/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'telephone': telephone,
        'device_id': deviceId,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['statut'] == 'active') {
        await _sauvegarderLocalement(data);
        return true;
      }
    }
    return false;
  }

  // ── Activer avec clé manuelle ─────────────────────────────
  static Future<Map<String, dynamic>> activerAvecCle(
      String code) async {
    final deviceId = await getDeviceId();

    // Vérifier format clé : MT-XXXXXXXX-XXXXXXXX20260330
    final pattern = RegExp(
      r'^MT-[A-Z0-9]{8}-[A-Z0-9]{8}(\d{8})$'
    );
    if (!pattern.hasMatch(code.trim().toUpperCase())) {
      return {'valide': false, 'message': 'Format de clé invalide'};
    }

    // Extraire date de la clé
    final match = pattern.firstMatch(code.trim().toUpperCase())!;
    final dateStr = match.group(1)!;
    final dateFin = DateTime(
      int.parse(dateStr.substring(0, 4)),
      int.parse(dateStr.substring(4, 6)),
      int.parse(dateStr.substring(6, 8)),
    );

    // Vérifier expiration localement
    if (DateTime.now().isAfter(dateFin)) {
      return {
        'valide': false,
        'message': 'Clé expirée depuis le ${dateFin.toString().substring(0, 10)}'
      };
    }

    final jours = dateFin.difference(DateTime.now()).inDays;

    // Sauvegarder
    await _sauvegarderLocalement({
      'statut': 'active',
      'code': code.trim().toUpperCase(),
      'date_fin': dateFin.toIso8601String(),
      'jours_restants': jours,
    });

    return {
      'valide': true,
      'date_fin': dateFin.toString().substring(0, 10),
      'jours_restants': jours,
      'message': 'Licence activée — expire dans $jours jours',
    };
  }

  // ── Vérifier licence locale ───────────────────────────────
  static Future<LicenceStatut> verifierLocalement() async {
    final data = await _getLicenceLocale();
    if (data == null) return LicenceStatut.nonActivee;

    final dateFin = DateTime.parse(data['date_fin']);
    final jours = dateFin.difference(DateTime.now()).inDays;

    if (DateTime.now().isAfter(dateFin)) {
      return LicenceStatut.expiree;
    }
    if (jours <= 7) {
      return LicenceStatut.expireBientot(jours);
    }
    return LicenceStatut.active;
  }

  // ── Stockage local chiffré ────────────────────────────────
  static Future<void> _sauvegarderLocalement(
      Map<String, dynamic> data) async {
    await _storage.write(
      key: _licenceKey,
      value: jsonEncode(data),
    );
  }

  static Future<Map<String, dynamic>?> _getLicenceLocale() async {
    final raw = await _storage.read(key: _licenceKey);
    if (raw == null) return null;
    return jsonDecode(raw);
  }
}

enum LicenceStatut {
  nonActivee,
  active,
  expiree;

  static LicenceStatut expireBientot(int jours) => active;
}
````

---

## Ordre d'implémentation

1. Créer dossier `backend/` à la racine
2. Installer Django et dépendances
3. Créer tous les fichiers dans l'ordre ci-dessus
4. Lancer migrations : `python manage.py migrate`
5. Créer superuser admin
6. Tester les endpoints avec curl ou Postman
7. Intégrer côté Flutter (LicenceService)
8. Créer l'écran d'activation Flutter

## Test rapide après installation
````bash
# Tester essai gratuit
curl -X POST http://localhost:8000/api/licence/essai/ \
  -H "Content-Type: application/json" \
  -d '{"telephone":"70123456","device_id":"TEST123"}'

# Vérifier une clé
curl -X POST http://localhost:8000/api/licence/verifier-cle/ \
  -H "Content-Type: application/json" \
  -d '{"code":"MT-A3F9BC12-KL82MN7P20260330","device_id":"TEST123"}'
````




moneytracking/
├── lib/                    ← Flutter (existant)
├── backend/                ← Django API (déjà prévu)
└── web/                    ← ⭐ NOUVEAU (Next.js)
    ├── app/
    │   ├── (site)/         ← Site vitrine public
    │   │   ├── page.tsx    ← Landing page
    │   │   ├── features/   ← Fonctionnalités
    │   │   ├── pricing/    ← Tarifs
    │   │   ├── download/   ← Télécharger APK
    │   │   └── docs/       ← Documentation
    │   └── (admin)/        ← Dashboard privé
    │       ├── login/
    │       ├── dashboard/  ← Stats globales
    │       ├── licences/   ← Gérer licences
    │       ├── clients/    ← Gérer clients
    │       └── demandes/   ← Valider demandes
    └── components/




# 🌐 MoneyTracking — Site Vitrine + Dashboard Admin (Next.js 14)

## Contexte
Créer un projet Next.js 14 complet dans un dossier `web/`
à la racine du projet MoneyTracking. Ce projet contient :
1. Un site vitrine public pour l'app MoneyTracking
2. Un dashboard admin privé pour gérer les licences

## Identité visuelle (basée sur le logo)
```
Bleu primaire    : #1565C0
Bleu clair       : #42A5F5
Bleu dégradé     : linear-gradient(135deg, #1565C0, #42A5F5)
Orange accent    : #FF6B35
Blanc            : #FFFFFF
Texte sombre     : #0F1923
Gris doux        : #F5F7FA
```

## Structure du projet
```
web/
├── app/
│   ├── (site)/
│   │   ├── layout.tsx          ← Layout site public
│   │   ├── page.tsx            ← Landing page
│   │   ├── features/page.tsx   ← Fonctionnalités
│   │   ├── pricing/page.tsx    ← Tarifs
│   │   ├── download/page.tsx   ← Télécharger APK
│   │   └── docs/page.tsx       ← Documentation
│   ├── (admin)/
│   │   ├── layout.tsx          ← Layout admin (auth requis)
│   │   ├── login/page.tsx      ← Connexion admin
│   │   ├── dashboard/page.tsx  ← Stats globales
│   │   ├── licences/page.tsx   ← Gérer licences
│   │   ├── clients/page.tsx    ← Gérer clients
│   │   └── demandes/page.tsx   ← Valider demandes
│   ├── api/
│   │   └── auth/[...nextauth]/ ← Auth admin
│   ├── layout.tsx
│   └── globals.css
├── components/
│   ├── site/
│   │   ├── Navbar.tsx
│   │   ├── Hero.tsx
│   │   ├── Features.tsx
│   │   ├── Pricing.tsx
│   │   ├── Download.tsx
│   │   ├── Footer.tsx
│   │   └── PhoneMockup.tsx
│   ├── admin/
│   │   ├── Sidebar.tsx
│   │   ├── StatCard.tsx
│   │   ├── LicenceTable.tsx
│   │   ├── DemandeCard.tsx
│   │   ├── GenerateLicenceModal.tsx
│   │   └── NotificationBell.tsx
│   └── ui/
│       ├── Button.tsx
│       ├── Badge.tsx
│       └── Modal.tsx
├── lib/
│   ├── api.ts              ← Client API Django
│   ├── auth.ts             ← NextAuth config
│   └── websocket.ts        ← WebSocket client
├── public/
│   ├── logo.png            ← Logo MoneyTracking
│   ├── icon.png            ← Icône app
│   └── apk/                ← Fichiers APK
├── package.json
└── tailwind.config.ts
```

---

## PARTIE 1 — Configuration

### package.json dependencies
```json
{
  "dependencies": {
    "next": "14.0.0",
    "react": "18.0.0",
    "react-dom": "18.0.0",
    "typescript": "5.0.0",
    "tailwindcss": "3.0.0",
    "next-auth": "4.24.0",
    "axios": "1.6.0",
    "recharts": "2.10.0",
    "framer-motion": "10.0.0",
    "lucide-react": "0.383.0",
    "date-fns": "3.0.0",
    "socket.io-client": "4.6.0",
    "react-hot-toast": "2.4.0",
    "clsx": "2.0.0"
  }
}
```

### tailwind.config.ts
```ts
export default {
  content: ['./app/**/*.tsx', './components/**/*.tsx'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#1565C0',
          light: '#42A5F5',
          dark: '#0D47A1',
        },
        accent: '#FF6B35',
        dark: '#0F1923',
      },
      backgroundImage: {
        'brand-gradient':
          'linear-gradient(135deg, #1565C0 0%, #42A5F5 100%)',
        'hero-gradient':
          'linear-gradient(135deg, #0D47A1 0%, #1565C0 50%, #42A5F5 100%)',
      },
    },
  },
}
```

---

## PARTIE 2 — Site Vitrine Public

### Page 1 — Landing page (`app/(site)/page.tsx`)

Hero section avec :
- Navbar fixe : logo + liens + bouton "Télécharger"
- Fond dégradé bleu hero-gradient
- Titre principal :
  **"Gérez votre agence Mobile Money en toute simplicité"**
- Sous-titre :
  "MoneyTracking détecte automatiquement vos SMS Orange Money,
  Moov Money et Coris Money pour créer vos transactions."
- Deux boutons CTA :
  - "Télécharger gratuitement" (orange, lien /download)
  - "Voir les fonctionnalités" (outline blanc, lien /features)
- Mockup téléphone animé (framer-motion) avec screenshot app
- Section stats rapides :
  - 🏦 3 opérateurs supportés
  - 📱 100% hors ligne
  - 🔒 Données sécurisées
  - ⚡ Détection SMS automatique
- Section "Comment ça marche" (3 étapes illustrées)
- Section témoignages agents BF
- Section tarifs résumé → lien /pricing
- Footer avec liens et contacts WhatsApp

### Page 2 — Fonctionnalités (`app/(site)/features/page.tsx`)

Grille de fonctionnalités avec icônes :
- 📩 Détection SMS automatique
- 💸 Dépôt & Retrait via USSD
- 👥 Gestion clients avec CNIB
- 📊 Dashboard & statistiques
- 💰 Calcul automatique des commissions
- 🏦 Gestion de caisse par opérateur
- 📤 Export PDF & Excel
- 🔐 Sécurité PIN + empreinte
- ☁️ Sauvegarde en ligne (bientôt)

### Page 3 — Tarifs (`app/(site)/pricing/page.tsx`)

Trois cartes de prix :
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   ESSAI      │  │  MENSUEL     │  │   ANNUEL ⭐  │
│              │  │              │  │              │
│  GRATUIT     │  │  1 000 FCFA  │  │ 10 000 FCFA  │
│  30 jours    │  │  / mois      │  │  / an        │
│              │  │              │  │  (-17%)      │
│ ✓ Toutes     │  │ ✓ Toutes     │  │ ✓ Toutes     │
│   fonctions  │  │   fonctions  │  │   fonctions  │
│ ✓ 3 opérat.  │  │ ✓ 3 opérat.  │  │ ✓ 3 opérat.  │
│              │  │              │  │ ✓ 2 mois     │
│              │  │              │  │   offerts    │
│[Essayer grts]│  │[Souscrire]   │  │[Choisir]     │
└──────────────┘  └──────────────┘  └──────────────┘
```

Carte annuel avec bordure orange (mise en avant).
FAQ tarifs en dessous.

### Page 4 — Téléchargement (`app/(site)/download/page.tsx`)

- Titre : "Télécharger MoneyTracking"
- Logo app bien visible
- Bouton principal :
  "📥 Télécharger APK v1.0.0" (orange, gros)
- Instructions d'installation en 3 étapes :
  1. Télécharger le fichier APK
  2. Autoriser les sources inconnues dans Paramètres
  3. Installer et lancer
- Versions disponibles (tableau) :
  | Version | Date | Changements | APK |
  |---------|------|-------------|-----|
  | v1.0.0  | ...  | Version initiale | 📥 |
- Note : "Compatible Android 6.0 et supérieur"
- Section "Disponible bientôt sur Google Play Store"

### Page 5 — Documentation (`app/(site)/docs/page.tsx`)

Sidebar navigation + contenu :
- Démarrage rapide
- Configuration des opérateurs
- Comment configurer les templates SMS
- Gestion des clients
- Comprendre le dashboard
- Système de licence — comment activer
- FAQ

---

## PARTIE 3 — Dashboard Admin

### Authentification (`app/(admin)/login/page.tsx`)
- Formulaire email + mot de passe
- NextAuth avec credentials provider
- Vérifie contre le backend Django
  (`POST /api/admin/login/`)
- Redirect vers `/dashboard` si succès

### Layout admin (`app/(admin)/layout.tsx`)
- Sidebar gauche fixe avec navigation
- Header avec :
  - Titre de la page courante
  - 🔔 Cloche notifications (badge rouge si nouvelles demandes)
  - Avatar admin
- Sidebar items :
  - 📊 Dashboard
  - 🔑 Licences
  - 👥 Clients
  - 📋 Demandes
  - ⚙️ Paramètres

### Page Dashboard (`app/(admin)/dashboard/page.tsx`)

#### Cartes stats en temps réel
```
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ Licences    │ │ Clients     │ │ Demandes    │ │ Revenus     │
│ actives     │ │ total       │ │ en attente  │ │ ce mois     │
│    47       │ │    63       │ │     3 🔴    │ │ 47 000 FCFA │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

#### Graphiques (recharts)
- Courbe revenus mensuels (12 derniers mois)
- Barres nouvelles licences par mois
- Camembert répartition durées (1 mois / 1 an / 2 ans)

#### Tableau licences expirant bientôt
- Liste des licences expirant dans les 7 prochains jours
- Bouton "Notifier le client" pour chacune

### Page Demandes (`app/(admin)/demandes/page.tsx`)

C'est la page la plus importante.

#### Liste des demandes en attente
Chaque demande affichée en carte :
```
┌──────────────────────────────────────────────────┐
│ 📱 70123456          ⏰ Il y a 2 heures          │
│ Durée demandée : 12 mois — 10 000 FCFA           │
│ Device ID : ABC12345...                          │
│                                                  │
│ Référence paiement : [___________________]       │
│ Note : [_____________________________________]   │
│                                                  │
│ [❌ Rejeter]              [✅ Valider et générer] │
└──────────────────────────────────────────────────┘
```

Quand on clique "Valider et générer" :
1. Appel API Django `POST /api/admin/licences/generer/`
2. Licence générée avec date_fin calculée
3. Code licence affiché en popup :
   `MT-A3F9BC12-KL82MN7P20260330`
4. Bouton "Copier la clé" pour l'envoyer par SMS au client

### Page Licences (`app/(admin)/licences/page.tsx`)

- Tableau avec recherche et filtres
- Colonnes : téléphone, code, statut, date fin, jours restants
- Filtre par statut : active / expirée / essai
- Bouton **"+ Générer une licence"** (sans demande préalable)
- Modal de génération :
```
  Téléphone : [___________]
  Device ID : [___________]
  Durée     : [1 mois ▼  ]
  Montant payé : [_______ FCFA]
  [Générer la licence]
```
- Résultat : code affiché + bouton copier

### Page Clients (`app/(admin)/clients/page.tsx`)
- Tableau searchable
- Voir l'historique des licences par client
- Modifier nom/prénom

---

## PARTIE 4 — WebSocket (Notifications temps réel)

### `lib/websocket.ts`
```ts
import { io, Socket } from 'socket.io-client'

let socket: Socket | null = null

export function connectWebSocket(token: string) {
  socket = io(process.env.NEXT_PUBLIC_WS_URL!, {
    auth: { token },
    reconnection: true,
    reconnectionDelay: 3000,
  })

  socket.on('nouvelle_demande', (data) => {
    // Nouvelle demande d'activation reçue
    // → incrémenter badge notification
    // → afficher toast "Nouvelle demande de 70123456"
  })

  socket.on('licence_expiree', (data) => {
    // Licence expirée
    // → afficher alerte dans dashboard
  })

  return socket
}
```

### Ajouter Django Channels au backend
Dans `backend/requirements.txt` ajouter :
```
channels==4.0.0
channels-redis==4.1.0
daphne==4.0.0
```

Créer `backend/licences/consumers.py` :
```python
import json
from channels.generic.websocket import AsyncWebsocketConsumer

class LicenceConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        await self.channel_layer.group_add(
            "admin_notifications", self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            "admin_notifications", self.channel_name
        )

    async def nouvelle_demande(self, event):
        await self.send(text_data=json.dumps({
            'type': 'nouvelle_demande',
            'telephone': event['telephone'],
            'duree_mois': event['duree_mois'],
        }))
```

---

## PARTIE 5 — Client API

### `lib/api.ts`
```ts
import axios from 'axios'

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: { 'Content-Type': 'application/json' },
})

// Intercepteur token admin
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

export const licenceApi = {
  // Récupérer toutes les licences
  getAll: () => api.get('/api/admin/licences/'),

  // Générer une licence
  generer: (data: {
    telephone: string
    device_id: string
    duree_mois: number
    montant_paye: number
  }) => api.post('/api/admin/licences/generer/', data),

  // Valider une demande
  validerDemande: (id: number, note?: string) =>
    api.post(`/api/admin/demandes/${id}/valider/`, { note }),

  // Rejeter une demande
  rejeterDemande: (id: number) =>
    api.post(`/api/admin/demandes/${id}/rejeter/`),

  // Stats dashboard
  getStats: () => api.get('/api/admin/stats/'),
}
```

---

## PARTIE 6 — Variables d'environnement

### `.env.local`
```
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_WS_URL=ws://localhost:8000
NEXTAUTH_SECRET=change-moi
NEXTAUTH_URL=http://localhost:3000
```

---

## PARTIE 7 — Ajouter endpoints admin au backend Django

Dans `backend/licences/views.py` ajouter :
```python
# GET /api/admin/stats/
class AdminStatsView(APIView):
    # Protégé par token admin
    def get(self, request):
        return Response({
            'licences_actives': Licence.objects.filter(
                statut='active',
                date_fin__gte=date.today()
            ).count(),
            'clients_total': Client.objects.count(),
            'demandes_en_attente': DemandeActivation.objects.filter(
                statut='en_attente'
            ).count(),
            'revenus_mois': Licence.objects.filter(
                created_at__month=date.today().month,
                statut='active'
            ).aggregate(total=Sum('montant_paye'))['total'] or 0,
        })

# POST /api/admin/licences/generer/
class AdminGenererLicenceView(APIView):
    def post(self, request):
        # Générer une licence depuis le dashboard admin
        telephone = request.data.get('telephone')
        device_id = request.data.get('device_id')
        duree_mois = int(request.data.get('duree_mois', 1))
        montant = int(request.data.get('montant_paye', 0))

        client, _ = Client.objects.get_or_create(
            telephone=telephone
        )
        licence_actuelle = Licence.objects.filter(
            client=client,
            device_id=device_id,
            statut='active'
        ).order_by('-date_fin').first()

        date_fin = LicenceService.calculer_date_fin(
            duree_mois,
            licence_actuelle.date_fin if licence_actuelle else None
        )
        code = LicenceService.generer_code(
            device_id, telephone, date_fin
        )
        licence = Licence.objects.create(
            client=client,
            code=code,
            device_id=device_id,
            date_debut=date.today(),
            date_fin=date_fin,
            duree_mois=duree_mois,
            montant_paye=montant,
            statut='active',
        )
        return Response({
            'code': licence.code,
            'date_fin': str(licence.date_fin),
            'message': 'Licence générée avec succès',
        })
```

---

## Ordre d'implémentation

1. Créer `web/` avec `npx create-next-app@14`
2. Configurer Tailwind avec les couleurs MoneyTracking
3. Composants UI de base (Button, Badge, Modal)
4. Site vitrine : Navbar + Landing page + Footer
5. Pages Features, Pricing, Download, Docs
6. Layout admin + page Login (NextAuth)
7. Dashboard admin avec stats
8. Page Demandes (la plus critique)
9. Page Licences + modal génération
10. Page Clients
11. WebSocket notifications (Django Channels + Next.js)

## Commande de démarrage
```bash
cd web
npm install
npm run dev
# → http://localhost:3000
```



# 🔐 MoneyTracking — Intégration système de licence dans l'app Flutter

## Contexte
Le backend Django et le site Next.js sont déjà en place.
Maintenant intégrer le système de licence directement
dans l'app Flutter existante.

---

## PARTIE 1 — Packages à ajouter dans pubspec.yaml
```yaml
dependencies:
  device_info_plus: ^9.0.0
  flutter_secure_storage: ^9.0.0
  http: ^1.1.0
  connectivity_plus: ^5.0.0
```

---

## PARTIE 2 — Fichiers à créer
```
lib/
└── core/
    └── licence/
        ├── licence_service.dart      ← Logique principale
        ├── licence_storage.dart      ← Stockage local chiffré
        ├── licence_validator.dart    ← Validation clé offline
        └── screens/
            ├── activation_screen.dart ← Écran activation
            └── licence_status_screen.dart ← Statut licence
```

---

## PARTIE 3 — LicenceService
```dart
// lib/core/licence/licence_service.dart

import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'licence_storage.dart';
import 'licence_validator.dart';

// ⚠️ Changer par l'URL réelle du backend en production
const String _baseUrl = 'https://ton-domaine.com/api/licence';

class LicenceService {

  // ── Device ID unique Android ──────────────────────────────
  static Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.id;
  }

  // ── Vérification au démarrage de l'app ───────────────────
  // Appelé dans main.dart avant d'afficher l'app
  static Future<LicenceStatut> verifierAuDemarrage() async {
    // 1. Vérifier d'abord en local (fonctionne offline)
    final statut = await LicenceStorage.verifierLocalement();

    if (statut == LicenceStatut.active ||
        statut == LicenceStatut.expireBientot) {
      // Licence locale valide → tenter sync en ligne en arrière-plan
      _syncEnArrierePlan();
      return statut;
    }

    // 2. Si pas de licence locale → tenter récupération en ligne
    final connecte = await _estConnecte();
    if (connecte) {
      final telephone = await LicenceStorage.getTelephone();
      if (telephone != null) {
        final recuperee = await recupererLicence(telephone);
        if (recuperee) return LicenceStatut.active;
      }
    }

    return statut;
  }

  // ── Sync silencieuse en arrière-plan ─────────────────────
  static Future<void> _syncEnArrierePlan() async {
    try {
      final connecte = await _estConnecte();
      if (!connecte) return;
      final telephone = await LicenceStorage.getTelephone();
      if (telephone == null) return;
      await recupererLicence(telephone);
    } catch (_) {}
  }

  // ── MODE 1 : Essai gratuit ────────────────────────────────
  static Future<ResultatActivation> demarrerEssai(
      String telephone) async {
    final deviceId = await getDeviceId();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/essai/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'telephone': telephone,
          'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await LicenceStorage.sauvegarder(data);
        await LicenceStorage.saveTelephone(telephone);
        return ResultatActivation.succes(
          'Essai gratuit activé pour 30 jours !'
        );
      }
      return ResultatActivation.erreur(
        data['erreur'] ?? 'Erreur inconnue'
      );
    } catch (e) {
      return ResultatActivation.erreur(
        'Impossible de se connecter au serveur'
      );
    }
  }

  // ── MODE 2 : Récupération en ligne (polling) ──────────────
  static Future<bool> recupererLicence(String telephone) async {
    final deviceId = await getDeviceId();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/recuperer/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'telephone': telephone,
          'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statut'] == 'active') {
          await LicenceStorage.sauvegarder(data);
          await LicenceStorage.saveTelephone(telephone);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ── MODE 2 : Attente validation (polling 30 sec) ──────────
  static Stream<StatutDemande> attendreValidation(
      String telephone) async* {
    yield StatutDemande.enAttente;
    for (int i = 0; i < 2880; i++) {
      await Future.delayed(const Duration(seconds: 30));
      final recuperee = await recupererLicence(telephone);
      if (recuperee) {
        yield StatutDemande.validee;
        return;
      }
      yield StatutDemande.enAttente;
    }
    yield StatutDemande.timeout;
  }

  // ── MODE 3 : Activation avec clé manuelle (offline) ───────
  static Future<ResultatActivation> activerAvecCle(
      String cle, String telephone) async {
    final deviceId = await getDeviceId();
    final resultat = LicenceValidator.valider(
      cle: cle.trim().toUpperCase(),
      deviceId: deviceId,
    );

    if (resultat.valide) {
      await LicenceStorage.sauvegarder({
        'statut': 'active',
        'code': cle.trim().toUpperCase(),
        'date_fin': resultat.dateFin!.toIso8601String(),
        'jours_restants': resultat.joursRestants,
        'source': 'cle_manuelle',
      });
      await LicenceStorage.saveTelephone(telephone);
      return ResultatActivation.succes(
        'Licence activée — expire dans '
        '${resultat.joursRestants} jours'
      );
    }
    return ResultatActivation.erreur(resultat.message);
  }

  // ── Demande d'activation ──────────────────────────────────
  static Future<ResultatActivation> demanderActivation({
    required String telephone,
    required int dureeMois,
  }) async {
    final deviceId = await getDeviceId();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/demander/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'telephone': telephone,
          'device_id': deviceId,
          'duree_mois': dureeMois,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        await LicenceStorage.saveTelephone(telephone);
        return ResultatActivation.succes(data['message']);
      }
      return ResultatActivation.erreur(
        data['erreur'] ?? 'Erreur'
      );
    } catch (e) {
      return ResultatActivation.erreur(
        'Impossible de se connecter'
      );
    }
  }

  static Future<bool> _estConnecte() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}

// ── Modèles ───────────────────────────────────────────────
enum LicenceStatut {
  nonActivee,
  essaiActif,
  active,
  expireBientot,
  expiree,
}

enum StatutDemande { enAttente, validee, timeout }

class ResultatActivation {
  final bool succes;
  final String message;
  ResultatActivation.succes(this.message) : succes = true;
  ResultatActivation.erreur(this.message) : succes = false;
}
```

---

## PARTIE 4 — LicenceValidator (offline)
```dart
// lib/core/licence/licence_validator.dart

class LicenceValidator {

  // Format clé : MT-XXXXXXXX-XXXXXXXX20260330
  static final _pattern = RegExp(
    r'^MT-([A-Z0-9]{8})-([A-Z0-9]{8})(\d{8})$'
  );

  static ValidationResult valider({
    required String cle,
    required String deviceId,
  }) {
    // 1. Vérifier format
    final match = _pattern.firstMatch(cle);
    if (match == null) {
      return ValidationResult.invalide('Format de clé invalide');
    }

    // 2. Extraire date depuis la clé
    final dateStr = match.group(3)!;
    DateTime dateFin;
    try {
      dateFin = DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
      );
    } catch (_) {
      return ValidationResult.invalide('Date invalide dans la clé');
    }

    // 3. Vérifier expiration
    if (DateTime.now().isAfter(dateFin)) {
      final expDepuis = DateTime.now().difference(dateFin).inDays;
      return ValidationResult.invalide(
        'Clé expirée depuis $expDepuis jours'
      );
    }

    // 4. Clé valide
    final jours = dateFin.difference(DateTime.now()).inDays;
    return ValidationResult.valide(dateFin, jours);
  }
}

class ValidationResult {
  final bool valide;
  final String message;
  final DateTime? dateFin;
  final int joursRestants;

  ValidationResult.valide(this.dateFin, this.joursRestants)
      : valide = true,
        message = 'Clé valide';

  ValidationResult.invalide(this.message)
      : valide = false,
        dateFin = null,
        joursRestants = 0;
}
```

---

## PARTIE 5 — LicenceStorage
```dart
// lib/core/licence/licence_storage.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LicenceStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyLicence = 'mt_licence';
  static const _keyTelephone = 'mt_telephone';

  static Future<void> sauvegarder(Map<String, dynamic> data) async {
    await _storage.write(
      key: _keyLicence,
      value: jsonEncode(data),
    );
  }

  static Future<Map<String, dynamic>?> lire() async {
    final raw = await _storage.read(key: _keyLicence);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  static Future<LicenceStatut> verifierLocalement() async {
    final data = await lire();
    if (data == null) return LicenceStatut.nonActivee;

    final dateFin = DateTime.parse(data['date_fin']);
    final jours = dateFin.difference(DateTime.now()).inDays;
    final statut = data['statut'] as String?;

    if (DateTime.now().isAfter(dateFin)) {
      return LicenceStatut.expiree;
    }
    if (statut == 'essai') return LicenceStatut.essaiActif;
    if (jours <= 7) return LicenceStatut.expireBientot;
    return LicenceStatut.active;
  }

  static Future<int> getJoursRestants() async {
    final data = await lire();
    if (data == null) return 0;
    final dateFin = DateTime.parse(data['date_fin']);
    return dateFin.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  static Future<void> saveTelephone(String tel) async {
    await _storage.write(key: _keyTelephone, value: tel);
  }

  static Future<String?> getTelephone() async {
    return _storage.read(key: _keyTelephone);
  }

  static Future<void> supprimer() async {
    await _storage.delete(key: _keyLicence);
  }
}
```

---

## PARTIE 6 — Écran Activation
```dart
// lib/core/licence/screens/activation_screen.dart
// Trois modes sur un seul écran

// Structure de l'écran :
//
// ┌─────────────────────────────────────┐
// │  [Logo MoneyTracking]               │
// │  "Activez votre licence"            │
// ├─────────────────────────────────────┤
// │  📡 RÉCUPÉRATION AUTOMATIQUE        │
// │  Numéro : [___________________]     │
// │  [Récupérer ma licence]             │
// │  [Démarrer l'essai gratuit]         │
// ├─────────────────────────────────────┤
// │           ── ou ──                  │
// ├─────────────────────────────────────┤
// │  🔑 CLÉ MANUELLE (sans internet)    │
// │  [MT-XXXX-XXXXXXXXYYYYMMDD      ]   │
// │  [Activer avec cette clé]           │
// ├─────────────────────────────────────┤
// │  Pas de licence ?                   │
// │  👉 Souscrire sur moneytracking.com │
// │  📞 WhatsApp : +226 XX XX XX XX     │
// └─────────────────────────────────────┘
//
// Après saisie numéro + clic "Récupérer" :
// → Si licence active : déverrouiller app
// → Si en attente : afficher écran polling
//   avec spinner + "En attente de validation..."
//   (polling toutes les 30 secondes)
// → Si aucune : proposer essai ou souscrire
```

---

## PARTIE 7 — Écran Statut Licence
```dart
// lib/core/licence/screens/licence_status_screen.dart
// Accessible depuis Paramètres → Ma licence
//
// ┌─────────────────────────────────────┐
// │  🔑 Ma Licence MoneyTracking        │
// ├─────────────────────────────────────┤
// │  Statut : ✅ Active                 │
// │  Expire le : 30 mars 2026           │
// │  Jours restants : 187 jours         │
// │  Téléphone : 70XXXXXX               │
// ├─────────────────────────────────────┤
// │  [🔄 Vérifier en ligne]             │
// │  [➕ Renouveler ma licence]         │
// └─────────────────────────────────────┘
//
// Si expireBientot (≤ 7 jours) :
// ┌─────────────────────────────────────┐
// │  ⚠️ Licence bientôt expirée         │
// │  Il vous reste 5 jours.             │
// │  Renouvelez maintenant pour         │
// │  ne pas perdre vos données.         │
// │  [Renouveler — 1 000 FCFA/mois]    │
// └─────────────────────────────────────┘
```

---

## PARTIE 8 — Intégration dans main.dart
```dart
// Modifier main.dart pour vérifier la licence au démarrage

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Vérifier licence avant tout
  final statutLicence = await LicenceService.verifierAuDemarrage();

  runApp(
    ProviderScope(
      child: MoneyTrackingApp(
        statutLicenceInitial: statutLicence,
      ),
    ),
  );
}

class MoneyTrackingApp extends ConsumerWidget {
  final LicenceStatut statutLicenceInitial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: AppRouter.router(
        statutLicence: statutLicenceInitial,
      ),
    );
  }
}
```

---

## PARTIE 9 — Router avec garde licence
```dart
// Modifier GoRouter pour rediriger selon la licence

static GoRouter router({required LicenceStatut statutLicence}) {
  return GoRouter(
    initialLocation: _getInitialRoute(statutLicence),
    redirect: (context, state) async {
      final statut = await LicenceService.verifierAuDemarrage();

      // Routes publiques (pas besoin de licence)
      final routesPubliques = ['/activation', '/lock'];
      final estPublique = routesPubliques.any(
        (r) => state.matchedLocation.startsWith(r)
      );

      // Si licence invalide → rediriger vers activation
      if (statut == LicenceStatut.nonActivee ||
          statut == LicenceStatut.expiree) {
        return estPublique ? null : '/activation';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/activation',
        builder: (_, __) => const ActivationScreen()),
      // ... autres routes existantes
    ],
  );
}

static String _getInitialRoute(LicenceStatut statut) {
  switch (statut) {
    case LicenceStatut.nonActivee:
    case LicenceStatut.expiree:
      return '/activation';
    default:
      return '/lock'; // écran PIN normal
  }
}
```

---

## PARTIE 10 — Bannière expiration dans l'app

Ajouter dans le layout principal une bannière
visible quand la licence expire dans ≤ 7 jours :
```dart
// Dans le scaffold principal (après PIN validé)
FutureBuilder<int>(
  future: LicenceStorage.getJoursRestants(),
  builder: (context, snapshot) {
    final jours = snapshot.data ?? 999;
    if (jours > 7) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(
        vertical: 8, horizontal: 16
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              jours > 0
                ? '⚠️ Votre licence expire dans $jours jours'
                : '🔴 Licence expirée — renouvelez maintenant',
              style: const TextStyle(
                color: Colors.white, fontSize: 13
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/licence/statut'),
            child: const Text('Renouveler',
              style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
  },
),
```

---

## Résumé des changements

- Ajouter 3 packages dans `pubspec.yaml`
- Créer `lib/core/licence/` avec tous les fichiers
- Modifier `main.dart` pour vérifier licence au démarrage
- Modifier `GoRouter` pour rediriger si pas de licence
- Ajouter bannière expiration dans le scaffold principal
- Ajouter "Ma Licence" dans l'écran Paramètres


# 🔐 MoneyTracking — Système de licence non bloquant

## Principe fondamental
La licence ne bloque PAS l'app. L'utilisateur peut toujours
consulter ses données et les exporter. Seules les actions
d'écriture (création, modification) nécessitent une licence.

## Créer un LicenceGuard
```dart
// lib/core/licence/licence_guard.dart

enum ActionType {
  // ✅ Toujours autorisé — lecture seule
  consulterDashboard,
  voirHistorique,
  voirClients,
  exporterPDF,
  exporterExcel,
  exporterCSV,
  recevoirSMS,      // détection continue même sans licence

  // 🔒 Nécessite licence active
  confirmerTransaction,
  creerTransactionManuelle,
  ajouterClient,
  modifierClient,
  configurerOperateur,
  modifierTemplateSMS,
  lancerUSSD,
  rechargerCaisse,
}

class LicenceGuard {

  // Actions TOUJOURS autorisées
  static const _actionsLibres = {
    ActionType.consulterDashboard,
    ActionType.voirHistorique,
    ActionType.voirClients,
    ActionType.exporterPDF,
    ActionType.exporterExcel,
    ActionType.exporterCSV,
    ActionType.recevoirSMS,
  };

  /// Vérifie si une action est autorisée
  /// Si non → affiche le dialog de licence
  static Future<bool> verifier(
    BuildContext context,
    ActionType action,
  ) async {
    // Action libre → toujours OK
    if (_actionsLibres.contains(action)) return true;

    // Vérifier la licence
    final statut = await LicenceStorage.verifierLocalement();

    final autorise = statut == LicenceStatut.active ||
                     statut == LicenceStatut.essaiActif ||
                     statut == LicenceStatut.expireBientot;

    if (!autorise) {
      // Afficher dialog licence
      await _afficherDialogLicence(context, statut);
      return false;
    }
    return true;
  }

  /// Dialog affiché quand une action protégée est tentée
  static Future<void> _afficherDialogLicence(
    BuildContext context,
    LicenceStatut statut,
  ) async {
    final estExpiree = statut == LicenceStatut.expiree;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          estExpiree
            ? '🔴 Licence expirée'
            : '🔒 Licence requise'
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estExpiree
                ? 'Votre licence a expiré. Renouvelez pour '
                  'continuer à créer des transactions.'
                : 'Cette action nécessite une licence active.',
            ),
            const SizedBox(height: 12),
            // Rappeler ce qui reste gratuit
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Toujours disponible gratuitement :',
                    style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 12)),
                  SizedBox(height: 4),
                  Text('• Consultation de l\'historique',
                    style: TextStyle(fontSize: 12)),
                  Text('• Export PDF / Excel',
                    style: TextStyle(fontSize: 12)),
                  Text('• Détection SMS automatique',
                    style: TextStyle(fontSize: 12)),
                  Text('• Voir le dashboard',
                    style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/activation');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: Text(
              estExpiree ? 'Renouveler' : 'Activer ma licence'
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Utilisation dans le code existant

### Confirmer une transaction
```dart
// Dans TransactionScreen
Future<void> _confirmerTransaction() async {
  // Vérifier licence avant d'écrire
  final autorise = await LicenceGuard.verifier(
    context,
    ActionType.confirmerTransaction,
  );
  if (!autorise) return; // dialog déjà affiché

  // Continuer normalement
  await _transactionRepo.createFromSms(...);
}
```

### Lancer USSD
```dart
Future<void> _lancerUSSD() async {
  final autorise = await LicenceGuard.verifier(
    context,
    ActionType.lancerUSSD,
  );
  if (!autorise) return;
  await UssdLauncher.dial(code);
}
```

### Ajouter / modifier client
```dart
Future<void> _sauvegarderClient() async {
  final action = _isEdit
    ? ActionType.modifierClient
    : ActionType.ajouterClient;

  final autorise = await LicenceGuard.verifier(context, action);
  if (!autorise) return;

  await _clientRepo.save(_client);
}
```

### Configurer opérateur
```dart
Future<void> _sauvegarderOperateur() async {
  final autorise = await LicenceGuard.verifier(
    context,
    ActionType.configurerOperateur,
  );
  if (!autorise) return;
  await _operateurRepo.save(_operateur);
}
```

### Export — toujours libre, pas de garde
```dart
// Pas de LicenceGuard ici — export toujours autorisé
Future<void> _exporterPDF() async {
  await ExportService.exporterPDF(transactions);
}
```

---

## SMS Listener — toujours actif
```dart
// SmsListenerService — NE PAS ajouter de vérification licence
// Les SMS sont toujours détectés et enregistrés
// dans sms_messages même sans licence.
// La transaction sera créée automatiquement SI licence active,
// sinon le SMS est juste enregistré en attente.

static Future<void> process({
  required String sender,
  required String body,
}) async {
  // 1. Toujours enregistrer le SMS brut
  await _smsRepo.insert(SmsMessage(...));

  // 2. Vérifier licence pour créer la transaction
  final statut = await LicenceStorage.verifierLocalement();
  final peutCreer = statut == LicenceStatut.active ||
                    statut == LicenceStatut.essaiActif ||
                    statut == LicenceStatut.expireBientot;

  if (!peutCreer) {
    // SMS enregistré mais transaction en attente
    // Notification : "SMS détecté — Activez votre licence
    //                pour créer la transaction"
    await NotificationService.show(
      title: 'MoneyTracking — SMS détecté',
      body: 'Activez votre licence pour enregistrer '
            'la transaction automatiquement.',
    );
    return;
  }

  // 3. Licence active → créer transaction normalement
  await _creerTransaction(...);
}
```

---

## Indicateur visuel dans l'app

Ajouter un badge discret dans l'AppBar quand la licence
est inactive — pas bloquant, juste informatif :
```dart
// Dans le scaffold principal
AppBar(
  title: const Text('MoneyTracking'),
  actions: [
    FutureBuilder<LicenceStatut>(
      future: LicenceStorage.verifierLocalement(),
      builder: (context, snapshot) {
        final statut = snapshot.data;

        // Licence active → rien n'afficher
        if (statut == LicenceStatut.active ||
            statut == LicenceStatut.essaiActif) {
          return const SizedBox.shrink();
        }

        // Pas de licence ou expirée → badge orange
        return GestureDetector(
          onTap: () => context.push('/activation'),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '🔒 Mode lecture',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        );
      },
    ),
    // ... autres actions AppBar
  ],
)
```

---

## Résumé des changements

- Créer `lib/core/licence/licence_guard.dart`
- Ajouter `LicenceGuard.verifier()` avant chaque action d'écriture
- **Ne pas** ajouter de garde sur les actions de lecture/export
- `SmsListenerService` : toujours actif, mais crée la transaction
  uniquement si licence active (sinon SMS juste enregistré)
- Badge "Mode lecture" dans AppBar si pas de licence
- Le router **ne redirige plus** vers l'écran d'activation
  au démarrage — l'app s'ouvre normalement