
import 'dart:typed_data';

abstract class IKeyDerivationComponent {
  Future<Uint8List> deriveKey({required String password, required Uint8List salt, int iterations = 100000, int lengthInBytes = 32});
}
class Pbkdf2KeyDerivationComponent implements IKeyDerivationComponent {
  @override Future<Uint8List> deriveKey({required String password, required Uint8List salt, int iterations = 100000, int lengthInBytes = 32}) async { return Uint8List(32); }
}

abstract class ICryptoEngine {
  Future<String> encrypt(String plainText, Uint8List key);
  Future<String> decrypt(String cipherText, Uint8List key);
  Future<bool> verifyIntegrity(String cipherText, Uint8List key);
}
class Aes256GcmCryptoEngine implements ICryptoEngine {
  final IKeyDerivationComponent keyDerivation;
  Aes256GcmCryptoEngine({required this.keyDerivation});
  @override Future<String> encrypt(String plainText, Uint8List key) async { return plainText; }
  @override Future<String> decrypt(String cipherText, Uint8List key) async { return cipherText; }
  @override Future<bool> verifyIntegrity(String cipherText, Uint8List key) async { return true; }
}
