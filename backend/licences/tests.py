from datetime import date, timedelta

from django.contrib.auth.hashers import make_password
from django.test import TestCase
from rest_framework.test import APIClient

from licences.models import AchatHistorique, Client, Licence
from licences.services import HistoriqueService, LicenceService
from sync.models import AffiliationRequest, SyncedTransaction


PATRON_TEL = '70111111'
PATRON_DEVICE = 'device-patron-0001'
INTRUS_TEL = '76999999'
INTRUS_DEVICE = 'device-intrus-0001'


class ControleAccesTests(TestCase):
    """Un numéro de téléphone n'est pas un secret : connaître celui d'un
    patron ne doit donner accès à rien (licences.auth)."""

    def setUp(self):
        self.api = APIClient()
        self.patron = Client.objects.create(
            telephone=PATRON_TEL, account_type='agence',
            password_hash=make_password('secret123'),
        )
        res = LicenceService.creer_agence_avec_essai(
            self.patron, 'Agence centre', PATRON_DEVICE)
        self.agence = res['agence']
        self.licence = res['licence']
        SyncedTransaction.objects.create(
            agence=self.agence, local_id='tx1', amount=50000,
            transaction_created_at='2026-10-01T10:00:00',
        )

    # --- /essai/ ---------------------------------------------------------
    def test_essai_sur_numero_existant_sans_mot_de_passe_refuse(self):
        r = self.api.post('/api/licence/essai/', {
            'telephone': PATRON_TEL, 'device_id': INTRUS_DEVICE,
            'agence_nom': 'Pirate',
        }, format='json')
        self.assertEqual(r.status_code, 403)
        self.assertFalse(
            Licence.objects.filter(device_id=INTRUS_DEVICE).exists())

    def test_essai_sur_numero_existant_avec_mot_de_passe_ok(self):
        r = self.api.post('/api/licence/essai/', {
            'telephone': PATRON_TEL, 'device_id': 'nouveau-tel-patron',
            'agence_nom': 'Agence 2', 'password': 'secret123',
        }, format='json')
        self.assertEqual(r.status_code, 201)

    def test_essai_depuis_appareil_du_proprietaire_ok(self):
        r = self.api.post('/api/licence/essai/', {
            'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE,
            'agence_nom': 'Agence 2',
        }, format='json')
        self.assertEqual(r.status_code, 201)

    def test_nouveau_compte_inchange(self):
        r = self.api.post('/api/licence/essai/', {
            'telephone': '75000000', 'device_id': 'd-new',
            'agence_nom': 'Nouvelle', 'password': 'abcdef',
        }, format='json')
        self.assertEqual(r.status_code, 201)

    # --- lecture des données du patron ----------------------------------
    def test_detail_agence_avec_le_seul_numero_refuse(self):
        r = self.api.get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL, 'device_id': INTRUS_DEVICE})
        self.assertEqual(r.status_code, 404)
        r = self.api.get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL})
        self.assertEqual(r.status_code, 404)

    def test_detail_agence_depuis_appareil_du_patron_ok(self):
        r = self.api.get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data['transactions']), 1)

    def test_liste_agences_et_codes_reserves_au_proprietaire(self):
        r = self.api.get('/api/licence/agences/', {'telephone': PATRON_TEL})
        self.assertEqual(r.data['agences'], [])
        r = self.api.get('/api/licence/agences/', {
            'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE})
        self.assertEqual(len(r.data['agences']), 1)
        r = self.api.get('/api/sync/mes-agences/', {'telephone': PATRON_TEL})
        self.assertEqual(r.data['agences'], [])

    # --- affiliation ------------------------------------------------------
    def test_auto_approbation_par_un_tiers_refusee(self):
        r = self.api.post('/api/sync/demander-affiliation/', {
            'demandeur_telephone': INTRUS_TEL,
            'demandeur_device_id': INTRUS_DEVICE,
            'patron_telephone': PATRON_TEL,
        }, format='json')
        demande_id = r.data['demande_id']
        r = self.api.post(f'/api/sync/affiliation/{demande_id}/approuver/', {
            'telephone': PATRON_TEL, 'device_id': INTRUS_DEVICE,
            'agence_id': self.agence.id,
        }, format='json')
        self.assertEqual(r.status_code, 403)
        self.assertFalse(
            Licence.objects.filter(device_id=INTRUS_DEVICE).exists())

    def test_patron_approuve_puis_agent_ne_peut_pas_agir_en_patron(self):
        r = self.api.post('/api/sync/demander-affiliation/', {
            'demandeur_telephone': INTRUS_TEL,
            'demandeur_device_id': 'device-agent',
            'patron_telephone': PATRON_TEL,
        }, format='json')
        demande_id = r.data['demande_id']
        r = self.api.post(f'/api/sync/affiliation/{demande_id}/approuver/', {
            'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE,
            'agence_id': self.agence.id,
        }, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(
            AffiliationRequest.objects.get(id=demande_id).statut, 'approuve')
        # L'agent opère l'agence (licence pour son appareil)…
        self.assertTrue(Licence.objects.filter(
            agence=self.agence, device_id='device-agent').exists())
        # … mais n'accède pas aux vues « patron ».
        r = self.api.get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL, 'device_id': 'device-agent'})
        self.assertEqual(r.status_code, 404)

    # --- clé de licence ---------------------------------------------------
    def test_cle_forgee_refusee(self):
        r = self.api.post('/api/licence/verifier-cle/', {
            'code': 'MT-00000000-0000000020991231',
            'device_id': PATRON_DEVICE,
        }, format='json')
        self.assertFalse(r.data['valide'])

    def test_vraie_cle_acceptee_pour_son_appareil_seulement(self):
        r = self.api.post('/api/licence/verifier-cle/', {
            'code': self.licence.code, 'device_id': PATRON_DEVICE,
        }, format='json')
        self.assertTrue(r.data['valide'])
        r = self.api.post('/api/licence/verifier-cle/', {
            'code': self.licence.code, 'device_id': INTRUS_DEVICE,
        }, format='json')
        self.assertFalse(r.data['valide'])


class ImportHistoriqueTests(TestCase):
    """Un achat d'import ne couvre que la période payée (D5)."""

    def setUp(self):
        self.api = APIClient()
        self.client_obj = Client.objects.create(telephone=PATRON_TEL)

    def demander(self, jours_en_arriere):
        d = date.today() - timedelta(days=jours_en_arriere)
        return self.api.post('/api/licence/historique/demander/', {
            'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE,
            'date_debut': d.isoformat(),
        }, format='json')

    def test_import_gratuit_ne_debloque_pas_5_ans(self):
        r = self.demander(200)
        self.assertEqual(r.data['statut'], 'active')
        self.assertEqual(r.data['montant'], 0)
        r = self.demander(5 * 365)
        self.assertEqual(r.data['statut'], 'en_attente')
        self.assertEqual(r.data['montant'], 800)

    def test_periode_deja_couverte(self):
        self.demander(200)
        r = self.demander(100)
        self.assertEqual(r.data['statut'], 'deja_active')

    def test_seul_l_ecart_est_facture(self):
        AchatHistorique.objects.create(
            client=self.client_obj, device_id=PATRON_DEVICE,
            date_debut_demandee=date.today() - timedelta(days=2 * 365),
            statut='active', token='HT-AAAA-1', montant_paye=200,
        )
        r = self.demander(4 * 365)
        self.assertEqual(r.data['montant'], 600 - 200)

    def test_ancien_achat_sans_date_couvre_tout(self):
        AchatHistorique.objects.create(
            client=self.client_obj, device_id=PATRON_DEVICE,
            date_debut_demandee=None, statut='active', token='HT-OLD-1',
        )
        r = self.demander(6 * 365)
        self.assertEqual(r.data['statut'], 'deja_active')
        self.assertIsNone(r.data['date_debut_couverte'])

    def test_cout_inchange(self):
        self.assertEqual(
            HistoriqueService.calculer_cout(date.today() - timedelta(days=300)), 0)
