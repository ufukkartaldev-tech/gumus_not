import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connected_notebook/core/security/note_encryption_service.dart';

class InvalidBackupPasswordException implements Exception {
  final String message;
  const InvalidBackupPasswordException([
    this.message = 'Hatalı parola veya bozuk dosya. Güvenlik doğrulaması başarısız oldu.',
  ]);
  @override
  String toString() => message;
}

class CorruptedBackupException implements Exception {
  final String message;
  const CorruptedBackupException([
    this.message = 'Yedekleme dosyası bozuk veya geçersiz bir formatta.',
  ]);
  @override
  String toString() => message;
}

class EmptyBackupException implements Exception {
  final String message;
  const EmptyBackupException([
    this.message = 'Yedeklenecek not veya şablon bulunamadı.',
  ]);
  @override
  String toString() => message;
}

/// Zips, encrypts, and restores the `<documents>/GumusNot` markdown workspace
/// (notes/ + templates/). Employs AES-256-GCM authenticated encryption, PBKDF2
/// key derivation, path traversal defense, and automatic rollback on failure.
class MarkdownBackupUtils {
  MarkdownBackupUtils._();

  static const List<int> v2MagicHeader = [0x47, 0x4E, 0x43, 0x42, 0x02]; // "GNCB\x02"
  static const int saltLength = 16;
  static const int ivLength = 16;
  static const int v2HeaderTotalLength = 5 + 4 + saltLength + ivLength; // 41 bytes
  static const int defaultPbkdf2Iterations = 120000;

