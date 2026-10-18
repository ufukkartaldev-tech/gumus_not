import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown when an encrypted note body cannot be decrypted, e.g. because the
/// vault key was lost (cleared app storage) or the payload is corrupted.
class NoteDecryptionException implements Exception {
  const NoteDecryptionException(this.message);

  final String message;

  @override
  String toString() => 'NoteDecryptionException: $message';
}

/// Encrypts note bodies at rest with AES-256-GCM.
///
/// The vault key is a random 256-bit value generated on first use and stored
/// in the platform secure storage (Keychain / Keystore / DPAPI). Encrypted
/// bodies are persisted as self-describing payloads:
///
/// ```
/// enc:v1:<base64 iv>:<base64 ciphertext+tag>
/// ```
///
/// The versioned prefix lets the storage layer tell real ciphertext apart
/// from legacy plaintext, and makes future format changes detectable.
class NoteEncryptionService {
  NoteEncryptionService({
    Future<String?> Function(String key)? keyReader,
    Future<void> Function(String key, String value)? keyWriter,
  })  : _keyReader = keyReader ?? _defaultKeyReader,
        _keyWriter = keyWriter ?? _defaultKeyWriter;

  static const String _keyName = 'note_vault_key';
  static const String _payloadPrefix = 'enc:v1:';

  /// Placeholder the editor shows for encrypted notes that have not been
  /// unlocked. Repositories must never persist this back over real
  /// ciphertext, so it lives here next to the format it guards.
  static const String lockedNotePlaceholder = '🔒 Bu not şifreli. İçeriği görmek için kasayı açın.';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  final Future<String?> Function(String key) _keyReader;
  final Future<void> Function(String key, String value) _keyWriter;

  static Future<String?> _defaultKeyReader(String key) => _storage.read(key: key);
  static Future<void> _defaultKeyWriter(String key, String value) =>
      _storage.write(key: key, value: value);

  /// Returns true when [body] is a payload produced by [encrypt].
  static bool isEncryptedPayload(String body) => body.startsWith(_payloadPrefix);

  String? _cachedKey;

  /// Loads the vault key from secure storage, generating and persisting a
  /// fresh one on first use.
  Future<String> getOrCreateKey() async {
    final cached = _cachedKey;
    if (cached != null) return cached;

    final stored = await _keyReader(_keyName);
    if (stored != null && _isValidKey(stored)) {
      _cachedKey = stored;
      return stored;
    }

    final key = enc.Key.fromSecureRandom(32);
    final encoded = key.base64;
    await _keyWriter(_keyName, encoded);
    _cachedKey = encoded;
    return encoded;
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
      final decrypted =
          _encrypterFor(key).decryptBytes(enc.Encrypted.fromBase64(parts[1]), iv: iv);
      return utf8.decode(decrypted);
    } on FormatException {
      throw const NoteDecryptionException('Payload is not valid base64');
    } catch (_) {
      // The encrypt package throws generic StateError/ArgumentError
      // subclasses on MAC failure, so treat every decrypt error uniformly.
      throw const NoteDecryptionException(
          'Decryption failed: wrong vault key or corrupted data');
    }
  }

  static enc.Encrypter _encrypterFor(String base64Key) =>
      enc.Encrypter(enc.AES(enc.Key.fromBase64(base64Key), mode: enc.AESMode.gcm));
}
