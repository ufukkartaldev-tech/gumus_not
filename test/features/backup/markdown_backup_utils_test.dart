import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/backup/services/cloud_sync_service.dart';
import 'package:connected_notebook/features/backup/services/markdown_backup_utils.dart';

void main() {
  late Directory sourceDir;
  late Directory restoreDir;

  setUp(() async {
    sourceDir = await Directory.systemTemp.createTemp('gumusnot_backup_src');
    restoreDir = await Directory.systemTemp.createTemp('gumusnot_backup_dst');
  });

  tearDown(() async {
    if (sourceDir.existsSync()) await sourceDir.delete(recursive: true);
    if (restoreDir.existsSync()) await restoreDir.delete(recursive: true);
  });

  Future<Archive> zipOfAsync(Directory dir) async {
    final bytes = await MarkdownBackupUtils.zipWorkspace(root: dir);
    return ZipDecoder().decodeBytes(bytes!);
  }

  group('CloudSyncService v2 Cryptography (PBKDF2-HMAC-SHA256 + AES-256-GCM)', () {
    // Use 2,000 iterations in unit tests for fast execution while verifying KDF header encoding
    final syncService = CloudSyncService(pbkdf2Iterations: 2000);
    final samplePlaintext = utf8.encode('Gizli yedek zip verisi 1234567890');

    test('v2 encrypt and decrypt round-trip succeeds and embeds GNCB\\x02 header', () {
      final payload = syncService.encryptBackupPayload(samplePlaintext, 'GucluParola!2026');

      // Verify GNCB\x02 magic header
      expect(payload.sublist(0, 5), equals([0x47, 0x4E, 0x43, 0x42, 0x02]));

      final decrypted = syncService.decryptBackupPayload(payload, 'GucluParola!2026');
      expect(decrypted, equals(samplePlaintext));
    });

    test('encrypting identical data with same password twice produces distinct ciphertexts (random salt + IV)', () {
      final p1 = syncService.encryptBackupPayload(samplePlaintext, 'AyniParola');
      final p2 = syncService.encryptBackupPayload(samplePlaintext, 'AyniParola');

      // Salt (bytes 9..25) and IV (bytes 25..41) must differ
      expect(p1.sublist(9, 25), isNot(equals(p2.sublist(9, 25))));
      expect(p1.sublist(25, 41), isNot(equals(p2.sublist(25, 41))));
      expect(p1.sublist(41), isNot(equals(p2.sublist(41))));
    });

    test('wrong password or tampered ciphertext throws on AES-256-GCM MAC verification', () {
      final payload = syncService.encryptBackupPayload(samplePlaintext, 'DogruParola');

      expect(
        () => syncService.decryptBackupPayload(payload, 'YanlisParola'),
        throwsA(anything),
      );

      // Flip a single bit in the ciphertext/tag region
      final tampered = List<int>.from(payload);
      tampered[tampered.length - 1] ^= 0x01;

      expect(
        () => syncService.decryptBackupPayload(tampered, 'DogruParola'),
        throwsA(anything),
      );
    });

    test('transparently decrypts legacy v1 backups (SHA-256 + AES-SIC) for backward compatibility', () {
      final legacyPayload = CloudSyncService.createLegacyV1PayloadForTest(
        samplePlaintext,
        'EskiYedekParolasi',
      );

      final decrypted = syncService.decryptBackupPayload(
        legacyPayload,
        'EskiYedekParolasi',
      );
      expect(decrypted, equals(samplePlaintext));
    });
  });

  group('MarkdownBackupUtils', () {
    test('zipWorkspace returns null when workspace does not exist', () async {
      final missing = Directory(
        '${sourceDir.parent.path}/does_not_exist_${DateTime.now().millisecondsSinceEpoch}',
      );
      expect(await MarkdownBackupUtils.zipWorkspace(root: missing), isNull);
    });

    test('zips notes and templates but excludes .git internals', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      Directory('${sourceDir.path}/templates').createSync(recursive: true);
      Directory('${sourceDir.path}/.git').createSync(recursive: true);
      File('${sourceDir.path}/notes/1.md').writeAsStringSync('---\ntitle: a\n---\nbody');
      File('${sourceDir.path}/templates/9.md').writeAsStringSync('---\nname: t\n---\nbody');
      File('${sourceDir.path}/.git/config').writeAsStringSync('should-not-leak');

      final archive = await zipOfAsync(sourceDir);
      final names = archive.map((f) => f.name).toSet();

      expect(names, contains('notes/1.md'));
      expect(names, contains('templates/9.md'));
      expect(names.any((n) => n.startsWith('.git')), isFalse);
    });

    test('non-destructive extract merges backup into existing files', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      File('${sourceDir.path}/notes/1.md').writeAsStringSync('from backup');

      Directory('${restoreDir.path}/notes').createSync(recursive: true);
      File('${restoreDir.path}/notes/2.md').writeAsStringSync('device only');

      final count = await MarkdownBackupUtils.extractWorkspace(
        await zipOfAsync(sourceDir),
        root: restoreDir,
      );

      expect(count, 1);
      expect(File('${restoreDir.path}/notes/1.md').readAsStringSync(), 'from backup');
      expect(File('${restoreDir.path}/notes/2.md').existsSync(), isTrue);
    });

    test('replaceExisting restore removes device files missing from backup', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      File('${sourceDir.path}/notes/1.md').writeAsStringSync('from backup');

      Directory('${restoreDir.path}/notes').createSync(recursive: true);
      Directory('${restoreDir.path}/templates').createSync(recursive: true);
      File('${restoreDir.path}/notes/2.md').writeAsStringSync('stale note');
      File('${restoreDir.path}/templates/7.md').writeAsStringSync('stale template');
      File('${restoreDir.path}/templates/.seeded').writeAsStringSync('seeded');
      File('${restoreDir.path}/.migrated_from_sqlite').writeAsStringSync('done');

      final count = await MarkdownBackupUtils.extractWorkspace(
        await zipOfAsync(sourceDir),
        root: restoreDir,
        replaceExisting: true,
      );

      expect(count, 1);
      expect(File('${restoreDir.path}/notes/1.md').readAsStringSync(), 'from backup');
      expect(File('${restoreDir.path}/notes/2.md').existsSync(), isFalse);
      expect(File('${restoreDir.path}/templates/7.md').existsSync(), isFalse);
      // Markers survive so seeding/migration never re-trigger after restore.
      expect(File('${restoreDir.path}/templates/.seeded').existsSync(), isTrue);
      expect(File('${restoreDir.path}/.migrated_from_sqlite').existsSync(), isTrue);
    });

    test('extract rejects path traversal entries', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('../../evil.md', 4, 'evil'.codeUnits))
        ..addFile(ArchiveFile('notes/ok.md', 2, 'ok'.codeUnits));

      final count = await MarkdownBackupUtils.extractWorkspace(
        archive,
        root: restoreDir,
      );

      expect(count, 1);
      expect(File('${restoreDir.path}/notes/ok.md').existsSync(), isTrue);
      expect(
        File('${restoreDir.parent.path}/evil.md').existsSync(),
        isFalse,
      );
    });
  });
}
