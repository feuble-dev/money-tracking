import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/sync/sync_service.dart';
import 'backup_crypto.dart';

/// Une sauvegarde présente sur l'appareil.
class BackupFile {
  final File file;
  final DateTime modified;
  final int sizeBytes;
  const BackupFile(this.file, this.modified, this.sizeBytes);
  String get name => p.basename(file.path);
}

/// Création, liste et restauration des sauvegardes. Toute la logique
/// fichiers/chiffrement est ici ; les écrans ne font que demander un mot de
/// passe et afficher le résultat.
class BackupService {
  BackupService._();

  static const extension = '.mmtbak';
  static const keepLast = 7;
  static const minPasswordLength = 6;

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'backups')).create(recursive: true);
  }

  static Future<String> _dbPath() async =>
      p.join(await getDatabasesPath(), 'moneytracking.db');

  static Future<List<BackupFile>> list() async {
    try {
      final dir = await _dir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(extension))
          .map((f) {
        final stat = f.statSync();
        return BackupFile(f, stat.modified, stat.size);
      }).toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      return files;
    } catch (_) {
      return const [];
    }
  }

  /// Sauvegarde chiffrée de la base actuelle.
  static Future<BackupFile> create(String password) async {
    final source = File(await _dbPath());
    if (!await source.exists()) {
      throw const BackupFormatException('Base de données introuvable');
    }
    // La base est en mode WAL : sans ce report, les dernières écritures
    // (encore dans moneytracking.db-wal) manqueraient à la sauvegarde.
    final db = await DatabaseHelper.instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

    final plain = await source.readAsBytes();
    // PBKDF2 + AES en pur Dart : hors du thread UI pour ne pas figer l'écran.
    final encrypted =
        await Isolate.run(() => BackupCrypto.encrypt(plain, password));

    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dest = File(p.join((await _dir()).path,
        'moneytracking_backup_$stamp$extension'));
    await dest.writeAsBytes(encrypted, flush: true);
    await _prune();
    final stat = dest.statSync();
    return BackupFile(dest, stat.modified, stat.size);
  }

  static Future<BackupKind> kindOf(File file) async {
    final raf = await file.open();
    try {
      return BackupCrypto.detect(await raf.read(16));
    } finally {
      await raf.close();
    }
  }

  /// Remplace la base actuelle par [file]. [password] est exigé pour une
  /// sauvegarde chiffrée (lève [BackupWrongPassword] s'il est faux) ; une
  /// ancienne sauvegarde en clair reste restaurable sans mot de passe.
  static Future<void> restore(File file, {String? password}) async {
    final bytes = await file.readAsBytes();
    final Uint8List plain;
    switch (BackupCrypto.detect(bytes)) {
      case BackupKind.encrypted:
        if (password == null) throw const BackupWrongPassword();
        plain = await Isolate.run(() => BackupCrypto.decrypt(bytes, password));
      case BackupKind.legacyPlain:
        plain = bytes;
      case BackupKind.unknown:
        throw const BackupFormatException(
            "Ce fichier n'est pas une sauvegarde MoneyTracking");
    }
    if (!BackupCrypto.isSqlite(plain)) {
      throw const BackupFormatException('Sauvegarde endommagée');
    }

    await DatabaseHelper.instance.close();
    final destPath = await _dbPath();

    // Filet de sécurité : la base actuelle est conservée à côté.
    final current = File(destPath);
    if (await current.exists()) {
      await current.copy('$destPath.avant_restauration');
    }
    // Les fichiers WAL/SHM de l'ANCIENNE base seraient sinon rejoués sur la
    // base restaurée à la réouverture (données mélangées, voire corruption).
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final f = File('$destPath$suffix');
      if (await f.exists()) await f.delete();
    }
    await File(destPath).writeAsBytes(plain, flush: true);

    // Les curseurs de synchro patron se basent sur l'ordre d'insertion,
    // propre à chaque fichier de base : on repousse tout (idempotent).
    await SyncService.resetCursors();
  }

  static Future<void> _prune() async {
    final all = await list();
    for (final b in all.skip(keepLast)) {
      try {
        await b.file.delete();
      } catch (_) {}
    }
  }
}
