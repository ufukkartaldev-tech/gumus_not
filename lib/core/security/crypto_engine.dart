import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'key_derivation_component.dart';
import 'secure_bytes.dart';

class CryptoEngineConstants {
  static const int aesKeyLength = 32;
  static const int nonceLength = 12;
  static const int recoveryKeyLength = 24;
  static const int version = 1;
  static const String recoveryAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
}

class EncryptionPayload {
  EncryptionPayload({
    required this.version,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final int version;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;

  String encode() {
    return jsonEncode({
      'v': version,
      'n': base64Encode(nonce),
      'c': base64Encode(cipherText),
      't': base64Encode(mac),
    });
  }

  static EncryptionPayload decode(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    return EncryptionPayload(
      version: map['v'] as int,
      nonce: Uint8List.fromList(base64Decode(map['n'] as String)),
      cipherText: Uint8List.fromList(base64Decode(map['c'] as String)),
      mac: Uint8List.fromList(base64Decode(map['t'] as String)),
    );
  }
}

class WrappedKeyPayload {
  WrappedKeyPayload({
    required this.version,
    required this.kdf,
    required this.iterations,
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final int version;
  final String kdf;
  final int iterations;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;

  String encode() {
    return jsonEncode({
      'v': version,
      'kdf': kdf,
      'i': iterations,
      's': base64Encode(salt),
      'n': base64Encode(nonce),
      'c': base64Encode(cipherText),
      't': base64Encode(mac),
    });
  }

  static WrappedKeyPayload decode(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    return WrappedKeyPayload(
      version: map['v'] as int,
      kdf: map['kdf'] as String,
      iterations: map['i'] as int,
      salt: Uint8List.fromList(base64Decode(map['s'] as String)),
      nonce: Uint8List.fromList(base64Decode(map['n'] as String)),
      cipherText: Uint8List.fromList(base64Decode(map['c'] as String)),
      mac: Uint8List.fromList(base64Decode(map['t'] as String)),
    );
  }
}

abstract class ICryptoEngine {
  Uint8List generateMasterKey();
  SecureBytes generateRecoveryKey();

  Future<String> encrypt({
    required SecureBytes plainBytes,
    required SecureBytes key,
  });

  Future<SecureBytes> decrypt({
    required String encryptedPayload,
    required SecureBytes key,
  });

  Future<String> wrapKey({
    required SecureBytes keyToWrap,
    required SecureBytes password,
  });

  Future<SecureBytes> unwrapKey({
    required String wrappedPayload,
    required SecureBytes password,
  });
}

class Aes256GcmCryptoEngine implements ICryptoEngine {
  Aes256GcmCryptoEngine({
    required IKeyDerivationComponent keyDerivation,
    Cipher? cipher,
    Random? random,
  })  : _keyDerivation = keyDerivation,
        _cipher = cipher ?? AesGcm.with256bits(),
        _random = random ?? Random.secure();

  final IKeyDerivationComponent _keyDerivation;
  final Cipher _cipher;
  final Random _random;

  @override
  Uint8List generateMasterKey() {
    return _randomBytes(CryptoEngineConstants.aesKeyLength);
  }

  @override
  SecureBytes generateRecoveryKey() {
    final value = List<int>.generate(
      CryptoEngineConstants.recoveryKeyLength,
      (_) => CryptoEngineConstants.recoveryAlphabet.codeUnitAt(
        _random.nextInt(CryptoEngineConstants.recoveryAlphabet.length),
      ),
    );
    return SecureBytes.fromBytes(Uint8List.fromList(value), copy: false);
  }

  @override
  Future<String> encrypt({
    required SecureBytes plainBytes,
    required SecureBytes key,
  }) async {
    final nonce = _randomBytes(CryptoEngineConstants.nonceLength);

    final box = await _cipher.encrypt(
      plainBytes.copy(),
      secretKey: SecretKey(key.copy()),
      nonce: nonce,
    );

    return EncryptionPayload(
      version: CryptoEngineConstants.version,
      nonce: Uint8List.fromList(box.nonce),
      cipherText: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    ).encode();
  }

  @override
  Future<SecureBytes> decrypt({
    required String encryptedPayload,
    required SecureBytes key,
  }) async {
    final payload = EncryptionPayload.decode(encryptedPayload);

    if (payload.version != CryptoEngineConstants.version) {
      throw StateError('Unsupported encryption payload version: ${payload.version}');
    }

    final clearBytes = await _cipher.decrypt(
      SecretBox(
        payload.cipherText,
        nonce: payload.nonce,
        mac: Mac(payload.mac),
      ),
      secretKey: SecretKey(key.copy()),
    );

    return SecureBytes.fromBytes(Uint8List.fromList(clearBytes), copy: false);
  }

  @override
  Future<String> wrapKey({
    required SecureBytes keyToWrap,
    required SecureBytes password,
  }) async {
    final derivation = await _keyDerivation.deriveKey(password: password);

    try {
      final nonce = _randomBytes(CryptoEngineConstants.nonceLength);

      final box = await _cipher.encrypt(
        keyToWrap.copy(),
        secretKey: SecretKey(derivation.derivedKey.copy()),
        nonce: nonce,
      );

      return WrappedKeyPayload(
        version: CryptoEngineConstants.version,
        kdf: 'pbkdf2-hmac-sha256',
        iterations: derivation.iterations,
        salt: derivation.salt,
        nonce: Uint8List.fromList(box.nonce),
        cipherText: Uint8List.fromList(box.cipherText),
        mac: Uint8List.fromList(box.mac.bytes),
      ).encode();
    } finally {
      derivation.derivedKey.wipe();
    }
  }

  @override
  Future<SecureBytes> unwrapKey({
    required String wrappedPayload,
    required SecureBytes password,
  }) async {
    final payload = WrappedKeyPayload.decode(wrappedPayload);

    if (payload.version != CryptoEngineConstants.version) {
      throw StateError('Unsupported wrapped-key payload version: ${payload.version}');
    }

    if (payload.kdf != 'pbkdf2-hmac-sha256') {
      throw StateError('Unsupported KDF: ${payload.kdf}');
    }

    final derivation = await _keyDerivation.deriveKey(
      password: password,
      salt: payload.salt,
    );

    try {
      final bytes = await _cipher.decrypt(
        SecretBox(
          payload.cipherText,
          nonce: payload.nonce,
          mac: Mac(payload.mac),
        ),
        secretKey: SecretKey(derivation.derivedKey.copy()),
      );

      return SecureBytes.fromBytes(Uint8List.fromList(bytes), copy: false);
    } finally {
      derivation.derivedKey.wipe();
    }
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }
}
