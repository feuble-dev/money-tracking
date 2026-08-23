# -*- coding: utf-8 -*-
"""
Script ponctuel : peuple le catalogue (Pays/Operateurs/Types/Patterns) a
partir de vrais SMS Orange Money / Moov Money / Coris Money / Wave.
Execute une seule fois via : python manage.py shell < _seed_catalog.py
Les offsets des zones taguees sont calcules automatiquement (raw.index())
plutot qu'a la main, pour eviter les erreurs de comptage sur du texte reel.
"""
from catalog.models import Country, Operator, TransactionType, OperatorTransactionType, SmsPattern

def zones_for(raw, fields):
    """fields: liste de (field_name, valeur_exacte_dans_raw). Cherche a
    partir de la position courante pour gerer les valeurs dupliquees dans
    le meme texte (ex: le meme montant apparait deux fois)."""
    zones = []
    cursor = 0
    for name, value in fields:
        idx = raw.index(value, cursor)
        zones.append({'start': idx, 'end': idx + len(value), 'fieldName': name})
        cursor = idx + len(value)
    return zones

# --- Pays ---------------------------------------------------------------
country, _ = Country.objects.get_or_create(
    code='BF', defaults={'name': 'Burkina Faso', 'dial_code': '+226'}
)

# --- Types de transaction globaux (D3) -----------------------------------
TYPES = [
    ('depot', 'Depot', 'in'),
    ('retrait', 'Retrait', 'out'),
    ('transfert', 'Transfert', 'in'),
    ('paiement_marchand', 'Paiement marchand', 'out'),
    ('paiement_facture', 'Paiement facture', 'out'),
    ('achat_credit', 'Achat de credit', 'out'),
]
type_objs = {}
for code, label, direction in TYPES:
    t, _ = TransactionType.objects.get_or_create(
        code=code, defaults={'label': label, 'default_direction': direction}
    )
    type_objs[code] = t

# --- Operateurs -----------------------------------------------------------
OPERATORS = [
    ('Orange Money', 'OrangeMoney'),
    ('Moov Money', 'MOOV MONEY'),
    ('Coris Money', 'CORISMONEY'),
    ('Wave', 'WAVE'),
]
operator_objs = {}
for name, sender in OPERATORS:
    op, _ = Operator.objects.get_or_create(
        country=country, name=name, defaults={'sms_sender': sender, 'is_active': True}
    )
    operator_objs[name] = op


def add_pattern(operator_name, type_code, raw, fields, direction_override=None):
    operator = operator_objs[operator_name]
    ttype = type_objs[type_code]
    link, _ = OperatorTransactionType.objects.get_or_create(
        operator=operator, transaction_type=ttype
    )
    zones = zones_for(raw, fields)
    # Evite les doublons si le script est rejoue.
    if SmsPattern.objects.filter(operator_transaction_type=link, raw_example=raw).exists():
        return
    SmsPattern.objects.create(
        operator_transaction_type=link,
        raw_example=raw,
        tagged_zones=zones,
        direction_override=direction_override,
        cible_compte='tous',
    )


# =========================================================================
# ORANGE MONEY
# =========================================================================

add_pattern('Orange Money', 'depot',
    "Cher client, vous avez recu 14700.0 FCFA, Frais:  FCFA, Taxe:  FCFA de 4883151 KREEZUS. Votre solde est de 15209.69 FCFA. ID Trans: CI260814.1103.19334149. Merci d'utiliser Orange Money.",
    [('montant', '14700.0'), ('numero_client', '4883151'), ('nom_client', 'KREEZUS'),
     ('solde', '15209.69'), ('operator_transaction_id', 'CI260814.1103.19334149')])

add_pattern('Orange Money', 'retrait',
    "Vous avez retire 1,300.00 FCFA aupres de l agent 5524806 ANSV SAWADOGO MAHAMADI GRAND ESPACE CHEZ SAWADOGO M, Trans ID : CO260819.0925.42113517. Votre solde est de : 51414.69 FCFA. Telechargez la nouvelle application Orange Money : https://onelink.to/trqvq2",
    [('montant', '1,300.00'), ('numero_client', '5524806'),
     ('operator_transaction_id', 'CO260819.0925.42113517'), ('solde', '51414.69')])

