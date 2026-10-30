import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thrown when an encrypted note body cannot be decrypted, e.g. because the
/// vault key was lost (cleared app storage) or the payload is corrupted.
class NoteDecryptionException implements Exception {
  const NoteDecryptionException(this.message);

  final String message;

  @override
  String toString() => 'NoteDecryptionException: $message';
}

/// Thrown when a `.vault_key.json` envelope exists on disk, but the local
/// device has not unlocked and cached the Data Encryption Key (DEK) yet.
class VaultLockedByPasswordException extends NoteDecryptionException {
  const VaultLockedByPasswordException([
    super.message = 'Kasa kilitli. Devam etmek için kasa parolanızı girin.',
  ]);
}

/// Thrown when unlocking `.vault_key.json` fails due to an incorrect password
/// (AES-256-GCM authentication tag mismatch) or corrupted envelope file.
class InvalidVaultPasswordException extends NoteDecryptionException {
  const InvalidVaultPasswordException([
    super.message = 'Kasa parolası hatalı.',
  ]);
}

/// Encrypts note bodies at rest with AES-256-GCM using **Envelope Encryption**.
///
/// - **DEK (Data Encryption Key)**: A random 256-bit key held in memory as a
///   mutable [Uint8List] so it can be deterministically zeroed (`fillRange`)
///   when the vault is locked, and optionally cached in platform secure storage
///   (`FlutterSecureStorage`).
/// - **KEK (Key Encryption Key)**: Derived from the user's Master Password via
///   `PBKDF2-HMAC-SHA256` (120,000 iterations by default) with a random
///   128-bit salt, and deterministically wiped from memory immediately after
///   wrapping/unwrapping the DEK.
/// - **Envelope (`.vault_key.json`)**: Stores the KDF parameters, salt, IV, and
///   the AES-256-GCM encrypted DEK inside the notes directory so the vault
///   travels safely with Git repositories, folder copies, and ZIP backups.
class NoteEncryptionService {
  NoteEncryptionService({
    Future<String?> Function(String key)? keyReader,
    Future<void> Function(String key, String value)? keyWriter,
    Future<void> Function(String key)? keyDeleter,
    Future<Directory> Function()? vaultDirResolver,
    int pbkdf2Iterations = defaultPbkdf2Iterations,
  })  : _keyReader = keyReader ?? _defaultKeyReader,
        _keyWriter = keyWriter ?? _defaultKeyWriter,
        _keyDeleter = keyDeleter ?? _defaultKeyDeleter,
        _vaultDirResolver = vaultDirResolver,
        _pbkdf2Iterations = pbkdf2Iterations;

  static const String _keyName = 'note_vault_key';
  static const String _payloadPrefix = 'enc:v1:';
  static const String envelopeFileName = '.vault_key.json';
  static const int defaultPbkdf2Iterations = 120000;
  static const int minPbkdf2Iterations = 1000;
  static const int maxPbkdf2Iterations = 5000000;

  /// Placeholder the editor shows for encrypted notes that have not been
  /// unlocked. Repositories must never persist this back over real
  /// ciphertext, so it lives here next to the format it guards.
  static const String lockedNotePlaceholder =
      '🔒 Bu not şifreli. İçeriği görmek için kasayı açın.';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  final Future<String?> Function(String key) _keyReader;
  final Future<void> Function(String key, String value) _keyWriter;
  final Future<void> Function(String key) _keyDeleter;
  final Future<Directory> Function()? _vaultDirResolver;
  final int _pbkdf2Iterations;

  static Future<String?> _defaultKeyReader(String key) =>
      _storage.read(key: key);
  static Future<void> _defaultKeyWriter(String key, String value) =>
      _storage.write(key: key, value: value);
  static Future<void> _defaultKeyDeleter(String key) =>
      _storage.delete(key: key);

  /// Returns true when [body] is a payload produced by [encrypt].
  static bool isEncryptedPayload(String body) =>
      body.startsWith(_payloadPrefix);

  /// Mutable 32-byte DEK buffer in RAM; zeroed deterministically on [lockVault].
  Uint8List? _cachedDekBytes;

  /// Exposes the in-memory DEK buffer strictly for deterministic zeroing tests.
  @visibleForTesting
  Uint8List? get debugCachedDekBuffer => _cachedDekBytes;

