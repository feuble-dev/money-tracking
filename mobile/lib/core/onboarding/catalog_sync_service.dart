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
}