add_pattern('Orange Money', 'transfert',
    "Cher client, vous avez transfere 2,525.00 FCFA, Frais: 0.0 FCFA, Taxe:  FCFA au numero 56328844,ISSOUF. Votre solde est de  12684.69 FCFA. ID Trans: PP260814.1106.97303900. Pour toute reclamation contactez par appel le 127 ou whatsapp 07000121. Orange Money BF",
    [('montant', '2,525.00'), ('numero_client', '56328844'), ('nom_client', 'ISSOUF'),
     ('solde', '12684.69'), ('operator_transaction_id', 'PP260814.1106.97303900')],
    direction_override='out')

add_pattern('Orange Money', 'transfert',
    "Vous avez recu 53500.0 FCFA, Frais:  FCFA, Taxe:  FCFA du 77952024,RIMALGUEDORAHIMATA. Le solde de votre compte est de 57747.69 FCFA Trans ID: PP260818.2016.86766195. Flashez le QR CODE marchand avec Max it pour plus de facilite : https://onelink.to/nn64xw",
    [('montant', '53500.0'), ('numero_client', '77952024'), ('nom_client', 'RIMALGUEDORAHIMATA'),
     ('solde', '57747.69'), ('operator_transaction_id', 'PP260818.2016.86766195')],
    direction_override='in')

add_pattern('Orange Money', 'paiement_marchand',
    "Votre paiement de 2,000.00 FCFA, Frais: 17.3913 FCFA, Taxe: 2.6087 FCFA a ACCEPTEUR GD ABDOUL MOUBARAK SERVICES ABDOUL MOUBARAK SERVICES a ete effectue avec succes. Votre solde est de : 43189.69 FCFA. Trans id: MP260820.2244.86724340.",
    [('montant', '2,000.00'), ('nom_client', 'ACCEPTEUR GD ABDOUL MOUBARAK SERVICES ABDOUL MOUBARAK SERVICES'),
     ('solde', '43189.69'), ('operator_transaction_id', 'MP260820.2244.86724340')])

add_pattern('Orange Money', 'paiement_marchand',
    "Votre paiement de  1050 FCFA a Forfait a ete effectue avec succes. Votre solde:  673 FCFA.Trans id: MP231222.0724.F17725. Reference : $REFERENCE_NO. Pour profiter du Bonus internet telecharger Max IT en cliquant ici http://onelink.to/nn64xw",
    [('montant', '1050'), ('nom_client', 'Forfait'), ('solde', '673'),
     ('operator_transaction_id', 'MP231222.0724.F17725')])

add_pattern('Orange Money', 'achat_credit',
    "Vous avez recharge 125.00 FCFA d unites. Gagnez 200% de bonus sur toutes premieres recharges Orange Money de moins de 10000F et 100% sur les autres recharges. Bonus valable 7 jours et utilisable vers tous les reseaux nationaux. Votre solde est de 36904.69 FCFA. TRANS ID: RC260822.1419.95735921. Rendez-vous sur Max it : http://urlz.fr/bpmE pour profiter de nos meilleures offres.",
    [('montant', '125.00'), ('solde', '36904.69'), ('operator_transaction_id', 'RC260822.1419.95735921')])

add_pattern('Orange Money', 'paiement_facture',
    "Votre paiement de facture ONEA a reussi,No Abonne:14012565081000,Montant Paye:4062FCFA , TransID:MP231129.0840.G01130.Votre solde est de:5099FCFA",
    [('numero_client', '14012565081000'), ('montant', '4062'),
     ('operator_transaction_id', 'MP231129.0840.G01130'), ('solde', '5099')])

# =========================================================================
# MOOV MONEY
# =========================================================================

