import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connected_notebook/core/security/legacy/legacy_encryption_service.dart';

/// Migration service for encryption format upgrades
class EncryptionMigrationService {
  static const int _legacyFormatVersion = 1;
  static const int _currentFormatVersion = 2;

  /// Check if encrypted package is in legacy format
  static bool isLegacyFormat(String encryptedPackage) {
    if (encryptedPackage.isEmpty) return false;

    try {
      final parts = encryptedPackage.split(':');

      // Legacy format: iv:encrypted (2 parts)
      // Current format: version:iv:encrypted (3 parts)
      if (parts.length == 2) {
        return true; // Legacy format
      } else if (parts.length == 3 && parts[0] == '1') {
        return true; // Version 1 format
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Migrate legacy encrypted data to new format
  static String migrateToVersion2({
    required String legacyEncryptedPackage,
    required Uint8List masterKey,
  }) {
    if (!isLegacyFormat(legacyEncryptedPackage)) {
      return legacyEncryptedPackage; // Already in new format
    }

    try {
      final parts = legacyEncryptedPackage.split(':');
      IV iv;
      Encrypted encrypted;

      if (parts.length == 2) {
        // Legacy format: iv:encrypted
        iv = IV.fromBase64(parts[0]);
        encrypted = Encrypted.fromBase64(parts[1]);
      } else if (parts.length == 3 && parts[0] == '1') {
        // Version 1 format: version:iv:encrypted
        iv = IV.fromBase64(parts[1]);
        encrypted = Encrypted.fromBase64(parts[2]);
      } else {
        throw Exception('Invalid legacy format');
      }

      // Decrypt with old format
      final encrypter = Encrypter(AES(Key(masterKey)));
      final plainText = encrypter.decrypt(encrypted, iv: iv);

      // Re-encrypt with new format
      final newIv = SecureMemory.generateIV();
      final newEncrypted = encrypter.encrypt(plainText, iv: newIv);

      // Return in new format: version:iv:encrypted
      return '$_currentFormatVersion:${newIv.base64}:${newEncrypted.base64}';
    } catch (e) {
      throw Exception('Migration failed: $e');
    }
  }

  /// Migrate password-encrypted data to new format
  static String migratePasswordEncryptedToVersion2({
    required String legacyEncryptedPackage,
    required String password,
  }) {
    try {
      final parts = legacyEncryptedPackage.split(':');

      if (parts.length == 2) {
        // Legacy password format: iv:encrypted (no salt)
        final iv = IV.fromBase64(parts[0]);
        final encrypted = Encrypted.fromBase64(parts[1]);

        // Derive key from password without salt (legacy behavior)
        final passwordBytes = utf8.encode(password);
        final derivedKey = sha256.convert(passwordBytes).bytes;

        // Decrypt
        final encrypter = Encrypter(AES(Key(Uint8List.fromList(derivedKey))));
        final plainText = encrypter.decrypt(encrypted, iv: iv);

        // Re-encrypt with new format (with salt)
        return EnhancedEncryptionService.instance.encryptWithPassword(
          plainText: plainText,
          password: password,
        );
      }

      return legacyEncryptedPackage; // Already in new format
    } catch (e) {
      throw Exception('Password migration failed: $e');
    }
  }

  /// Batch migrate all encrypted notes in database
  static Future<Map<String, dynamic>> migrateDatabaseNotes({
    required Database database,
    required Uint8List masterKey,
  }) async {
    final stopwatch = Stopwatch()..start();
    final migrationStats = {
      'totalNotes': 0,
      'migratedNotes': 0,
      'failedNotes': 0,
      'durationMs': 0,
    };

    try {
      // Get all notes
      final List<Map<String, dynamic>> notes = await database.query('notes');
      migrationStats['totalNotes'] = notes.length;

      // Process each note
      for (final note in notes) {
        try {
          final content = note['content'] as String? ?? '';
          final isEncrypted = note['is_encrypted'] as int? ?? 0;

          if (isEncrypted == 1 && content.isNotEmpty) {
            if (isLegacyFormat(content)) {
              // Migrate encrypted content
              final migratedContent = migrateToVersion2(
                legacyEncryptedPackage: content,
                masterKey: masterKey,
              );

              // Update note
              await database.update(
                'notes',
                {'content': migratedContent},
                where: 'id = ?',
                whereArgs: [note['id']],
              );

              migrationStats['migratedNotes'] = (migrationStats['migratedNotes'] as int) + 1;
            }
          }
        } catch (e) {
          print('Failed to migrate note ${note['id']}: $e');
          migrationStats['failedNotes'] = (migrationStats['failedNotes'] as int) + 1;
        }
      }

      stopwatch.stop();
      migrationStats['durationMs'] = stopwatch.elapsedMilliseconds;

      return migrationStats;
    } catch (e) {
      stopwatch.stop();
      migrationStats['durationMs'] = stopwatch.elapsedMilliseconds;
      throw Exception('Database migration failed: $e');
    }
  }

  /// Validate migration integrity
  static Future<bool> validateMigration({
    required Database database,
    required Uint8List masterKey,
  }) async {
    try {
      // Get a sample of notes
      final List<Map<String, dynamic>> notes = await database.query(
        'notes',
        limit: 10,
        where: 'is_encrypted = 1',
      );

      for (final note in notes) {
        final content = note['content'] as String? ?? '';

        if (content.isNotEmpty) {
          // Check format
          final parts = content.split(':');
          if (parts.length != 3 || parts[0] != '2') {
            return false; // Not in new format
          }

          // Try to decrypt to ensure it works
          try {
            final iv = IV.fromBase64(parts[1]);
            final encrypted = Encrypted.fromBase64(parts[2]);
            final encrypter = Encrypter(AES(Key(masterKey)));
            encrypter.decrypt(encrypted, iv: iv);
          } catch (e) {
            return false; // Decryption failed
          }
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create migration report
  static Future<Map<String, dynamic>> createMigrationReport({
    required Database database,
  }) async {
    final report = {
      'totalNotes': 0,
      'encryptedNotes': 0,
      'legacyFormatNotes': 0,
      'currentFormatNotes': 0,
      'migrationRequired': false,
    };

    try {
      final List<Map<String, dynamic>> notes = await database.query('notes');
      report['totalNotes'] = notes.length;

      for (final note in notes) {
        final content = note['content'] as String? ?? '';
        final isEncrypted = note['is_encrypted'] as int? ?? 0;

        if (isEncrypted == 1 && content.isNotEmpty) {
          report['encryptedNotes'] = (report['encryptedNotes'] as int) + 1;

          if (isLegacyFormat(content)) {
            report['legacyFormatNotes'] = (report['legacyFormatNotes'] as int) + 1;
          } else {
            report['currentFormatNotes'] = (report['currentFormatNotes'] as int) + 1;
          }
        }
      }

      report['migrationRequired'] = (report['legacyFormatNotes'] as int) > 0;

      return report;
    } catch (e) {
      throw Exception('Failed to create migration report: $e');
    }
  }
}
