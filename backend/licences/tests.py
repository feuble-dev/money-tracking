from datetime import date, timedelta

from django.contrib.auth.hashers import make_password
from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient

from licences import signature
from licences.auth import emettre_jeton
from licences.models import AchatHistorique, AppareilAutorise, Client, Licence
from licences.services import HistoriqueService, LicenceService
from sync.models import AffiliationRequest, SyncedTransaction


PATRON_TEL = '70111111'
PATRON_DEVICE = 'device-patron-0001'
INTRUS_TEL = '76999999'
INTRUS_DEVICE = 'device-intrus-0001'


def api_pour(device_id, client=None, origine='creation'):
    """APIClient qui présente un jeton valide pour `device_id`."""
    api = APIClient()
    api.credentials(HTTP_X_DEVICE_TOKEN=emettre_jeton(device_id, origine, client))
    return api


class Base(TestCase):
    def setUp(self):
        cache.clear()
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
        self.patron_api = api_pour(PATRON_DEVICE, self.patron)
        self.intrus_api = api_pour(INTRUS_DEVICE)


class JetonAppareilTests(Base):
    """Le device_id seul ne prouve rien : il faut le jeton de l'appareil."""

    def test_sans_jeton_401(self):
        r = APIClient().get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE})
        self.assertEqual(r.status_code, 401)

    def test_jeton_d_un_autre_appareil_401(self):
        r = self.intrus_api.get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE})
        self.assertEqual(r.status_code, 401)

    def test_creation_de_compte_emet_un_jeton(self):
        r = APIClient().post('/api/licence/essai/', {
            'telephone': '75000000', 'device_id': 'uuid-neuf',
            'agence_nom': 'Nouvelle', 'password': 'abcdef',
        }, format='json')
        self.assertEqual(r.status_code, 201)
        jeton = r.data['device_token']
        api = APIClient()
        api.credentials(HTTP_X_DEVICE_TOKEN=jeton)
        r = api.get('/api/licence/agences/', {
            'telephone': '75000000', 'device_id': 'uuid-neuf'})
        self.assertEqual(len(r.data['agences']), 1)

    def test_login_emet_un_jeton(self):
        r = APIClient().post('/api/licence/login/', {
            'telephone': PATRON_TEL, 'password': 'secret123',
            'device_id': 'nouveau-tel',
        }, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertIn('device_token', r.data)

    def test_migration_installation_ancienne_une_seule_fois(self):
        Licence.objects.create(
            agence=self.agence, code='MT-LEGACY-1', device_id='TP1A.220624.014',
            date_debut=date.today(), date_fin=date.today() + timedelta(days=30),
            duree_mois=1,
        )
        r = APIClient().post('/api/licence/appareil/enregistrer/',
                             {'device_id': 'TP1A.220624.014'}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertIn('device_token', r.data)
        # Un second appareil avec le même Build.ID ne peut plus le réclamer.
        r = APIClient().post('/api/licence/appareil/enregistrer/',
                             {'device_id': 'TP1A.220624.014'}, format='json')
        self.assertEqual(r.status_code, 403)

    def test_migration_appareil_inconnu_refusee(self):
        r = APIClient().post('/api/licence/appareil/enregistrer/',
                             {'device_id': 'jamais-vu'}, format='json')
        self.assertEqual(r.status_code, 404)
        self.assertFalse(AppareilAutorise.objects.filter(device_id='jamais-vu').exists())

    def test_affiliation_premier_contact_emet_un_jeton(self):
        r = APIClient().post('/api/sync/demander-affiliation/', {
            'demandeur_telephone': INTRUS_TEL,
            'demandeur_device_id': 'uuid-agent',
            'patron_telephone': PATRON_TEL,
        }, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertIn('device_token', r.data)
        # Ce device_id est désormais connu : sans son jeton, refus.
        r = APIClient().post('/api/sync/demander-affiliation/', {
            'demandeur_telephone': INTRUS_TEL,
            'demandeur_device_id': 'uuid-agent',
            'patron_telephone': PATRON_TEL,
        }, format='json')
        self.assertEqual(r.status_code, 403)


class ControleAccesTests(Base):
    """Un numéro de téléphone n'est pas un secret : connaître celui d'un
    patron ne doit donner accès à rien (licences.auth)."""

    def test_essai_sur_numero_existant_sans_mot_de_passe_refuse(self):
        r = self.intrus_api.post('/api/licence/essai/', {
            'telephone': PATRON_TEL, 'device_id': INTRUS_DEVICE,
            'agence_nom': 'Pirate',
        }, format='json')
        self.assertEqual(r.status_code, 403)
        self.assertFalse(
            Licence.objects.filter(device_id=INTRUS_DEVICE).exists())

    def test_essai_sur_numero_existant_avec_mot_de_passe_ok(self):
        r = APIClient().post('/api/licence/essai/', {
            'telephone': PATRON_TEL, 'device_id': 'nouveau-tel-patron',
            'agence_nom': 'Agence 2', 'password': 'secret123',
        }, format='json')
        self.assertEqual(r.status_code, 201)

    def test_essai_depuis_appareil_du_proprietaire_ok(self):
        r = self.patron_api.post('/api/licence/essai/', {
            'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE,
            'agence_nom': 'Agence 2',
        }, format='json')
        self.assertEqual(r.status_code, 201)

    def test_detail_agence_reserve_au_patron(self):
        r = self.intrus_api.get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL, 'device_id': INTRUS_DEVICE})
        self.assertEqual(r.status_code, 404)
        r = self.patron_api.get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data['transactions']), 1)

    def test_liste_agences_et_codes_reserves_au_proprietaire(self):
        r = self.intrus_api.get('/api/licence/agences/', {
            'telephone': PATRON_TEL, 'device_id': INTRUS_DEVICE})
        self.assertEqual(r.data['agences'], [])
        r = self.patron_api.get('/api/licence/agences/', {
            'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE})
        self.assertEqual(len(r.data['agences']), 1)

    def test_auto_approbation_par_un_tiers_refusee(self):
        r = self.intrus_api.post('/api/sync/demander-affiliation/', {
            'demandeur_telephone': INTRUS_TEL,
            'demandeur_device_id': INTRUS_DEVICE,
            'patron_telephone': PATRON_TEL,
        }, format='json')
        demande_id = r.data['demande_id']
        r = self.intrus_api.post(f'/api/sync/affiliation/{demande_id}/approuver/', {
            'telephone': PATRON_TEL, 'device_id': INTRUS_DEVICE,
            'agence_id': self.agence.id,
        }, format='json')
        self.assertEqual(r.status_code, 403)
        self.assertFalse(
            Licence.objects.filter(device_id=INTRUS_DEVICE).exists())

    def test_agent_approuve_n_agit_pas_en_patron(self):
        agent_api = api_pour('device-agent', origine='affiliation')
        r = agent_api.post('/api/sync/demander-affiliation/', {
            'demandeur_telephone': INTRUS_TEL,
            'demandeur_device_id': 'device-agent',
            'patron_telephone': PATRON_TEL,
        }, format='json')
        demande_id = r.data['demande_id']
        r = self.patron_api.post(f'/api/sync/affiliation/{demande_id}/approuver/', {
            'telephone': PATRON_TEL, 'device_id': PATRON_DEVICE,
            'agence_id': self.agence.id,
        }, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(
            AffiliationRequest.objects.get(id=demande_id).statut, 'approuve')
        self.assertTrue(Licence.objects.filter(
            agence=self.agence, device_id='device-agent').exists())
        r = agent_api.get(
            f'/api/sync/agence-detail/{self.agence.id}/',
            {'telephone': PATRON_TEL, 'device_id': 'device-agent'})
        self.assertEqual(r.status_code, 404)


class CleLicenceTests(Base):
    def verifier(self, api, code, device_id):
        return api.post('/api/licence/verifier-cle/',
                        {'code': code, 'device_id': device_id}, format='json')

    def test_ancienne_cle_forgee_refusee(self):
        r = self.verifier(self.patron_api, 'MT-00000000-0000000020991231', PATRON_DEVICE)
        self.assertFalse(r.data['valide'])

    def test_ancienne_vraie_cle_pour_son_appareil_seulement(self):
        self.assertTrue(self.verifier(
            self.patron_api, self.licence.code, PATRON_DEVICE).data['valide'])
        self.assertFalse(self.verifier(
            self.intrus_api, self.licence.code, INTRUS_DEVICE).data['valide'])

    def test_cle_signee_valide(self):
        cle = signature.cle_pour_licence(self.licence)
        self.assertTrue(cle.startswith('MT2-'))
        r = self.verifier(self.patron_api, cle, PATRON_DEVICE)
        self.assertTrue(r.data['valide'])
        self.assertEqual(r.data['date_fin'], str(self.licence.date_fin))

    def test_cle_signee_d_un_autre_appareil_refusee(self):
        cle = signature.cle_pour_licence(self.licence)
        self.assertIsNone(signature.verifier(cle, INTRUS_DEVICE))

    def test_cle_signee_alteree_refusee(self):
        cle = signature.cle_pour_licence(self.licence)
        # Prolonger la date en modifiant un octet du contenu casse la signature.
        alteree = cle[:10] + ('A' if cle[10] != 'A' else 'B') + cle[11:]
        self.assertIsNone(signature.verifier(alteree, PATRON_DEVICE))

    def test_cle_publique_exposee(self):
        r = APIClient().get('/api/licence/cle-publique/')
        self.assertEqual(r.data['algorithme'], 'ed25519')
        self.assertEqual(r.data['cle'], signature.cle_publique_b64())


class ParticulierGratuitTests(TestCase):
    def test_licence_permanente_et_import_gratuit(self):
        r = APIClient().post('/api/licence/essai/', {
            'telephone': '71000000', 'device_id': 'uuid-perso',
            'account_type': 'particulier', 'agence_nom': 'Mon suivi personnel',
            'password': 'abcdef',
        }, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertEqual(r.data['statut'], 'active')
        self.assertEqual(r.data['date_fin'], '2099-12-31')
        api = APIClient()
        api.credentials(HTTP_X_DEVICE_TOKEN=r.data['device_token'])
        r = api.post('/api/licence/historique/demander/', {
            'telephone': '71000000', 'device_id': 'uuid-perso',
            'date_debut': (date.today() - timedelta(days=5 * 365)).isoformat(),
        }, format='json')
        self.assertEqual(r.data['statut'], 'active')
        self.assertEqual(r.data['montant'], 0)


class ImportHistoriqueTests(TestCase):
    """Un achat d'import ne couvre que la période payée (D5)."""

    def setUp(self):
        self.client_obj = Client.objects.create(telephone=PATRON_TEL)
        self.api = api_pour(PATRON_DEVICE, self.client_obj)

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


class LimitationLoginTests(TestCase):
    def test_force_brute_bloquee(self):
        cache.clear()
        api = APIClient()
        Client.objects.create(telephone=PATRON_TEL,
                              password_hash=make_password('bon-mdp'))
        codes = [
            api.post('/api/licence/login/', {
                'telephone': PATRON_TEL, 'password': f'essai{i}',
                'device_id': 'd',
            }, format='json').status_code
            for i in range(12)
        ]
        self.assertEqual(codes[:10], [401] * 10)
        self.assertEqual(codes[-1], 429)