add_pattern('Moov Money', 'depot',
    "Depot d'argent reussi aupres de: KREEZUS 01469501\nCode agent: 01375\nMontant: 3 000,00 FCFA\nTID: DF73DX4HC9\nSolde: 3 018,00 FCFA",
    [('nom_client', 'KREEZUS 01469501'), ('numero_client', '01375'), ('montant', '3 000,00'),
     ('operator_transaction_id', 'DF73DX4HC9'), ('solde', '3 018,00')])

add_pattern('Moov Money', 'retrait',
    "Retrait d’argent  réussi auprès de l’ Agent  ADAMA KONGOUINDIGA \nCode d'agent: 1030478 \nMontant: 51 000,00 FCFA, \nFrais: 510,00 FCFA  \nTotal: 51 510,00 FCFA \nDate: 08/11/2025 13H28\nTxn ID: CO251108.1328.F20530  \nSolde: 20 571,00FCFA",
    [('nom_client', 'ADAMA KONGOUINDIGA'), ('numero_client', '1030478'), ('montant', '51 000,00'),
     ('operator_transaction_id', 'CO251108.1328.F20530'), ('solde', '20 571,00')])

add_pattern('Moov Money', 'transfert',
    "Vous avez reçu 300,00 FCFA de MAIMOUNA NABOLE. \nNuméro: 22652124881\nDate: 20/12/2025 19:35:19\nTID: CLK93W31R3\nSolde: 318,00 FCFA",
    [('montant', '300,00'), ('nom_client', 'MAIMOUNA NABOLE'), ('numero_client', '22652124881'),
     ('operator_transaction_id', 'CLK93W31R3'), ('solde', '318,00')],
    direction_override='in')

add_pattern('Moov Money', 'transfert',
    "Transfert National d'argent réussi pour KOMKIETA ARNAUD SAWADOGO\nNuméro: 22673781319\nMontant: 505,00 FCFA\nFrais: Frais:0,00 FCFA FCFA\nTotal:505,00 FCFA\nDate: 18/08/2022 18H22 \nTID: PP220818.1822.B15418 \nSolde: 572,00 FCFA",
    [('nom_client', 'KOMKIETA ARNAUD SAWADOGO'), ('numero_client', '22673781319'), ('montant', '505,00'),
     ('operator_transaction_id', 'PP220818.1822.B15418'), ('solde', '572,00')],
    direction_override='out')

add_pattern('Moov Money', 'paiement_marchand',
    "Paiement reussi auprès du marchand YENGA KREEZUS \nCode marchand: 63380912 \nMontant: 128,00 FCFA \nFrais: 0,00 FCFA \nTOTAL: 128,00 FCFA \nDate: 01/12/2025 19:55 \nTID: CL152ZYY05 \nSolde: 118,00 FCFA\nReference: 1110155910476",
    [('nom_client', 'YENGA KREEZUS'), ('numero_client', '63380912'), ('montant', '128,00'),
     ('operator_transaction_id', 'CL152ZYY05'), ('solde', '118,00')])

add_pattern('Moov Money', 'paiement_facture',
    "Paiement réussi pour la facture ONEA numero 14012565081000 \nMontant: 5 125,00 FCFA \nPénalité: 4 000,00 FCFA \nMontant total:9 125,00 FCFA\nFrais: 150,00 FCFA\nDate: 09/12/2025 18:24\nTID: CL993D1HFZ\nSolde: 843,00 FCFA\nONEA et MOOV Money vous remercient.",
    [('numero_client', '14012565081000'), ('montant', '5 125,00'),
     ('operator_transaction_id', 'CL993D1HFZ'), ('solde', '843,00')])

add_pattern('Moov Money', 'achat_credit',
    "Ref :RCA220502.2058.B832870 , Vous avez rechargé le 22663622761 de 125,00 FCFA de crédit.  Votre solde MOOV Money est de 192,00 FCFA.",
    [('operator_transaction_id', 'RCA220502.2058.B832870'), ('numero_client', '22663622761'),
     ('montant', '125,00'), ('solde', '192,00')])

