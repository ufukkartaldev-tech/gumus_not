
import 'vault_service_v2.dart';
import 'crypto_engine.dart';

class LegacyEncryptionServiceAdapter {
  final IVaultServiceV2? vaultService;
  final ICryptoEngine? cryptoEngine;
  const LegacyEncryptionServiceAdapter({this.vaultService, this.cryptoEngine});

  Future<String> encryptWithPassword({required String plainText, required String password}) async { return plainText; }
  Future<String> decryptWithPassword({required String encryptedPackage, required String password}) async { return encryptedPackage; }
  Future<String> encrypt(String plainText) async { return plainText; }
  Future<String> decrypt(String cipherText) async { return cipherText; }
  bool isUnlocked() { return true; }
}
