import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';

import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/features/backup/services/markdown_backup_utils.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Manages encrypted cloud backups on Google Drive (`appDataFolder`).
///
/// ### Binary Payload Format v2 (`GNCB\x02`):
/// - Bytes `0..4`: Magic header `[0x47, 0x4E, 0x43, 0x42, 0x02]` (`"GNCB\x02"`)
/// - Bytes `5..8`: Big-endian `uint32` PBKDF2 iteration count (default `120,000`)
/// - Bytes `9..24`: 16-byte cryptographically random PBKDF2 salt
/// - Bytes `25..40`: 16-byte cryptographically random AES-GCM IV (nonce)
/// - Bytes `41..N`: AES-256-GCM ciphertext + 128-bit authentication tag (MAC)
///
/// ### Legacy Compatibility (v1):
/// Payloads without the `GNCB\x02` header fall back to the legacy v1 format
/// (`[16-byte IV][AES-256-SIC ciphertext]` keyed by single-pass `SHA-256(password)`)
/// so existing user backups on Google Drive remain restorable.
class CloudSyncService {
  static const String _backupFileName = 'gumusnot_secure_backup.enc';
  static const List<int> _v2MagicHeader = [0x47, 0x4E, 0x43, 0x42, 0x02]; // "GNCB\x02"
  static const int _saltLength = 16;
  static const int _ivLength = 16;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final int pbkdf2Iterations;

  CloudSyncService({
    this.pbkdf2Iterations = NoteEncryptionService.defaultPbkdf2Iterations,
  });