  /// Returns true if an unlocked 32-byte DEK is currently resident in RAM.
  bool get isUnlockedInMemory =>
      _cachedDekBytes != null && _cachedDekBytes!.length == 32;

  void _setCachedDekBytes(List<int> rawBytes) {
    final existing = _cachedDekBytes;
    if (existing != null) {
      existing.fillRange(0, existing.length, 0);
    }
    _cachedDekBytes = Uint8List.fromList(rawBytes);
  }

  /// Deterministically zeroes the in-memory DEK buffer (`fillRange(0, len, 0)`)
  /// without waiting for Dart GC.
  ///
  /// When [purgePersistedIfRecoverable] is `true` and a `.vault_key.json`
  /// envelope exists on disk (meaning the DEK can be safely unwrapped again
  /// using the Master Password), the cached DEK is also removed from platform
  /// secure storage so subsequent accesses require re-authentication.
  Future<void> lockVault({bool purgePersistedIfRecoverable = true}) async {
    final dekBytes = _cachedDekBytes;
    if (dekBytes != null) {
      dekBytes.fillRange(0, dekBytes.length, 0);
      _cachedDekBytes = null;
    }

    if (purgePersistedIfRecoverable && await hasEnvelope()) {
      await _keyDeleter(_keyName);
    }
  }

  Future<File?> _envelopeFile() async {
    if (kIsWeb) return null;
    try {
      final Directory dir;
      final resolver = _vaultDirResolver;
      if (resolver != null) {
        dir = await resolver();
      } else {
        final docs = await getApplicationDocumentsDirectory();
        dir = Directory(p.join(docs.path, 'GumusNot', 'notes'));
      }
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return File(p.join(dir.path, envelopeFileName));
    } catch (_) {
      return null;
    }
  }

  /// Returns true if a password-protected `.vault_key.json` envelope exists in
  /// the notes workspace.
  Future<bool> hasEnvelope() async {
    final file = await _envelopeFile();
    return file != null && file.existsSync();
  }

  /// Returns true if this device currently holds a valid unlocked DEK in
  /// memory or platform secure storage.
  Future<bool> hasLocalKey() async {
    if (isUnlockedInMemory) return true;
    final stored = await _keyReader(_keyName);
    final decoded = _tryDecodeValidKey(stored);
    if (decoded != null) {
      _setCachedDekBytes(decoded);
      decoded.fillRange(0, decoded.length, 0);
      return true;
    }
    return false;
  }

  Future<Uint8List> _getOrCreateDekBytes() async {
    final cached = _cachedDekBytes;
    if (cached != null && cached.length == 32) {
      return cached;
    }

    final stored = await _keyReader(_keyName);
    final decoded = _tryDecodeValidKey(stored);
    if (decoded != null) {
      _setCachedDekBytes(decoded);
      decoded.fillRange(0, decoded.length, 0);
      return _cachedDekBytes!;
    }

    if (await hasEnvelope()) {
      throw const VaultLockedByPasswordException();
    }

    final generated = enc.Key.fromSecureRandom(32);
    try {
      await _keyWriter(_keyName, generated.base64);
      _setCachedDekBytes(generated.bytes);
      return _cachedDekBytes!;
    } finally {
      generated.bytes.fillRange(0, generated.bytes.length, 0);
    }
  }

  /// Loads the vault DEK from secure storage, generating and persisting a
  /// fresh one on first use ONLY if no `.vault_key.json` envelope exists yet.
  ///
  /// If an envelope exists on disk (e.g. synced from another device) and the
  /// local storage has no key, throws [VaultLockedByPasswordException] to
  /// prevent silently generating a conflicting key.
  Future<String> getOrCreateKey() async {
    final dekBytes = await _getOrCreateDekBytes();
    return base64Encode(dekBytes);
  }

