import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneytracking/core/licence/offline_key.dart';
import 'package:moneytracking/core/network/api_client.dart';
import 'package:moneytracking/core/security/device_identity.dart';

/// Vecteur produit par le backend (licences/signature.py) avec le
/// LICENCE_SECRET par défaut : agence 12, appareil « abc-uuid »,
/// fin 2027-01-31, statut active.
const _key =
    'MT2-AAAADAobqmm7UuYkATVq_ucvbZNDc6Z_Ms2NdNBE2PXjeshgPWF8C_H1ModVI-yI54SbwpmEmT4G-4peQETrQ9OjKIpeonAFHyJKCAw';
const _publicKey = 'EMj3TNL9cusul3Dj2qt8EzB/27tDeTG6NB9AE2164oI=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    DeviceIdentity.resetCache();
  });

  group('OfflineKey (clé signée par le serveur)', () {
    final pk = base64.decode(_publicKey);

    test('clé authentique pour cet appareil', () async {
      final l = await OfflineKey.verifyWith(_key, 'abc-uuid', pk);
      expect(l, isNotNull);
      expect(l!.agenceId, 12);
      expect(l.dateFin, DateTime(2027, 1, 31));
      expect(l.statut, 'active');
    });

    test('refusée pour un autre appareil', () async {
      expect(await OfflineKey.verifyWith(_key, 'autre-appareil', pk), isNull);
    });

    test('refusée si altérée (prolonger la date casse la signature)', () async {
      final altered = '${_key.substring(0, 10)}B${_key.substring(11)}';
      expect(await OfflineKey.verifyWith(altered, 'abc-uuid', pk), isNull);
    });

    test("l'ancien format non signé n'est jamais accepté hors ligne", () async {
      expect(
          await OfflineKey.verifyWith(
              'MT-00000000-0000000020991231', 'abc-uuid', pk),
          isNull);
    });
  });

  group('DeviceIdentity', () {
    test('nouvelle installation : UUID aléatoire, stable', () async {
      DeviceIdentity.isLegacyInstall = () async => false;
      final a = await DeviceIdentity.id();
      DeviceIdentity.resetCache();
      final b = await DeviceIdentity.id();
      expect(a, b);
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(a), isTrue);
    });
  });

  group('ApiClient', () {
    test('envoie le jeton et mémorise celui renvoyé par le serveur', () async {
      final seen = <String?>[];
      ApiClient.httpClient = MockClient((req) async {
        seen.add(req.headers['X-Device-Token']);
        return http.Response(
            jsonEncode({'ok': true, 'device_token': 'secret-1'}), 201,
            headers: {'content-type': 'application/json'});
      });
      final first = await ApiClient.post('https://x/essai/', {'a': 1});
      expect(first.ok, isTrue);
      await ApiClient.get('https://x/agences/');
      expect(seen, [null, 'secret-1']);
      expect(await DeviceIdentity.token(), 'secret-1');
    });

    test('reconnaît un appareil non authentifié', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response(
          jsonEncode({'erreur': 'x', 'code': 'jeton_appareil'}), 401));
      final res = await ApiClient.get('https://x/agences/');
      expect(res.needsDeviceAuth, isTrue);
      expect(res.error(), 'x');
    });
  });
}
