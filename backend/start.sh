#!/bin/bash
cd "$(dirname "$0")"
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