  /// Legacy v1 key derivation (single-pass SHA-256 without salt) kept strictly
  /// for backward-compatible restoration of older v1 backups.
  static enc.Key _generateLegacyV1Key(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypts [zipBytes] using **PBKDF2-HMAC-SHA256** key derivation with a
  /// fresh 128-bit random salt and **AES-256-GCM** authenticated encryption.
  @visibleForTesting
  Uint8List encryptBackupPayload(List<int> zipBytes, String password) {
    return MarkdownBackupUtils.encryptBackupPayload(
      zipBytes,
      password,
      pbkdf2Iterations: pbkdf2Iterations,
    );
  }

  /// Decrypts [payloadBytes] produced by [encryptBackupPayload] (v2 AES-256-GCM
  /// + PBKDF2-HMAC-SHA256), or transparently falls back to legacy v1 decryption
  /// if the payload does not start with the v2 magic header.
  @visibleForTesting
  List<int> decryptBackupPayload(List<int> payloadBytes, String password) {
    return MarkdownBackupUtils.decryptBackupPayload(payloadBytes, password);
  }

  /// Helper for testing legacy v1 payload creation.
  @visibleForTesting
  static Uint8List createLegacyV1PayloadForTest(List<int> zipBytes, String password) {
    final key = _generateLegacyV1Key(password);
    final iv = enc.IV.fromSecureRandom(_ivLength);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encryptBytes(zipBytes, iv: iv);
    return Uint8List.fromList(<int>[...iv.bytes, ...encrypted.bytes]);
  }

  /// Google ile giriş yapıp yetkilendirilmiş Drive API istemcisi döner
  Future<(drive.DriveApi, GoogleAuthClient)?> _getDriveApi() async {
    const scopes = <String>[drive.DriveApi.driveAppdataScope];
    try {
      await _googleSignIn.initialize();

      // Sessiz giriş dene; olmazsa etkileşimli giriş iste (iptal → istisna).
      var account = await _googleSignIn.attemptLightweightAuthentication();
      account ??= await _googleSignIn.authenticate(scopeHint: scopes);

      final authHeaders = await account.authorizationClient
          .authorizationHeaders(scopes, promptIfNecessary: true);
      if (authHeaders == null) return null;

      final authenticateClient = GoogleAuthClient(authHeaders);
      return (drive.DriveApi(authenticateClient), authenticateClient);
    } catch (e) {
      debugPrint('Google Sign-In Hatası: $e');
      return null;
    }
  }

  /// Çalışma alanını kilitli ZIP'e çevirir (PBKDF2-HMAC-SHA256 + AES-256-GCM) ve Drive'a yükler
  Future<Map<String, dynamic>> backupToDrive(String password) async {
    if (kIsWeb) return {'success': false, 'message': 'Web sürümü desteklenmiyor.'};

    GoogleAuthClient? authClient;
    try {
      final apiBundle = await _getDriveApi();
      if (apiBundle == null) {
        return {'success': false, 'message': 'Google girişi yapılamadı veya iptal edildi.'};
      }
      final (driveApi, client) = apiBundle;
      authClient = client;

      // 1. Markdown çalışma alanını (notlar + şablonlar) zip'le
      final zipBytes = await MarkdownBackupUtils.zipWorkspace();
      if (zipBytes == null || zipBytes.isEmpty) {
        return {'success': false, 'message': 'Yedeklenecek markdown dosyası bulunamadı.'};
      }

      // 2. Şifrele (v2: PBKDF2-HMAC-SHA256 + 16B Salt + 16B IV + AES-256-GCM)
      final finalBytes = encryptBackupPayload(zipBytes, password);

      // 3. Drive'a Yükle (appDataFolder -> Kullanıcı bu klasörü göremez, çok güvenlidir)
      final media = drive.Media(Stream.value(finalBytes), finalBytes.length);
      final driveFile = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];

      // Eski yedeği bul ve güncelle (Eğer yoksa yeni oluştur)
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name='$_backupFileName'",
      );
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(drive.File(), existingFileId, uploadMedia: media);
      } else {
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      return {'success': true, 'message': 'Yedek başarıyla şifrelenip buluta yüklendi! 🔒'};
    } catch (e) {
      debugPrint('Bulut yedekleme hatası: $e');
      return {'success': false, 'message': 'Yedekleme başarısız: $e'};
    } finally {
      authClient?.close();
    }
  }

  /// Drive'dan şifreli yedeği indirir, parolayı çözer (v2 GCM veya v1 Legacy) ve geri yükler
  Future<Map<String, dynamic>> restoreFromDrive(String password) async {
    if (kIsWeb) return {'success': false, 'message': 'Web sürümü desteklenmiyor.'};

    GoogleAuthClient? authClient;
    try {
      final apiBundle = await _getDriveApi();
      if (apiBundle == null) {
        return {'success': false, 'message': 'Google girişi yapılamadı.'};
      }
      final (driveApi, client) = apiBundle;
      authClient = client;

      // 1. Dosyayı Bul
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name='$_backupFileName'",
      );
      if (fileList.files == null || fileList.files!.isEmpty) {
        return {'success': false, 'message': 'Bulutta size ait bir yedek bulunamadı.'};
      }

      final fileId = fileList.files!.first.id!;

      // 2. Dosyayı İndir
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      if (bytes.length <= _ivLength) {
        return {'success': false, 'message': 'Yedek dosyası bozuk.'};
      }

      // 3. Şifreyi Çöz (v2 AES-256-GCM + PBKDF2 veya v1 Legacy fallback)
      List<int> decryptedZipBytes;
      try {
        decryptedZipBytes = decryptBackupPayload(bytes, password);
      } on FormatException catch (e) {
        return {'success': false, 'message': e.message};
      } catch (e) {
        // Parola yanlışsa (GCM MAC hatası) veya bozuksa hata fırlatır
        return {'success': false, 'message': 'Parola yanlış! Yedeğiniz açılamadı. ❌'};
      }

      // 4. Zip'i aç ve markdown dosyalarını yedekteki haliyle değiştir
      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(decryptedZipBytes);
      } catch (_) {
        return {'success': false, 'message': 'Parola yanlış veya yedek arşivi bozuk! ❌'};
      }

      final restoredCount = await MarkdownBackupUtils.extractWorkspace(
        archive,
        replaceExisting: true,
      );

      return {
        'success': true,
        'message': 'Yedek başarıyla indirildi ve şifresi çözülüp geri yüklendi! ✅ '
            '($restoredCount dosya) Not listeniz yenilendi.',
      };
    } catch (e) {
      debugPrint('Bulut geri yükleme hatası: $e');
      return {'success': false, 'message': 'Geri yükleme başarısız: $e'};
    } finally {
      authClient?.close();
    }
  }
}
