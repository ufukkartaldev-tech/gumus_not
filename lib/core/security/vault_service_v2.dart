import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_engine.dart';
import 'secure_bytes.dart';

abstract class IVaultServiceV2 {
  bool get isUnlocked;

  Future<void> initializeVault({
    required SecureBytes password,
    SecureBytes? recoveryKey,
  });

  Future<bool> unlockWithPassword(SecureBytes password);
  Future<bool> unlockWithRecoveryKey(SecureBytes recoveryKey);

  Future<String> encryptText(String plainText);
  Future<String> decryptText(String encryptedPayload);

  Future<void> lock();
}

class VaultStorageKeysV2 {
  static const wrappedPassword = 'vault_v2_wrapped_password';
  static const wrappedRecovery = 'vault_v2_wrapped_recovery';
  static const formatVersion = 'vault_v2_format';
}

class VaultServiceV2 implements IVaultServiceV2 {
  VaultServiceV2({
    required ICryptoEngine cryptoEngine,
    FlutterSecureStorage? secureStorage,
  })  : _cryptoEngine = cryptoEngine,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final ICryptoEngine _cryptoEngine;
  final FlutterSecureStorage _secureStorage;

  SecureBytes? _masterKey;

  @override
  bool get isUnlocked => _masterKey != null;

  @override
  Future<void> initializeVault({
    required SecureBytes password,
    SecureBytes? recoveryKey,
  }) async {
    final existingWrappedPassword = await _secureStorage.read(
      key: VaultStorageKeysV2.wrappedPassword,
    );

    if (existingWrappedPassword != null) {
      final unlocked = await unlockWithPassword(password);
      if (!unlocked) {
        throw StateError('Existing vault could not be unlocked with the supplied password.');
      }
      return;
    }

    final generatedMasterKey = SecureBytes.fromBytes(
      _cryptoEngine.generateMasterKey(),
      copy: false,
    );
    final effectiveRecoveryKey = recoveryKey ?? _cryptoEngine.generateRecoveryKey();

    try {
      final wrappedPassword = await _cryptoEngine.wrapKey(
        keyToWrap: generatedMasterKey,
        password: password,
      );

      final wrappedRecovery = await _cryptoEngine.wrapKey(
        keyToWrap: generatedMasterKey,
        password: effectiveRecoveryKey,
      );

      await _secureStorage.write(
        key: VaultStorageKeysV2.wrappedPassword,
        value: wrappedPassword,
      );
      await _secureStorage.write(
        key: VaultStorageKeysV2.wrappedRecovery,
        value: wrappedRecovery,
      );
      await _secureStorage.write(
        key: VaultStorageKeysV2.formatVersion,
        value: '2',
      );

      await lock();
      _masterKey = SecureBytes.fromBytes(generatedMasterKey.copy(), copy: false);
    } finally {
      generatedMasterKey.wipe();
      if (recoveryKey == null) {
        effectiveRecoveryKey.wipe();
      }
    }
  }

  @override
  Future<bool> unlockWithPassword(SecureBytes password) async {
    final wrapped = await _secureStorage.read(key: VaultStorageKeysV2.wrappedPassword);
    if (wrapped == null) return false;

    try {
      final unwrapped = await _cryptoEngine.unwrapKey(
        wrappedPayload: wrapped,
        password: password,
      );
      await lock();
      _masterKey = unwrapped;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> unlockWithRecoveryKey(SecureBytes recoveryKey) async {
    final wrapped = await _secureStorage.read(key: VaultStorageKeysV2.wrappedRecovery);
    if (wrapped == null) return false;

    try {
      final unwrapped = await _cryptoEngine.unwrapKey(
        wrappedPayload: wrapped,
        password: recoveryKey,
      );
      await lock();
      _masterKey = unwrapped;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> encryptText(String plainText) async {
    final masterKey = _masterKey;
    if (masterKey == null) {
      throw StateError('Vault is locked.');
    }

    final plainBytes = SecureBytes.fromUtf8(plainText);
    try {
      return await _cryptoEngine.encrypt(
        plainBytes: plainBytes,
        key: masterKey,
      );
    } finally {
      plainBytes.wipe();
    }
  }

  @override
  Future<String> decryptText(String encryptedPayload) async {
    final masterKey = _masterKey;
    if (masterKey == null) {
      throw StateError('Vault is locked.');
    }

    final clearBytes = await _cryptoEngine.decrypt(
      encryptedPayload: encryptedPayload,
      key: masterKey,
    );

    try {
      return utf8.decode(clearBytes.copy());
    } finally {
      clearBytes.wipe();
    }
  }

  @override
  Future<void> lock() async {
    _masterKey?.wipe();
    _masterKey = null;
  }
}