  /// Wraps the current (or newly created) 256-bit DEK with a KEK derived from
  /// [masterPassword] via PBKDF2-HMAC-SHA256 and writes `.vault_key.json`.
  ///
  /// Changing the master password only re-wraps the DEK in `.vault_key.json`
  /// without needing to re-encrypt any note files.
  Future<void> setupMasterPassword(String masterPassword) async {
    if (masterPassword.trim().isEmpty) {
      throw ArgumentError('Master parola boş olamaz.');
    }
    final dekBytes = await _getOrCreateDekBytes();

    final salt = enc.IV.fromSecureRandom(16).bytes;
    final iv = enc.IV.fromSecureRandom(16);
    final kekBytes = pbkdf2Sha256(
      password: masterPassword,
      salt: salt,
      iterations: _pbkdf2Iterations,
      keyLength: 32,
    );

    final enc.Encrypted wrappedDek;
    try {
      final kekEncrypter = enc.Encrypter(
        enc.AES(enc.Key(kekBytes), mode: enc.AESMode.gcm),
      );
      wrappedDek = kekEncrypter.encryptBytes(dekBytes, iv: iv);
    } finally {
      kekBytes.fillRange(0, kekBytes.length, 0);
    }

    final envelope = <String, Object>{
      'version': 1,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _pbkdf2Iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'iv': iv.base64,
      'ciphertext': wrappedDek.base64,
    };

    final file = await _envelopeFile();
    if (file == null) {
      throw const NoteDecryptionException(
        'Kasa anahtarı dosyası bu platformda oluşturulamadı.',
      );
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(envelope),
      flush: true,
    );
  }