# =========================================================================
# CORIS MONEY
# =========================================================================

add_pattern('Coris Money', 'depot',
    "Vous avez recu 500.0F de 8566356 AVD / DIALLO MOUNIRA le 02/08/2024 15:16:19. TID 20248219.OB8566356.541. Votre solde est de 500.00F",
    [('montant', '500.0'), ('numero_client', '8566356'), ('nom_client', 'DIALLO MOUNIRA'),
     ('operator_transaction_id', '20248219.OB8566356.541'), ('solde', '500.00')])

add_pattern('Coris Money', 'depot',
    "Vous avez recu depuis le compte bancaire de LENGANE, un montant de 2500.0F le 28/04/2026 17:51:04. TID: 20264284.US0001291.972",
    [('nom_client', 'LENGANE'), ('montant', '2500.0'), ('operator_transaction_id', '20264284.US0001291.972')])

add_pattern('Coris Money', 'retrait',
    "Vous avez effectue un retrait de 10000.0F, Frais : 100.0F, Total: 10100.0F  aupres de l'agent 3768294 0001 - SIDYANE JEAN CLEMENT (0429) le 22/12/2025 18:06:49. TID: 2025122249.MV3768294.266. Votre solde est de 314.00F",
    [('montant', '10000.0'), ('numero_client', '3768294'), ('nom_client', 'SIDYANE JEAN CLEMENT'),
     ('operator_transaction_id', '2025122249.MV3768294.266'), ('solde', '314.00')])

add_pattern('Coris Money', 'transfert',
    "Vous avez envoye 30300.0F, Frais : 0.0F, Total: 30300F a NAKOULMA 55980548 le 26/01/2026 22:51:36. TID:  202612636.UZ0001291.287. Votre solde est de 69.00F",
    [('montant', '30300.0'), ('nom_client', 'NAKOULMA'), ('numero_client', '55980548'),
     ('operator_transaction_id', '202612636.UZ0001291.287'), ('solde', '69.00')],
    direction_override='out')

add_pattern('Coris Money', 'paiement_marchand',
    "Vous avez effectue un paiement d'un montant de 538.0F le 06/12/2025 08:57:53 aupres de 0600603 KREEZUS. TID: 202512653.FF0600603.017. Votre solde est de 1617.00F",
    [('montant', '538.0'), ('numero_client', '0600603'), ('nom_client', 'KREEZUS'),
     ('operator_transaction_id', '202512653.FF0600603.017'), ('solde', '1617.00')])

add_pattern('Coris Money', 'paiement_facture',
    "Paiement facture de 4833.0F, Frais: 0.0F, Total: 4833F pour le facturier 0024664 ONEA le 23/10/2024 08:46:18. TID : 2024102318.AM0001291.431. Votre solde est 67.00F",
    [('montant', '4833.0'), ('operator_transaction_id', '2024102318.AM0001291.431'), ('solde', '67.00')])

# =========================================================================
# WAVE (echantillon limite : uniquement transfert recu dans les SMS fournis)
# =========================================================================

add_pattern('Wave', 'transfert',
    "Vous avez recu 800F\nDe Sita Dabilgou (57563534)\nNouveau solde: 1.600F \n+infos: 80001257\nAvec UBA\nT26Y2JQ2D6DVU2YQQ",
    [('montant', '800'), ('nom_client', 'Sita Dabilgou'), ('numero_client', '57563534'),
     ('solde', '1.600'), ('operator_transaction_id', 'T26Y2JQ2D6DVU2YQQ')],
    direction_override='in')

print("=== Catalogue peuple ===")
for op_name, op in operator_objs.items():
    n_types = OperatorTransactionType.objects.filter(operator=op).count()
    n_patterns = SmsPattern.objects.filter(operator_transaction_type__operator=op).count()
    print(f"{op_name}: {n_types} type(s) actives, {n_patterns} pattern(s)")