  static Future<Directory> _root() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString('custom_workspace_path');
      if (custom != null && custom.isNotEmpty) {
        return Directory(custom);
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'GumusNot'));
  }

  static bool _hasV2Header(List<int> bytes) {
    if (bytes.length < v2MagicHeader.length) return false;
    for (var i = 0; i < v2MagicHeader.length; i++) {
      if (bytes[i] != v2MagicHeader[i]) return false;
    }
    return true;
  }

  /// Single-pass SHA-256 for legacy v1 backup backward compatibility.
  static enc.Key _generateLegacyV1Key(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypts raw zip archive bytes using AES-256-GCM authenticated encryption
  /// and PBKDF2-HMAC-SHA256 key derivation with a cryptographically random salt and IV.
  static Uint8List encryptBackupPayload(
    List<int> zipBytes,
    String password, {
    int pbkdf2Iterations = defaultPbkdf2Iterations,
  }) {
    if (password.isEmpty) {
      throw ArgumentError('Yedekleme parolası boş olamaz.');
    }

    final salt = enc.IV.fromSecureRandom(saltLength).bytes;
    final iv = enc.IV.fromSecureRandom(ivLength);
    final keyBytes = NoteEncryptionService.pbkdf2Sha256(
      password: password,
      salt: salt,
      iterations: pbkdf2Iterations,
      keyLength: 32,
    );

    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm),
    );
    final encrypted = encrypter.encryptBytes(zipBytes, iv: iv);

    final iterBytes = ByteData(4)..setUint32(0, pbkdf2Iterations, Endian.big);

    final builder = BytesBuilder(copy: false)
      ..add(v2MagicHeader)
      ..add(iterBytes.buffer.asUint8List())
      ..add(salt)
      ..add(iv.bytes)
      ..add(encrypted.bytes);

    return builder.toBytes();
  }

  /// Decrypts an encrypted backup payload (v2 AES-256-GCM or transparent legacy v1).
  /// Throws [InvalidBackupPasswordException] if password or HMAC tag check fails.
  /// Throws [CorruptedBackupException] if the file format is malformed.
  static List<int> decryptBackupPayload(
    List<int> payloadBytes,
    String password,
  ) {
    if (password.isEmpty) {
      throw const InvalidBackupPasswordException('Yedekleme parolası boş olamaz.');
    }

    if (_hasV2Header(payloadBytes)) {
      if (payloadBytes.length <= v2HeaderTotalLength + 16) {
        throw const CorruptedBackupException('Yedek dosyası bozuk veya eksik (v2).');
      }

      final data = Uint8List.fromList(payloadBytes);
      final iterations =
          ByteData.sublistView(data, 5, 9).getUint32(0, Endian.big);
      if (iterations < 1000 || iterations > 5000000) {
        throw const CorruptedBackupException('Geçersiz PBKDF2 iterasyon sayısı.');
      }

      final salt = Uint8List.sublistView(data, 9, 9 + saltLength);
      final ivBytes = Uint8List.sublistView(
        data,
        9 + saltLength,
        9 + saltLength + ivLength,
      );
      final ciphertext = Uint8List.sublistView(data, v2HeaderTotalLength);

      final keyBytes = NoteEncryptionService.pbkdf2Sha256(
        password: password,
        salt: salt,
        iterations: iterations,
        keyLength: 32,
      );

      try {
        final encrypter = enc.Encrypter(
          enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm),
        );
        return encrypter.decryptBytes(
          enc.Encrypted(ciphertext),
          iv: enc.IV(ivBytes),
        );
      } catch (e) {
        throw const InvalidBackupPasswordException(
          'Hatalı parola veya bozuk dosya. Güvenlik doğrulaması başarısız oldu.',
        );
      }
    }

    // Legacy v1 fallback: [16-byte IV][AES-256 default SIC/CTR ciphertext]
    if (payloadBytes.length <= ivLength) {
      throw const CorruptedBackupException('Yedek dosyası bozuk.');
    }

    try {
      final key = _generateLegacyV1Key(password);
      final ivBytes = Uint8List.fromList(payloadBytes.sublist(0, ivLength));
      final encryptedBytes = Uint8List.fromList(payloadBytes.sublist(ivLength));

      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);
    } catch (_) {
      throw const InvalidBackupPasswordException(
        'Hatalı parola veya bozuk eski sürüm (v1) yedek dosyası.',
      );
    }
  }

  /// Returns zip bytes of the whole workspace, or null when the workspace
  /// does not exist yet. The optional [root] override exists for tests.
  static Future<List<int>?> zipWorkspace({Directory? root}) async {
    final dir = root ?? await _root();
    if (!dir.existsSync()) return null;

    final archive = Archive();
    var fileCount = 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative =
          p.relative(entity.path, from: dir.path).replaceAll('\\', '/');
      if (relative.startsWith('.git')) continue;
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
      fileCount++;
    }

    if (fileCount == 0) return null;
    return ZipEncoder().encode(archive);
  }

  /// Extracts a workspace zip into `<documents>/GumusNot` or [root].
  /// Protects against path traversal, absolute paths, and Windows drive colons.
  /// When [replaceExisting] is false, preserves existing conflicting files with suffix.
  static Future<int> extractWorkspace(
    Archive archive, {
    Directory? root,
    bool replaceExisting = false,
  }) async {
    final dir = root ?? await _root();
    if (!dir.existsSync()) dir.createSync(recursive: true);

    if (replaceExisting) {
      await _clearMarkdownFiles(dir);
    }

    var count = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');

      // Comprehensive Path Traversal Defense:
      // Reject relative traversal (..), absolute paths, and Windows drive colons (C:)
      if (name.startsWith('/') ||
          name.contains(':') ||
          p.isAbsolute(name) ||
          name.split('/').contains('..')) {
        continue;
      }
      if (name.split('/').first == '.git') continue;

      final target = File(p.join(dir.path, name));
      await target.parent.create(recursive: true);

      if (!replaceExisting && target.existsSync()) {
        final existingBytes = await target.readAsBytes();
        final newBytes = file.content as List<int>;
        if (!listEquals(existingBytes, newBytes)) {
          final ext = p.extension(name);
          final withoutExt = p.withoutExtension(name);
          final conflictTarget =
              File(p.join(dir.path, '$withoutExt (Yedekten)$ext'));
          await conflictTarget.writeAsBytes(newBytes, flush: true);
          count++;
          continue;
        }
      }

      await target.writeAsBytes(file.content as List<int>, flush: true);
      count++;
    }
    return count;
  }

  /// Deletes every markdown file under notes/ and templates/, leaving
  /// directories, dotfiles and anything else untouched.
  static Future<void> _clearMarkdownFiles(Directory root) async {
    for (final sub in ['notes', 'templates']) {
      final dir = Directory(p.join(root.path, sub));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.md')) {
          await entity.delete();
        }
      }
    }
  }

  /// Creates a temporary snapshot of current notes and templates
  /// to enable instantaneous rollback if restoration fails midway.
  static Future<Directory> _createSafetySnapshot(Directory dir) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final snapshotDir = Directory(
      p.join(tempDir.path, 'gn_restore_snap_${DateTime.now().millisecondsSinceEpoch}'),
    );
    if (snapshotDir.existsSync()) snapshotDir.deleteSync(recursive: true);
    snapshotDir.createSync(recursive: true);

    for (final sub in ['notes', 'templates']) {
      final srcSub = Directory(p.join(dir.path, sub));
      if (!srcSub.existsSync()) continue;
      final dstSub = Directory(p.join(snapshotDir.path, sub));
      dstSub.createSync(recursive: true);
      for (final entity in srcSub.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: srcSub.path);
          final dstFile = File(p.join(dstSub.path, rel));
          dstFile.parent.createSync(recursive: true);
          entity.copySync(dstFile.path);
        }
      }
    }
    return snapshotDir;
  }

  /// Restores the original workspace files from the safety snapshot.
  static Future<void> _rollbackFromSafetySnapshot(
    Directory snapshotDir,
    Directory targetDir,
  ) async {
    try {
      await _clearMarkdownFiles(targetDir);
      for (final sub in ['notes', 'templates']) {
        final srcSub = Directory(p.join(snapshotDir.path, sub));
        if (!srcSub.existsSync()) continue;
        final dstSub = Directory(p.join(targetDir.path, sub));
        dstSub.createSync(recursive: true);
        for (final entity in srcSub.listSync(recursive: true, followLinks: false)) {
          if (entity is File) {
            final rel = p.relative(entity.path, from: srcSub.path);
            final dstFile = File(p.join(dstSub.path, rel));
            dstFile.parent.createSync(recursive: true);
            entity.copySync(dstFile.path);
          }
        }
      }
    } catch (e) {
      debugPrint('Rollback error: $e');
    }
  }

  /// Creates a local encrypted backup payload (.enc) of the workspace.
  static Future<Uint8List?> createEncryptedBackup({
    required String password,
    int? pbkdf2Iterations,
    Directory? root,
  }) async {
    final zipBytes = await zipWorkspace(root: root);
    if (zipBytes == null || zipBytes.isEmpty) {
      throw const EmptyBackupException('Yedeklenecek not veya şablon bulunamadı.');
    }
    return encryptBackupPayload(
      zipBytes,
      password,
      pbkdf2Iterations: pbkdf2Iterations ?? defaultPbkdf2Iterations,
    );
  }

  /// Restores workspace from an encrypted backup payload (.enc).
  /// Employs automatic safety snapshotting and rollback on failure.
  static Future<int> restoreEncryptedBackup(
    List<int> encBytes,
    String password, {
    Directory? root,
    bool replaceExisting = false,
  }) async {
    final zipBytes = decryptBackupPayload(encBytes, password);
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final targetDir = root ?? await _root();

    final snapshotDir = await _createSafetySnapshot(targetDir);
    try {
      final count = await extractWorkspace(
        archive,
        root: targetDir,
        replaceExisting: replaceExisting,
      );
      if (snapshotDir.existsSync()) {
        snapshotDir.deleteSync(recursive: true);
      }
      return count;
    } catch (e) {
      await _rollbackFromSafetySnapshot(snapshotDir, targetDir);
      if (snapshotDir.existsSync()) {
        snapshotDir.deleteSync(recursive: true);
      }
      rethrow;
    }
  }

  /// Creates an unencrypted portable zip archive of the workspace.
  static Future<List<int>?> createZipBackup({Directory? root}) async {
    final zipBytes = await zipWorkspace(root: root);
    if (zipBytes == null || zipBytes.isEmpty) {
      throw const EmptyBackupException('Yedeklenecek not veya şablon bulunamadı.');
    }
    return zipBytes;
  }

  /// Restores workspace from an unencrypted zip archive.
  /// Employs automatic safety snapshotting and rollback on failure.
  static Future<int> restoreZipBackup(
    List<int> zipBytes, {
    Directory? root,
    bool replaceExisting = false,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final targetDir = root ?? await _root();

    final snapshotDir = await _createSafetySnapshot(targetDir);
    try {
      final count = await extractWorkspace(
        archive,
        root: targetDir,
        replaceExisting: replaceExisting,
      );
      if (snapshotDir.existsSync()) {
        snapshotDir.deleteSync(recursive: true);
      }
      return count;
    } catch (e) {
      await _rollbackFromSafetySnapshot(snapshotDir, targetDir);
      if (snapshotDir.existsSync()) {
        snapshotDir.deleteSync(recursive: true);
      }
      rethrow;
    }
  }
}
