import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure_bytes.dart';

class KeyDerivationResult {
  KeyDerivationResult({
    required this.derivedKey,
    required this.salt,
    required this.iterations,
  });

  final SecureBytes derivedKey;
  final Uint8List salt;
  final int iterations;
}

abstract class IKeyDerivationComponent {
  int get iterations;
  int get saltLength;
  int get derivedKeyLength;

  Uint8List generateSalt();

  Future<KeyDerivationResult> deriveKey({
    required SecureBytes password,
    Uint8List? salt,
  });
}

class Pbkdf2KeyDerivationComponent implements IKeyDerivationComponent {
  Pbkdf2KeyDerivationComponent({
    Pbkdf2? algorithm,
    this.random,
    this.iterations = 210000,
    this.saltLength = 16,
    this.derivedKeyLength = 32,
  }) : _algorithm = algorithm ??
            Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: iterations,
              bits: derivedKeyLength * 8,
            );

  final Pbkdf2 _algorithm;
  final Random? random;

  @override
  final int iterations;

  @override
  final int saltLength;

  @override
  final int derivedKeyLength;

  @override
  Uint8List generateSalt() {
    final secureRandom = random ?? Random.secure();
    return Uint8List.fromList(
      List<int>.generate(saltLength, (_) => secureRandom.nextInt(256)),
    );
  }

  @override
  Future<KeyDerivationResult> deriveKey({
    required SecureBytes password,
    Uint8List? salt,
  }) async {
    final effectiveSalt = salt == null ? generateSalt() : Uint8List.fromList(salt);

    final secretKey = await _algorithm.deriveKey(
      secretKey: SecretKey(password.copy()),
      nonce: effectiveSalt,
    );

    final derivedBytes = Uint8List.fromList(await secretKey.extractBytes());

    return KeyDerivationResult(
      derivedKey: SecureBytes.fromBytes(derivedBytes, copy: false),
      salt: effectiveSalt,
      iterations: iterations,
    );
  }
}
