import 'dart:typed_data';

import 'crypto_engine.dart';
import 'legacy/legacy_encryption_service.dart';
import 'secure_bytes.dart';
import 'vault_service_v2.dart';

/// Compatibility bridge that exposes legacy-like methods while routing new
/// operations through AES-256-GCM based services.
class LegacyEncryptionServiceAdapter {
  LegacyEncryptionServiceAdapter({
    required IVaultServiceV2 vaultService,
    required ICryptoEngine cryptoEngine,
  })  : _vaultService = vaultService,
        _cryptoEngine = cryptoEngine;

  final IVaultServiceV2 _vaultService;
  final ICryptoEngine _cryptoEngine;

  bool isUnlocked() => _vaultService.isUnlocked;

  Future<void> initializeVault({
    required String password,
    String? recoveryKey,
  }) async {
    final passwordBytes = SecureBytes.fromUtf8(password);
    final recoveryBytes = recoveryKey == null ? null : SecureBytes.fromUtf8(recoveryKey);

    try {
      await _vaultService.initializeVault(
        password: passwordBytes,
        recoveryKey: recoveryBytes,
      );
    } finally {
      passwordBytes.wipe();
      recoveryBytes?.wipe();
    }
  }

  Future<bool> initializeWithRecoveryKey(String recoveryKey) async {
    final recoveryBytes = SecureBytes.fromUtf8(recoveryKey);
    try {
      return await _vaultService.unlockWithRecoveryKey(recoveryBytes);
    } finally {
      recoveryBytes.wipe();
    }
  }

  Future<bool> unlockWithPassword(String password) async {
    final passwordBytes = SecureBytes.fromUtf8(password);
    try {
      return await _vaultService.unlockWithPassword(passwordBytes);
    } finally {
      passwordBytes.wipe();
    }
  }

  Future<String> encrypt(String plainText) {
    return _vaultService.encryptText(plainText);
  }

  Future<String> decrypt(String encryptedText) {
    return _vaultService.decryptText(encryptedText);
  }

  Future<String> encryptWithPassword({
    required String plainText,
    required String password,
  }) async {
    final plainBytes = SecureBytes.fromUtf8(plainText);
    final passwordBytes = SecureBytes.fromUtf8(password);

    try {
      return await _cryptoEngine.wrapKey(
        keyToWrap: plainBytes,
        password: passwordBytes,
      );
    } finally {
      plainBytes.wipe();
      passwordBytes.wipe();
    }
  }

  Future<String> decryptWithPassword({
    required String encryptedPackage,
    required String password,
  }) async {
    final passwordBytes = SecureBytes.fromUtf8(password);
    try {
      final clearBytes = await _cryptoEngine.unwrapKey(
        wrappedPayload: encryptedPackage,
        password: passwordBytes,
      );
      try {
        return String.fromCharCodes(clearBytes.copy());
      } finally {
        clearBytes.wipe();
      }
    } finally {
      passwordBytes.wipe();
    }
  }

  Future<void> lock() => _vaultService.lock();

  /// Legacy migration bridge helper.
  ///
  /// Existing migration utilities still expect the old singleton service type.
  /// During staged rollout, keep the old service for reading v1/v2 legacy data,
  /// then re-encrypt into the new format through this adapter.
  EnhancedEncryptionService get legacyMigrationSource => EnhancedEncryptionService.instance;

  Uint8List generateMasterKeyForTests() => _cryptoEngine.generateMasterKey();
}
