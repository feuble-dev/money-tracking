from datetime import date, timedelta

from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from licences.auth import emettre_jeton
from licences.models import AppareilAutorise, Client, Licence
from licences.services import LicenceService
from sync.models import SyncedTransaction


class AdminTests(TestCase):
    def setUp(self):
        self.admin = APIClient()
        self.admin.force_authenticate(User.objects.create_user('admin', is_staff=True))
        self.client_obj = Client.objects.create(
            telephone='70111111', account_type='agence',
            password_hash=make_password('secret'),
        )
        res = LicenceService.creer_agence_avec_essai(self.client_obj, 'Tampouy', 'dev-1')
        self.agence, self.licence = res['agence'], res['licence']
        Licence.objects.create(
            agence=self.agence, code='MT-PAYE-1', device_id='dev-1',
            date_debut=date.today(), date_fin=date.today() + timedelta(days=365),
            duree_mois=12, montant_paye=4480, statut='active',
        )
        Client.objects.create(telephone='71000000', account_type='particulier')
        SyncedTransaction.objects.create(
            agence=self.agence, local_id='t1', amount=50000, operator_name='Orange Money',
            transaction_created_at=f'{date.today()}T10:00:00',
        )
        emettre_jeton('dev-1', 'creation', self.client_obj)

    def test_reserve_au_staff(self):
        anon = APIClient()
        for url in ['/api/admin/analytics/', '/api/admin/recherche/?q=70',
                    f'/api/admin/clients/{self.client_obj.id}/']:
            self.assertIn(anon.get(url).status_code, (401, 403))

    def test_jamais_de_hash_de_mot_de_passe(self):
        r = self.admin.get('/api/admin/clients/')
        self.assertNotIn('password_hash', r.data[0])
        self.assertIn('agences_count', r.data[0])
        r = self.admin.get(f'/api/admin/clients/{self.client_obj.id}/')
        self.assertNotIn('password_hash', r.data)
        self.assertTrue(r.data['a_mot_de_passe'])

    def test_analytics(self):
        r = self.admin.get('/api/admin/analytics/?jours=30')
        self.assertEqual(r.status_code, 200)
        k = r.data['kpis']
        self.assertEqual(k['revenus']['value'], 4480)
        self.assertEqual(k['mrr'], round(4480 / 12))
        self.assertEqual(k['particuliers'], 1)
        self.assertEqual(k['volume_synchronise']['value'], 50000)
        self.assertEqual(len(r.data['series']['revenus']), 30)
        self.assertEqual(r.data['operateurs'][0]['nom'], 'Orange Money')
        self.assertEqual(r.data['top_agences'][0]['nom'], 'Tampouy')
        # Au-delà de 90 jours, séries hebdomadaires.
        r = self.admin.get('/api/admin/analytics/?jours=365')
        self.assertLess(len(r.data['series']['revenus']), 60)

    def test_recherche(self):
        r = self.admin.get('/api/admin/recherche/?q=7011')
        self.assertEqual(r.data['clients'][0]['telephone'], '70111111')
        r = self.admin.get('/api/admin/recherche/?q=Tamp')
        self.assertEqual(r.data['agences'][0]['nom'], 'Tampouy')
        r = self.admin.get('/api/admin/recherche/?q=PAYE')
        self.assertEqual(r.data['licences'][0]['code'], 'MT-PAYE-1')

    def test_suspendre_puis_reactiver(self):
        url = f'/api/admin/licences/{self.licence.id}/'
        self.assertEqual(self.admin.post(url + 'suspendre/').data['statut'], 'suspendue')
        self.assertEqual(self.admin.post(url + 'suspendre/').status_code, 400)
        self.assertEqual(self.admin.post(url + 'reactiver/').data['statut'], 'essai')
        self.assertEqual(self.admin.post(url + 'detruire/').status_code, 400)

    def test_revoquer_un_appareil(self):
        app = AppareilAutorise.objects.get(device_id='dev-1')
        self.assertEqual(self.admin.delete(f'/api/admin/appareils/{app.id}/').status_code, 204)
        self.assertFalse(AppareilAutorise.objects.filter(id=app.id).exists())

    def test_compteurs(self):
        r = self.admin.get('/api/admin/compteurs/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(set(r.data), {'demandes', 'achats', 'expirent'})

    def test_demandes_affichent_le_montant(self):
        from licences.models import DemandeActivation
        DemandeActivation.objects.create(telephone='70111111', device_id='dev-1',
                                         agence=self.agence, duree_mois=12)
        r = self.admin.get('/api/admin/demandes/')
        self.assertEqual(r.data[0]['montant'], LicenceService.montant_pour_duree(12))
        self.assertEqual(r.data[0]['agence_nom'], 'Tampouy')
