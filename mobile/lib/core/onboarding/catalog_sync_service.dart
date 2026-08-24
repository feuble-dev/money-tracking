import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../sms/sms_pattern_builder.dart';
import 'models/catalog_models.dart';

const _catalogBaseUrl = 'https://api-money-tracking.rf-appdev.online/api/catalog';
// const _catalogBaseUrl = 'http://localhost:8000/api/catalog';

const _uuid = Uuid();

/// Récupère le catalogue centralisé (pays/opérateurs/types/patterns) et
/// l'importe dans la base locale. Compile les regex ici, jamais côté
/// backend/web (D2) — c'est le seul endroit qui appelle
/// SmsPatternBuilder.buildRegex pour des patterns venant du catalogue.
class CatalogSyncService {
  Future<List<CatalogCountry>> fetchCountries() async {
    final response = await http
        .get(Uri.parse('$_catalogBaseUrl/countries/'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => CatalogCountry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [accountType] ('particulier'|'agence') filtre les patterns SMS dont le
  /// SMS diffère selon le type de compte (cible_compte côté backend) — un
  /// SMS reçu par un compte Particulier n'est pas toujours identique à celui
  /// reçu par un compte Agence pour la même transaction.
  Future<List<CatalogOperator>> fetchOperators(
    String countryCode, {
    String? accountType,
  }) async {
    final uri = Uri.parse('$_catalogBaseUrl/countries/$countryCode/operators/')
        .replace(queryParameters: accountType != null ? {'account_type': accountType} : null);
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Erreur serveur (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final operators = data['operators'] as List;
    return operators
        .map((e) => CatalogOperator.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crée l'agence locale (miroir de l'agence backend créée via
  /// LicenceService.demarrerEssaiAvecAgence / agences/creer).
  Future<String> createLocalAgence({
    required String nom,
    required int backendAgenceId,
    bool isDefault = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final id = _uuid.v4();
    await db.insert('agences', {
      'id': id,
      'backend_agence_id': backendAgenceId,
      'nom': nom,
      'is_default': isDefault ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// Importe les opérateurs sélectionnés (avec leurs types + patterns) dans
  /// la base locale et les rattache à l'agence donnée.
  Future<void> importOperators(
    List<CatalogOperator> operators,
    String agenceId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final catalogOp in operators) {
        // Un opérateur catalogue déjà importé (ex: agence supplémentaire du
        // même compte) n'est pas recréé — juste relié à cette agence.
        final existingOp = await txn.query(
          'operators',
          where: 'catalog_operator_id = ?',
          whereArgs: [catalogOp.id],
        );
        final String operatorId;
        if (existingOp.isNotEmpty) {
          operatorId = existingOp.first['id'] as String;
        } else {
          operatorId = _uuid.v4();
          await txn.insert('operators', {
            'id': operatorId,
            'name': catalogOp.name,
            'logo_path': catalogOp.logoUrl,
            'sms_sender': catalogOp.smsSender,
            'is_active': 1,
            'catalog_operator_id': catalogOp.id,
            'is_custom': 0,
            'synced_at': now,
            'created_at': now,
          });
        }

        await txn.insert(
          'agence_operators',
          {'agence_id': agenceId, 'operator_id': operatorId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        for (final catalogType in catalogOp.transactionTypes) {
          final transactionTypeId =
              await _findOrCreateTransactionType(txn, catalogType);

          final existingLink = await txn.query(
            'operator_transaction_types',
            where: 'operator_id = ? AND transaction_type_id = ?',
            whereArgs: [operatorId, transactionTypeId],
          );
          final String linkId;
          if (existingLink.isNotEmpty) {
            linkId = existingLink.first['id'] as String;
            await txn.update(
              'operator_transaction_types',
              {
                'ussd_code': catalogType.ussdCode,
                'commission_taux': catalogType.commissionTaux,
                'catalog_link_id': catalogType.id,
              },
              where: 'id = ?',
              whereArgs: [linkId],
            );
          } else {
            linkId = _uuid.v4();
            await txn.insert('operator_transaction_types', {
              'id': linkId,
              'operator_id': operatorId,
              'transaction_type_id': transactionTypeId,
              'catalog_link_id': catalogType.id,
              'ussd_code': catalogType.ussdCode,
              'commission_taux': catalogType.commissionTaux,
              'is_active': 1,
              'created_at': now,
            });
          }

          for (final pattern in catalogType.smsPatterns) {
            final existingPattern = await txn.query(
              'sms_patterns',
              where: 'catalog_pattern_id = ?',
              whereArgs: [pattern.id],
            );
            if (existingPattern.isNotEmpty) continue; // déjà importé

            final zones = pattern.taggedZones
                .map((z) => TaggedZone(
                      start: z['start'] as int,
                      end: z['end'] as int,
                      fieldName: z['fieldName'] as String,
                      value: pattern.rawExample.substring(
                          z['start'] as int, z['end'] as int),
                    ))
                .toList();
            final regex = SmsPatternBuilder.buildRegex(
                pattern.rawExample, zones);

            await txn.insert('sms_patterns', {
              'id': _uuid.v4(),
              'operator_id': operatorId,
              'transaction_type': catalogType.code,
              'operator_transaction_type_id': linkId,
              'catalog_pattern_id': pattern.id,
              'direction': pattern.direction,
              'tagged_zones_json': SmsPatternBuilder.zonesToJson(zones),
              'source': 'catalog',
              'raw_example': pattern.rawExample,
              'pattern_json': SmsPatternBuilder.zonesToJson(zones),
              'regex_generated': regex,
              'created_at': now,
            });
          }
        }
      }
    });
  }

  Future<String> _findOrCreateTransactionType(
    Transaction txn,
    CatalogTransactionType catalogType,
  ) async {
    final existing = await txn.query(
      'transaction_types',
      where: 'code = ?',
      whereArgs: [catalogType.code],
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }
    final id = _uuid.v4();
    await txn.insert('transaction_types', {
      'id': id,
      'catalog_type_id': catalogType.id,
      'code': catalogType.code,
      'label': catalogType.label,
      'default_direction': catalogType.defaultDirection,
      'is_custom': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// Met à jour les opérateurs déjà importés localement (types + patterns)
  /// depuis le catalogue distant — n'ajoute JAMAIS un opérateur que
  /// l'agent n'a pas explicitement choisi à l'onboarding (importOperators
  /// s'en charge, c'est un choix délibéré de l'agent).
  ///
  /// C'est le mécanisme qui manquait pour que les corrections du catalogue
  /// admin (ex: un pattern SMS mal tagué qui empêchait des transactions
  /// réelles d'être détectées) atteignent les appareils déjà onboardés —
  /// jusqu'ici le catalogue n'était jamais réimporté après l'onboarding,
  /// même si `Country.catalog_version` (D6) était justement pensé pour
  /// permettre ce resync incrémental.
  ///
  /// Met aussi à jour les champs propres de l'opérateur (logo, nom,
  /// expéditeur SMS) — un logo uploadé après coup dans le dashboard admin
  /// ne remontait jamais sur les appareils déjà onboardés sinon.
  ///
  /// Ne touche jamais un pattern `source != 'catalog'` (un pattern custom
  /// ou — un jour — overridé localement par l'agent reste intouché).
  /// Retourne le nombre de champs/patterns effectivement modifiés.
  Future<int> resyncOperators({
    required String countryCode,
    String? accountType,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final operators = await fetchOperators(countryCode, accountType: accountType);
    int changed = 0;

    await db.transaction((txn) async {
      for (final catalogOp in operators) {
        final existingOp = await txn.query(
          'operators',
          where: 'catalog_operator_id = ?',
          whereArgs: [catalogOp.id],
        );
        if (existingOp.isEmpty) continue; // resync ne rajoute pas d'opérateur
        final operatorId = existingOp.first['id'] as String;
        final now = DateTime.now().toIso8601String();

        // Champs propres à l'opérateur (logo notamment) — un logo ajouté
        // après coup dans le dashboard admin ne remontait jamais ici avant,
        // seuls les types/patterns imbriqués étaient mis à jour.
        final current = existingOp.first;
        if (current['logo_path'] != catalogOp.logoUrl ||
            current['name'] != catalogOp.name ||
            current['sms_sender'] != catalogOp.smsSender) {
          await txn.update(
            'operators',
            {
              'logo_path': catalogOp.logoUrl,
              'name': catalogOp.name,
              'sms_sender': catalogOp.smsSender,
              'synced_at': now,
            },
            where: 'id = ?',
            whereArgs: [operatorId],
          );
          changed++;
        }

        for (final catalogType in catalogOp.transactionTypes) {
          final transactionTypeId = await _findOrCreateTransactionType(txn, catalogType);

          final existingLink = await txn.query(
            'operator_transaction_types',
            where: 'operator_id = ? AND transaction_type_id = ?',
            whereArgs: [operatorId, transactionTypeId],
          );
          final String linkId;
          if (existingLink.isNotEmpty) {
            linkId = existingLink.first['id'] as String;
            await txn.update(
              'operator_transaction_types',
              {
                'ussd_code': catalogType.ussdCode,
                'commission_taux': catalogType.commissionTaux,
                'catalog_link_id': catalogType.id,
              },
              where: 'id = ?',
              whereArgs: [linkId],
            );
          } else {
            linkId = _uuid.v4();
            await txn.insert('operator_transaction_types', {
              'id': linkId,
              'operator_id': operatorId,
              'transaction_type_id': transactionTypeId,
              'catalog_link_id': catalogType.id,
              'ussd_code': catalogType.ussdCode,
              'commission_taux': catalogType.commissionTaux,
              'is_active': 1,
              'created_at': now,
            });
          }

          for (final pattern in catalogType.smsPatterns) {
            final zones = pattern.taggedZones
                .map((z) => TaggedZone(
                      start: z['start'] as int,
                      end: z['end'] as int,
                      fieldName: z['fieldName'] as String,
                      value: pattern.rawExample.substring(
                          z['start'] as int, z['end'] as int),
                    ))
                .toList();
            final regex = SmsPatternBuilder.buildRegex(pattern.rawExample, zones);
            final zonesJson = SmsPatternBuilder.zonesToJson(zones);

            final existingPattern = await txn.query(
              'sms_patterns',
              where: 'catalog_pattern_id = ? AND source = ?',
              whereArgs: [pattern.id, 'catalog'],
            );

            if (existingPattern.isEmpty) {
              await txn.insert('sms_patterns', {
                'id': _uuid.v4(),
                'operator_id': operatorId,
                'transaction_type': catalogType.code,
                'operator_transaction_type_id': linkId,
                'catalog_pattern_id': pattern.id,
                'direction': pattern.direction,
                'tagged_zones_json': zonesJson,
                'source': 'catalog',
                'raw_example': pattern.rawExample,
                'pattern_json': zonesJson,
                'regex_generated': regex,
                'created_at': now,
              });
              changed++;
              continue;
            }

            final current = existingPattern.first;
            final unchanged = current['tagged_zones_json'] == zonesJson &&
                current['regex_generated'] == regex &&
                current['direction'] == pattern.direction;
            if (unchanged) continue;

            await txn.update(
              'sms_patterns',
              {
                'tagged_zones_json': zonesJson,
                'pattern_json': zonesJson,
                'regex_generated': regex,
                'direction': pattern.direction,
                'operator_transaction_type_id': linkId,
              },
              where: 'id = ?',
              whereArgs: [current['id']],
            );
            changed++;
          }
        }
      }
    });

    return changed;
  }
}