  /// Changes the master password after verifying [currentPassword] against the
  /// existing `.vault_key.json` envelope.
  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await unlockWithMasterPassword(currentPassword);
    await setupMasterPassword(newPassword);
  }

  /// Unwraps the DEK from `.vault_key.json` using [masterPassword], persists it
  /// to local secure storage, and caches it in memory.
  ///
  /// Throws [InvalidVaultPasswordException] if the password is wrong (GCM MAC
  /// failure) or the envelope is malformed.
  Future<String> unlockWithMasterPassword(String masterPassword) async {
    final file = await _envelopeFile();
    if (file == null || !file.existsSync()) {
      throw const NoteDecryptionException(
        'Kasa anahtar dosyası (.vault_key.json) bulunamadı.',
      );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      throw const InvalidVaultPasswordException(
        'Kasa anahtar dosyası (.vault_key.json) bozuk.',
      );
    }

    final saltB64 = data['salt'] as String?;
    final ivB64 = data['iv'] as String?;
    final ciphertextB64 = data['ciphertext'] as String?;
    final iterations = data['iterations'] as int? ?? defaultPbkdf2Iterations;

    if (saltB64 == null || ivB64 == null || ciphertextB64 == null) {
      throw const InvalidVaultPasswordException(
        'Kasa anahtar dosyası eksik alanlar içeriyor.',
      );
    }
    if (iterations < minPbkdf2Iterations ||
        iterations > maxPbkdf2Iterations) {
      throw const InvalidVaultPasswordException(
        'Geçersiz PBKDF2 iterasyon sayısı.',
      );
    }

    Uint8List? kekBytes;
    Uint8List? unwrappedDek;
    try {
      final salt = base64Decode(saltB64);
      final iv = enc.IV.fromBase64(ivB64);
      kekBytes = pbkdf2Sha256(
        password: masterPassword,
        salt: salt,
        iterations: iterations,
        keyLength: 32,
      );

      final kekEncrypter = enc.Encrypter(
        enc.AES(enc.Key(kekBytes), mode: enc.AESMode.gcm),
      );
      unwrappedDek = Uint8List.fromList(
        kekEncrypter.decryptBytes(
          enc.Encrypted.fromBase64(ciphertextB64),
          iv: iv,
        ),
      );

      if (unwrappedDek.length != 32) {
        throw const InvalidVaultPasswordException();
      }

      final dekBase64 = base64Encode(unwrappedDek);
      await _keyWriter(_keyName, dekBase64);
      _setCachedDekBytes(unwrappedDek);
      return dekBase64;
    } on InvalidVaultPasswordException {
      rethrow;
    } catch (_) {
      throw const InvalidVaultPasswordException();
    } finally {
      kekBytes?.fillRange(0, kekBytes.length, 0);
      unwrappedDek?.fillRange(0, unwrappedDek.length, 0);
    }
  }

  /// Verifies whether [masterPassword] correctly unwraps `.vault_key.json`
  /// without persisting or caching the DEK in the vault session.
  ///
  /// This allows using the master password as an authentication fallback for
  /// app lock without inadvertently unlocking all encrypted notes in the
  /// editor session.
  ///
  /// Returns `true` if the password is valid, `false` otherwise.
  Future<bool> verifyMasterPassword(String masterPassword) async {
    if (masterPassword.trim().isEmpty) return false;

    final file = await _envelopeFile();
    if (file == null || !file.existsSync()) {
      return false;
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }

    final saltB64 = data['salt'] as String?;
    final ivB64 = data['iv'] as String?;
    final ciphertextB64 = data['ciphertext'] as String?;
    final iterations = data['iterations'] as int? ?? defaultPbkdf2Iterations;

    if (saltB64 == null || ivB64 == null || ciphertextB64 == null) {
      return false;
    }
    if (iterations < minPbkdf2Iterations || iterations > maxPbkdf2Iterations) {
      return false;
    }

    Uint8List? kekBytes;
    Uint8List? unwrappedDek;
    try {
      final salt = base64Decode(saltB64);
      final iv = enc.IV.fromBase64(ivB64);
      kekBytes = pbkdf2Sha256(
        password: masterPassword,
        salt: salt,
        iterations: iterations,
        keyLength: 32,
      );

      final kekEncrypter = enc.Encrypter(
        enc.AES(enc.Key(kekBytes), mode: enc.AESMode.gcm),
      );
      unwrappedDek = Uint8List.fromList(
        kekEncrypter.decryptBytes(
          enc.Encrypted.fromBase64(ciphertextB64),
          iv: iv,
        ),
      );

      return unwrappedDek.length == 32;
    } catch (_) {
      return false;
    } finally {
      kekBytes?.fillRange(0, kekBytes.length, 0);
      unwrappedDek?.fillRange(0, unwrappedDek.length, 0);
    }
  }

  /// Standard PBKDF2-HMAC-SHA256 implementation (RFC 8018).
  static Uint8List pbkdf2Sha256({
    required String password,
    required List<int> salt,
    required int iterations,
    int keyLength = 32,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    const hashLength = 32; // SHA-256 produces 32-byte blocks
    final numBlocks = (keyLength + hashLength - 1) ~/ hashLength;
    final derivedKey = Uint8List(numBlocks * hashLength);

    final blockInput = Uint8List(salt.length + 4);
    blockInput.setRange(0, salt.length, salt);

    for (var blockIndex = 1; blockIndex <= numBlocks; blockIndex++) {
      blockInput[salt.length] = (blockIndex >> 24) & 0xff;
      blockInput[salt.length + 1] = (blockIndex >> 16) & 0xff;
      blockInput[salt.length + 2] = (blockIndex >> 8) & 0xff;
      blockInput[salt.length + 3] = blockIndex & 0xff;

      var u = Uint8List.fromList(hmac.convert(blockInput).bytes);
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < hashLength; j++) {
          t[j] ^= u[j];
        }
      }

      derivedKey.setRange(
        (blockIndex - 1) * hashLength,
        blockIndex * hashLength,
        t,
      );
      u.fillRange(0, u.length, 0);
      t.fillRange(0, t.length, 0);
    }

    return Uint8List.sublistView(derivedKey, 0, keyLength);
  }

  static Uint8List? _tryDecodeValidKey(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = base64Decode(value);
      return decoded.length == 32 ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<String> encrypt(String plaintext) async {
    final dekBytes = await _getOrCreateDekBytes();
    final encrypter = _encrypterForBytes(dekBytes);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '$_payloadPrefix${iv.base64}:${encrypted.base64}';
  }

  Future<String> decrypt(String payload) async {
    if (!isEncryptedPayload(payload)) {
      throw const NoteDecryptionException('Body is not an encrypted payload');
    }

    final parts = payload.substring(_payloadPrefix.length).split(':');
    if (parts.length != 2) {
      throw const NoteDecryptionException('Malformed payload structure');
    }

    final dekBytes = await _getOrCreateDekBytes();
    try {
      final iv = enc.IV.fromBase64(parts[0]);
      final decrypted = _encrypterForBytes(dekBytes).decryptBytes(
        enc.Encrypted.fromBase64(parts[1]),
        iv: iv,
      );
      return utf8.decode(decrypted);
    } on FormatException {
      throw const NoteDecryptionException('Payload is not valid base64');
    } catch (_) {
      // The encrypt package throws generic StateError/ArgumentError
      // subclasses on MAC failure, so treat every decrypt error uniformly.
      throw const NoteDecryptionException(
        'Decryption failed: wrong vault key or corrupted data',
      );
    }
  }

  static enc.Encrypter _encrypterForBytes(Uint8List keyBytes) =>
      enc.Encrypter(enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm));
}
