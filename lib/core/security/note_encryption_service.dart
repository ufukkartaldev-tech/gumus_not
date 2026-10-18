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
/// - **DEK (Data Encryption Key)**: A random 256-bit key generated once and
///   cached in platform secure storage (`FlutterSecureStorage`) for fast daily
///   use.
/// - **KEK (Key Encryption Key)**: Derived from the user's Master Password via
///   `PBKDF2-HMAC-SHA256` (120,000 iterations by default) with a random
///   128-bit salt.
/// - **Envelope (`.vault_key.json`)**: Stores the KDF parameters, salt, IV, and
///   the AES-256-GCM encrypted DEK inside the notes directory so the vault
///   travels safely with Git repositories, folder copies, and ZIP backups.
class NoteEncryptionService {
  NoteEncryptionService({
    Future<String?> Function(String key)? keyReader,
    Future<void> Function(String key, String value)? keyWriter,
    Future<Directory> Function()? vaultDirResolver,
    int pbkdf2Iterations = defaultPbkdf2Iterations,
  })  : _keyReader = keyReader ?? _defaultKeyReader,
        _keyWriter = keyWriter ?? _defaultKeyWriter,
        _vaultDirResolver = vaultDirResolver,
        _pbkdf2Iterations = pbkdf2Iterations;

  static const String _keyName = 'note_vault_key';
  static const String _payloadPrefix = 'enc:v1:';
  static const String envelopeFileName = '.vault_key.json';
  static const int defaultPbkdf2Iterations = 120000;

  /// Placeholder the editor shows for encrypted notes that have not been
  /// unlocked. Repositories must never persist this back over real
  /// ciphertext, so it lives here next to the format it guards.
  static const String lockedNotePlaceholder =
      '🔒 Bu not şifreli. İçeriği görmek için kasayı açın.';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  final Future<String?> Function(String key) _keyReader;
  final Future<void> Function(String key, String value) _keyWriter;
  final Future<Directory> Function()? _vaultDirResolver;
  final int _pbkdf2Iterations;

  static Future<String?> _defaultKeyReader(String key) =>
      _storage.read(key: key);
  static Future<void> _defaultKeyWriter(String key, String value) =>
      _storage.write(key: key, value: value);

  /// Returns true when [body] is a payload produced by [encrypt].
  static bool isEncryptedPayload(String body) =>
      body.startsWith(_payloadPrefix);

  String? _cachedKey;

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
    if (_cachedKey != null) return true;
    final stored = await _keyReader(_keyName);
    if (stored != null && _isValidKey(stored)) {
      _cachedKey = stored;
      return true;
    }
    return false;
  }

  /// Loads the vault DEK from secure storage, generating and persisting a
  /// fresh one on first use ONLY if no `.vault_key.json` envelope exists yet.
  ///
  /// If an envelope exists on disk (e.g. synced from another device) and the
  /// local storage has no key, throws [VaultLockedByPasswordException] to
  /// prevent silently generating a conflicting key.
  Future<String> getOrCreateKey() async {
    final cached = _cachedKey;
    if (cached != null) return cached;

    final stored = await _keyReader(_keyName);
    if (stored != null && _isValidKey(stored)) {
      _cachedKey = stored;
      return stored;
    }

    if (await hasEnvelope()) {
      throw const VaultLockedByPasswordException();
    }

    final key = enc.Key.fromSecureRandom(32);
    final encoded = key.base64;
    await _keyWriter(_keyName, encoded);
    _cachedKey = encoded;
    return encoded;
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
    final dekBase64 = await getOrCreateKey();
    final dekBytes = base64Decode(dekBase64);

    final salt = enc.IV.fromSecureRandom(16).bytes;
    final iv = enc.IV.fromSecureRandom(16);
    final kekBytes = pbkdf2Sha256(
      password: masterPassword,
      salt: salt,
      iterations: _pbkdf2Iterations,
      keyLength: 32,
    );

    final kekEncrypter = enc.Encrypter(
      enc.AES(enc.Key(kekBytes), mode: enc.AESMode.gcm),
    );
    final wrappedDek = kekEncrypter.encryptBytes(dekBytes, iv: iv);

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

    try {
      final salt = base64Decode(saltB64);
      final iv = enc.IV.fromBase64(ivB64);
      final kekBytes = pbkdf2Sha256(
        password: masterPassword,
        salt: salt,
        iterations: iterations,
        keyLength: 32,
      );

      final kekEncrypter = enc.Encrypter(
        enc.AES(enc.Key(kekBytes), mode: enc.AESMode.gcm),
      );
      final dekBytes = kekEncrypter.decryptBytes(
        enc.Encrypted.fromBase64(ciphertextB64),
        iv: iv,
      );

      if (dekBytes.length != 32) {
        throw const InvalidVaultPasswordException();
      }

      final dekBase64 = base64Encode(dekBytes);
      await _keyWriter(_keyName, dekBase64);
      _cachedKey = dekBase64;
      return dekBase64;
    } on InvalidVaultPasswordException {
      rethrow;
    } catch (_) {
      throw const InvalidVaultPasswordException();
    }
  }

  /// Standard PBKDF2-HMAC-SHA256 implementation (RFC 8018).
  @visibleForTesting
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
    }

    return Uint8List.sublistView(derivedKey, 0, keyLength);
  }

  static bool _isValidKey(String value) {
    try {
      return enc.Key.fromBase64(value).length == 32;
    } on FormatException {
      return false;
    }
  }

  Future<String> encrypt(String plaintext) async {
    final key = await getOrCreateKey();
    final encrypter = _encrypterFor(key);
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

    final key = await getOrCreateKey();
    try {
      final iv = enc.IV.fromBase64(parts[0]);
      final decrypted = _encrypterFor(key).decryptBytes(
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

  static enc.Encrypter _encrypterFor(String base64Key) =>
      enc.Encrypter(enc.AES(enc.Key.fromBase64(base64Key), mode: enc.AESMode.gcm));
}
