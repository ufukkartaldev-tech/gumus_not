import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/backup/services/markdown_backup_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  group('MarkdownBackupUtils v2 Cryptography (AES-256-GCM + PBKDF2-HMAC-SHA256)', () {
    const testIterations = 2000;
    final samplePlaintext = utf8.encode('Gizli yedek zip verisi 1234567890');

    test('v2 encrypt and decrypt round-trip succeeds and embeds GNCB\\x02 header', () {
      final payload = MarkdownBackupUtils.encryptBackupPayload(
        samplePlaintext,
        'GucluParola!2026',
        pbkdf2Iterations: testIterations,
      );

      // Verify GNCB\x02 magic header
      expect(payload.sublist(0, 5), equals([0x47, 0x4E, 0x43, 0x42, 0x02]));

      final decrypted = MarkdownBackupUtils.decryptBackupPayload(
        payload,
        'GucluParola!2026',
      );
      expect(decrypted, equals(samplePlaintext));
    });

    test('encrypting identical data twice produces distinct ciphertexts (random salt + IV)', () {
      final p1 = MarkdownBackupUtils.encryptBackupPayload(
        samplePlaintext,
        'AyniParola',
        pbkdf2Iterations: testIterations,
      );
      final p2 = MarkdownBackupUtils.encryptBackupPayload(
        samplePlaintext,
        'AyniParola',
        pbkdf2Iterations: testIterations,
      );

      // Salt (bytes 9..25) and IV (bytes 25..41) must differ
      expect(p1.sublist(9, 25), isNot(equals(p2.sublist(9, 25))));
      expect(p1.sublist(25, 41), isNot(equals(p2.sublist(25, 41))));
      expect(p1.sublist(41), isNot(equals(p2.sublist(41))));
    });

    test('wrong password throws InvalidBackupPasswordException', () {
      final payload = MarkdownBackupUtils.encryptBackupPayload(
        samplePlaintext,
        'DogruParola',
        pbkdf2Iterations: testIterations,
      );

      expect(
        () => MarkdownBackupUtils.decryptBackupPayload(payload, 'YanlisParola'),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('tampered ciphertext throws InvalidBackupPasswordException on MAC verification failure', () {
      final payload = MarkdownBackupUtils.encryptBackupPayload(
        samplePlaintext,
        'DogruParola',
        pbkdf2Iterations: testIterations,
      );

      // Tamper single bit in ciphertext
      final tampered = List<int>.from(payload);
      tampered[tampered.length - 1] ^= 0x01;

      expect(
        () => MarkdownBackupUtils.decryptBackupPayload(tampered, 'DogruParola'),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('corrupted short payload throws CorruptedBackupException', () {
      final corruptedShort = [0x47, 0x4E, 0x43, 0x42, 0x02, 0x00, 0x01];
      expect(
        () => MarkdownBackupUtils.decryptBackupPayload(corruptedShort, 'Parola'),
        throwsA(isA<CorruptedBackupException>()),
      );
    });
  });

  group('Local Encrypted Backup (.enc) End-to-End Tests', () {
    test('createEncryptedBackup and restoreEncryptedBackup roundtrips all notes cleanly', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      Directory('${sourceDir.path}/templates').createSync(recursive: true);
      File('${sourceDir.path}/notes/proje.md').writeAsStringSync('---\ntitle: Proje\n---\nÖnemli içerik');
      File('${sourceDir.path}/templates/sablon.md').writeAsStringSync('---\nname: Toplantı\n---\nŞablon metni');

      final encBytes = await MarkdownBackupUtils.createEncryptedBackup(
        password: 'GizliParola123',
        pbkdf2Iterations: 2000,
        root: sourceDir,
      );

      expect(encBytes, isNotNull);
      expect(encBytes!.sublist(0, 5), equals([0x47, 0x4E, 0x43, 0x42, 0x02]));

      final count = await MarkdownBackupUtils.restoreEncryptedBackup(
        encBytes,
        'GizliParola123',
        root: restoreDir,
        replaceExisting: true,
      );

      expect(count, 2);
      expect(File('${restoreDir.path}/notes/proje.md').readAsStringSync(), contains('Önemli içerik'));
      expect(File('${restoreDir.path}/templates/sablon.md').readAsStringSync(), contains('Şablon metni'));
    });

    test('restoreEncryptedBackup with wrong password preserves existing notes intact', () async {
      Directory('${restoreDir.path}/notes').createSync(recursive: true);
      final existingFile = File('${restoreDir.path}/notes/mevcut.md');
      existingFile.writeAsStringSync('Orijinal Mevcut Not');

      // Valid backup payload
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      File('${sourceDir.path}/notes/yeni.md').writeAsStringSync('Yedekten Gelecek');
      final encBytes = await MarkdownBackupUtils.createEncryptedBackup(
        password: 'DogruParola',
        pbkdf2Iterations: 2000,
        root: sourceDir,
      );

      // Attempt restore with wrong password
      expect(
        () => MarkdownBackupUtils.restoreEncryptedBackup(
          encBytes!,
          'YanlisParola',
          root: restoreDir,
          replaceExisting: true,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );

      // Existing notes must NOT be deleted or modified
      expect(existingFile.existsSync(), isTrue);
      expect(existingFile.readAsStringSync(), 'Orijinal Mevcut Not');
      expect(File('${restoreDir.path}/notes/yeni.md').existsSync(), isFalse);
    });

    test('empty workspace throws EmptyBackupException on backup attempt', () async {
      expect(
        () => MarkdownBackupUtils.createEncryptedBackup(
          password: 'Parola',
          root: sourceDir,
        ),
        throwsA(isA<EmptyBackupException>()),
      );
    });
  });

  group('Portable ZIP Archive Backup & Restore Tests', () {
    test('createZipBackup and restoreZipBackup roundtrip workspace successfully', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      File('${sourceDir.path}/notes/fikir.md').writeAsStringSync('---\ntitle: Fikir\n---\nİçerik metni');

      final zipBytes = await MarkdownBackupUtils.createZipBackup(root: sourceDir);
      expect(zipBytes, isNotNull);

      final count = await MarkdownBackupUtils.restoreZipBackup(
        zipBytes!,
        root: restoreDir,
        replaceExisting: true,
      );

      expect(count, 1);
      expect(File('${restoreDir.path}/notes/fikir.md').readAsStringSync(), contains('İçerik metni'));
    });

    test('corrupted zip bytes throw exception and leave target files untouched', () async {
      Directory('${restoreDir.path}/notes').createSync(recursive: true);
      final existingNote = File('${restoreDir.path}/notes/kalici.md');
      existingNote.writeAsStringSync('Dokunulmamasi Gereken Not');

      final corruptedBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x99, 0x88, 0x77]);

      expect(
        () => MarkdownBackupUtils.restoreZipBackup(
          corruptedBytes,
          root: restoreDir,
          replaceExisting: true,
        ),
        throwsA(anything),
      );

      expect(existingNote.existsSync(), isTrue);
      expect(existingNote.readAsStringSync(), 'Dokunulmamasi Gereken Not');
    });
  });

  group('Path Traversal & Security Defenses', () {
    test('extractWorkspace rejects relative traversal, absolute paths, and Windows drive colons', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('../../evil_parent.md', 4, 'evil'.codeUnits))
        ..addFile(ArchiveFile('/root_evil.md', 4, 'evil'.codeUnits))
        ..addFile(ArchiveFile('C:/Windows/System32/evil.dll', 4, 'evil'.codeUnits))
        ..addFile(ArchiveFile('notes/../secret.md', 6, 'secret'.codeUnits))
        ..addFile(ArchiveFile('.git/config', 6, 'gitcfg'.codeUnits))
        ..addFile(ArchiveFile('notes/guvenli.md', 7, 'guvenli'.codeUnits));

      final count = await MarkdownBackupUtils.extractWorkspace(
        archive,
        root: restoreDir,
      );

      expect(count, 1);
      expect(File('${restoreDir.path}/notes/guvenli.md').existsSync(), isTrue);
      expect(File('${restoreDir.path}/notes/guvenli.md').readAsStringSync(), 'guvenli');

      // None of the traversal attempts must exist
      expect(File('${restoreDir.parent.path}/evil_parent.md').existsSync(), isFalse);
      expect(File('${restoreDir.path}/root_evil.md').existsSync(), isFalse);
      expect(File('${restoreDir.path}/.git/config').existsSync(), isFalse);
    });
  });

  group('File Conflict & Merge Behavior', () {
    test('non-destructive restore creates conflict copy when existing file has differing content', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      File('${sourceDir.path}/notes/gunluk.md').writeAsStringSync('Yedekten gelen sürüm');

      Directory('${restoreDir.path}/notes').createSync(recursive: true);
      File('${restoreDir.path}/notes/gunluk.md').writeAsStringSync('Cihazdaki mevcut yerel sürüm');

      final zipBytes = await MarkdownBackupUtils.createZipBackup(root: sourceDir);
      final count = await MarkdownBackupUtils.restoreZipBackup(
        zipBytes!,
        root: restoreDir,
        replaceExisting: false,
      );

      expect(count, 1);
      // Original local note is preserved
      expect(
        File('${restoreDir.path}/notes/gunluk.md').readAsStringSync(),
        'Cihazdaki mevcut yerel sürüm',
      );
      // Conflicting backup copy is saved alongside with suffix
      final conflictFile = File('${restoreDir.path}/notes/gunluk (Yedekten).md');
      expect(conflictFile.existsSync(), isTrue);
      expect(conflictFile.readAsStringSync(), 'Yedekten gelen sürüm');
    });

    test('non-destructive restore does not duplicate file when content is identical', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      File('${sourceDir.path}/notes/ayni.md').writeAsStringSync('Birebir ayni icerik');

      Directory('${restoreDir.path}/notes').createSync(recursive: true);
      File('${restoreDir.path}/notes/ayni.md').writeAsStringSync('Birebir ayni icerik');

      final zipBytes = await MarkdownBackupUtils.createZipBackup(root: sourceDir);
      await MarkdownBackupUtils.restoreZipBackup(
        zipBytes!,
        root: restoreDir,
        replaceExisting: false,
      );

      expect(
        File('${restoreDir.path}/notes/ayni (Yedekten).md').existsSync(),
        isFalse,
      );
    });
  });

  group('Large Collection Stress & Missing Metadata Resilience', () {
    test('handles 120 notes with mixed metadata without memory failure or data corruption', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      for (int i = 1; i <= 120; i++) {
        // Varying metadata: some with full frontmatter, some raw markdown, some empty
        final content = i % 3 == 0
            ? '# Not $i\nRaw markdown without YAML frontmatter.'
            : '---\nid: $i\ntitle: Not $i\ntags: [stres, buyuk]\n---\nİçerik $i: ${'A' * 200}';
        File('${sourceDir.path}/notes/not_$i.md').writeAsStringSync(content);
      }

      final encBytes = await MarkdownBackupUtils.createEncryptedBackup(
        password: 'BuyukKoleksiyonParolasi!',
        pbkdf2Iterations: 2000,
        root: sourceDir,
      );

      expect(encBytes, isNotNull);
      expect(encBytes!.length, greaterThan(1000));

      final restoredCount = await MarkdownBackupUtils.restoreEncryptedBackup(
        encBytes,
        'BuyukKoleksiyonParolasi!',
        root: restoreDir,
        replaceExisting: true,
      );

      expect(restoredCount, 120);
      expect(
        File('${restoreDir.path}/notes/not_50.md').existsSync(),
        isTrue,
      );
      expect(
        File('${restoreDir.path}/notes/not_3.md').readAsStringSync(),
        contains('Raw markdown without YAML frontmatter.'),
      );
    });
  });
}
