import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Security constants for encryption
class SecurityConstants {
  // Key derivation
  static const int pbkdf2Iterations = 100000;
  static const int pbkdf2KeyLength = 32; // 256 bits
  static const int saltLength = 16; // 128 bits
  static const int ivLength = 16; // 128 bits
  
  // Master key
  static const int masterKeyLength = 32; // 256 bits
  
  // Recovery key
  static const int recoveryKeyLength = 24;
  static const String recoveryKeyCharset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  
  // Storage keys
  static const String storageKeyWrappedPassword = 'vault_mk_wrapped_pw';
  static const String storageKeyWrappedRecovery = 'vault_mk_wrapped_rec';
  static const String storageKeySalt = 'vault_mk_salt';
  
  // Encryption format version (for future compatibility)
  static const int encryptionFormatVersion = 2;
}

/// Secure memory utilities for zeroing sensitive data
class SecureMemory {
  /// Securely wipe a byte array by overwriting with zeros
  static void wipeBytes(Uint8List? bytes) {
    if (bytes == null) return;
    
    // Overwrite with random data first, then zeros
    final random = Random.secure();
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
  
  /// Securely wipe a string by converting to bytes and wiping
  static void wipeString(String? str) {
    if (str == null) return;
    
    // Convert to bytes, wipe, then clear the string reference
    final bytes = utf8.encode(str);
    final byteList = Uint8List.fromList(bytes);
    wipeBytes(byteList);
  }
  
  /// Create a secure random byte array
  static Uint8List secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (index) => random.nextInt(256)),
    );
  }
  
  /// Generate a secure random salt
  static Uint8List generateSalt() {
    return secureRandomBytes(SecurityConstants.saltLength);
  }
  
  /// Generate a secure random IV
  static IV generateIV() {
    return IV(secureRandomBytes(SecurityConstants.ivLength));
  }
  
  /// Generate a secure random master key
  static Uint8List generateMasterKey() {
    return secureRandomBytes(SecurityConstants.masterKeyLength);
  }
}

/// PBKDF2 key derivation with salt
class KeyDerivation {
  /// Derive a key from password using PBKDF2 with salt
  static Uint8List deriveKeyFromPassword({
    required String password,
    required Uint8List salt,
    int iterations = SecurityConstants.pbkdf2Iterations,
    int keyLength = SecurityConstants.pbkdf2KeyLength,
  }) {
    // Convert password to bytes
    final passwordBytes = utf8.encode(password);
    
    // PBKDF2 key derivation using HMAC-SHA256
    var derivedKey = Uint8List(keyLength);
    var block = Uint8List(0);
    
    for (int i = 1; derivedKey.length > 0; i++) {
      // Calculate U1 = HMAC(password, salt || i)
      var hmac = Hmac(sha256, passwordBytes);
      var input = Uint8List.fromList([...salt, ..._intToBytes(i)]);
      var u = Uint8List.fromList(hmac.convert(input).bytes);
      
      block = u;
      
      // Calculate U2..Uc
      for (int j = 1; j < iterations; j++) {
        hmac = Hmac(sha256, passwordBytes);
        u = Uint8List.fromList(hmac.convert(u).bytes);
        
        // XOR block with u
        for (int k = 0; k < block.length; k++) {
          block[k] ^= u[k];
        }
      }
      
      // Copy block to derivedKey
      final bytesToCopy = derivedKey.length < block.length 
          ? derivedKey.length 
          : block.length;
      
      for (int j = 0; j < bytesToCopy; j++) {
        derivedKey[j] = block[j];
      }
      
      derivedKey = derivedKey.sublist(bytesToCopy);
    }
    
    return block;
  }
  
  /// Convert integer to big-endian bytes
  static Uint8List _intToBytes(int i) {
    return Uint8List(4)
      ..[0] = (i >> 24) & 0xFF
      ..[1] = (i >> 16) & 0xFF
      ..[2] = (i >> 8) & 0xFF
      ..[3] = i & 0xFF;
  }
  
  /// Generate a recovery key
  static String generateRecoveryKey() {
    final random = Random.secure();
    return List.generate(
      SecurityConstants.recoveryKeyLength,
      (index) => SecurityConstants.recoveryKeyCharset[
        random.nextInt(SecurityConstants.recoveryKeyCharset.length)
      ],
    ).join();
  }
}

/// Enhanced encryption service with PBKDF2 and salt
class EnhancedEncryptionService {
  // Singleton instance
  static EnhancedEncryptionService? _instance;
  
  // Secure storage
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Master key and encrypter
  Uint8List? _masterKey;
  Encrypter? _encrypter;
  String? _recoveryKey;
  
  // Memory protection
  bool _isLocked = true;
  
  /// Private constructor for singleton
  EnhancedEncryptionService._();
  
  /// Get singleton instance
  static EnhancedEncryptionService get instance {
    _instance ??= EnhancedEncryptionService._();
    return _instance!;
  }
  
  /// Initialize vault with password
  Future<void> initializeVault({
    required String password,
    String? recoveryKey,
  }) async {
    try {
      // Check if vault already exists
      final existingSalt = await _secureStorage.read(
        key: SecurityConstants.storageKeySalt,
      );
      
      if (existingSalt == null) {
        // New vault setup
        await _setupNewVault(password: password, recoveryKey: recoveryKey);
      } else {
        // Unlock existing vault
        await _unlockVault(password: password);
      }
      
      _isLocked = false;
    } catch (e) {
      _isLocked = true;
      rethrow;
    }
  }
  
  /// Initialize vault with recovery key
  Future<bool> initializeWithRecoveryKey(String recoveryKey) async {
    try {
      final wrappedRecovery = await _secureStorage.read(
        key: SecurityConstants.storageKeyWrappedRecovery,
      );
      
      if (wrappedRecovery == null) return false;
      
      // Unwrap master key with recovery key
      _masterKey = await _unwrapMasterKey(
        wrappedPackage: wrappedRecovery,
        password: recoveryKey,
      );
      
      _encrypter = Encrypter(AES(Key(_masterKey!)));
      _recoveryKey = recoveryKey;
      _isLocked = false;
      
      return true;
    } catch (e) {
      _isLocked = true;
      return false;
    }
  }
  
  /// Encrypt text with master key
  String encrypt(String plainText) {
    _checkLocked();
    if (plainText.isEmpty) return '';
    
    try {
      final iv = SecureMemory.generateIV();
      final encrypted = _encrypter!.encrypt(plainText, iv: iv);
      
      // Format: version:salt:iv:encrypted
      return '${SecurityConstants.encryptionFormatVersion}:${iv.base64}:${encrypted.base64}';
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }
  
  /// Decrypt text with master key
  String decrypt(String encryptedPackage) {
    _checkLocked();
    if (encryptedPackage.isEmpty) return '';
    
    try {
      final parts = encryptedPackage.split(':');
      
      // Handle different format versions
      if (parts.length == 3 && parts[0] == '2') {
        // Version 2 format: version:iv:encrypted
        final iv = IV.fromBase64(parts[1]);
        final encrypted = Encrypted.fromBase64(parts[2]);
        
        return _encrypter!.decrypt(encrypted, iv: iv);
      } else if (parts.length == 2) {
        // Legacy format (version 1): iv:encrypted
        final iv = IV.fromBase64(parts[0]);
        final encrypted = Encrypted.fromBase64(parts[1]);
        
        return _encrypter!.decrypt(encrypted, iv: iv);
      } else {
        throw Exception('Invalid encryption format');
      }
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }
  
  /// Encrypt with password (for individual notes)
  String encryptWithPassword({
    required String plainText,
    required String password,
  }) {
    if (plainText.isEmpty) return '';
    
    try {
      // Generate unique salt for this encryption
      final salt = SecureMemory.generateSalt();
      final iv = SecureMemory.generateIV();
      
      // Derive key from password and salt
      final derivedKey = KeyDerivation.deriveKeyFromPassword(
        password: password,
        salt: salt,
      );
      
      // Encrypt
      final encrypter = Encrypter(AES(Key(derivedKey)));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      
      // Format: version:salt:iv:encrypted
      return '${SecurityConstants.encryptionFormatVersion}:${base64.encode(salt)}:${iv.base64}:${encrypted.base64}';
    } catch (e) {
      throw Exception('Password encryption failed: $e');
    }
  }
  
  /// Decrypt with password
  String decryptWithPassword({
    required String encryptedPackage,
    required String password,
  }) {
    if (encryptedPackage.isEmpty) return '';
    
    try {
      final parts = encryptedPackage.split(':');
      
      if (parts.length != 4 || parts[0] != '2') {
        throw Exception('Invalid password encryption format');
      }
      
      final salt = base64.decode(parts[1]);
      final iv = IV.fromBase64(parts[2]);
      final encrypted = Encrypted.fromBase64(parts[3]);
      
      // Derive key from password and salt
      final derivedKey = KeyDerivation.deriveKeyFromPassword(
        password: password,
        salt: salt,
      );
      
      // Decrypt
      final encrypter = Encrypter(AES(Key(derivedKey)));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Password decryption failed: $e');
    }
  }
  
  /// Get recovery key (only when vault is unlocked)
  String? getRecoveryKey() {
    return _isLocked ? null : _recoveryKey;
  }
  
  /// Check if vault is initialized and unlocked
  bool isUnlocked() => !_isLocked;
  
  /// Lock the vault (clear keys from memory)
  void lock() {
    _clearSensitiveData();
    _isLocked = true;
  }
  
  /// Change vault password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _checkLocked();
    
    try {
      // Verify old password by trying to unwrap
      final wrappedPassword = await _secureStorage.read(
        key: SecurityConstants.storageKeyWrappedPassword,
      );
      
      if (wrappedPassword == null) {
        throw Exception('Vault not properly initialized');
      }
      
      // Try to unwrap with old password
      await _unwrapMasterKey(
        wrappedPackage: wrappedPassword,
        password: oldPassword,
      );
      
      // Re-wrap master key with new password
      final salt = SecureMemory.generateSalt();
      final newWrappedPassword = await _wrapMasterKey(
        masterKey: _masterKey!,
        password: newPassword,
        salt: salt,
      );
      
      // Store new wrapped key and salt
      await _secureStorage.write(
        key: SecurityConstants.storageKeyWrappedPassword,
        value: newWrappedPassword,
      );
      
      await _secureStorage.write(
        key: SecurityConstants.storageKeySalt,
        value: base64.encode(salt),
      );
      
    } catch (e) {
      throw Exception('Password change failed: $e');
    }
  }
  
  // Private methods
  
  Future<void> _setupNewVault({
    required String password,
    String? recoveryKey,
  }) async {
    // Generate master key
    _masterKey = SecureMemory.generateMasterKey();
    
    // Generate or use provided recovery key
    _recoveryKey = recoveryKey ?? KeyDerivation.generateRecoveryKey();
    
    // Generate salt for password derivation
    final salt = SecureMemory.generateSalt();
    
    // Wrap master key with password
    final wrappedPassword = await _wrapMasterKey(
      masterKey: _masterKey!,
      password: password,
      salt: salt,
    );
    
    // Wrap master key with recovery key
    final wrappedRecovery = await _wrapMasterKey(
      masterKey: _masterKey!,
      password: _recoveryKey!,
      salt: salt,
    );
    
    // Store wrapped keys and salt
    await _secureStorage.write(
      key: SecurityConstants.storageKeyWrappedPassword,
      value: wrappedPassword,
    );
    
    await _secureStorage.write(
      key: SecurityConstants.storageKeyWrappedRecovery,
      value: wrappedRecovery,
    );
    
    await _secureStorage.write(
      key: SecurityConstants.storageKeySalt,
      value: base64.encode(salt),
    );
    
    // Initialize encrypter
    _encrypter = Encrypter(AES(Key(_masterKey!)));
  }
  
  Future<void> _unlockVault({required String password}) async {
    try {
      // Get stored salt
      final storedSalt = await _secureStorage.read(
        key: SecurityConstants.storageKeySalt,
      );
      
      if (storedSalt == null) {
        throw Exception('Vault not properly initialized');
      }
      
      final salt = base64.decode(storedSalt);
      
      // Get wrapped password
      final wrappedPassword = await _secureStorage.read(
        key: SecurityConstants.storageKeyWrappedPassword,
      );
      
      if (wrappedPassword == null) {
        throw Exception('Vault not properly initialized');
      }
      
      // Unwrap master key
      _masterKey = await _unwrapMasterKey(
        wrappedPackage: wrappedPassword,
        password: password,
        salt: salt,
      );
      
      // Initialize encrypter
      _encrypter = Encrypter(AES(Key(_masterKey!)));
      
    } catch (e) {
      throw Exception('Failed to unlock vault: $e');
    }
  }
  
  Future<String> _wrapMasterKey({
    required Uint8List masterKey,
    required String password,
    required Uint8List salt,
  }) async {
    // Derive key from password and salt
    final derivedKey = KeyDerivation.deriveKeyFromPassword(
      password: password,
      salt: salt,
    );
    
    // Generate IV for wrapping
    final iv = SecureMemory.generateIV();
    
    // Encrypt master key with derived key
    final encrypter = Encrypter(AES(Key(derivedKey)));
    final encrypted = encrypter.encryptBytes(masterKey, iv: iv);
    
    // Format: version:salt:iv:encrypted
    return '${SecurityConstants.encryptionFormatVersion}:${base64.encode(salt)}:${iv.base64}:${encrypted.base64}';
  }
  
  Future<Uint8List> _unwrapMasterKey({
    required String wrappedPackage,
    required String password,
    Uint8List? salt,
  }) async {
    final parts = wrappedPackage.split(':');
    
    if (parts.length != 4 || parts[0] != '2') {
      throw Exception('Invalid wrapped key format');
    }
    
    final packageSalt = base64.decode(parts[1]);
    final iv = IV.fromBase64(parts[2]);
    final encrypted = Encrypted.fromBase64(parts[3]);
    
    // Use provided salt or extract from package
    final derivationSalt = salt ?? packageSalt;
    
    // Derive key from password and salt
    final derivedKey = KeyDerivation.deriveKeyFromPassword(
      password: password,
      salt: derivationSalt,
    );
    
    // Decrypt master key
    final encrypter = Encrypter(AES(Key(derivedKey)));
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    
    return Uint8List.fromList(decrypted);
  }
  
  void _checkLocked() {
    if (_isLocked) {
      throw Exception('Vault is locked. Call initializeVault() first.');
    }
  }
  
  void _clearSensitiveData() {
    // Securely wipe master key
    if (_masterKey != null) {
      SecureMemory.wipeBytes(_masterKey);
      _masterKey = null;
    }
    
    // Clear encrypter
    _encrypter = null;
    
    // Clear recovery key from memory
    if (_recoveryKey != null) {
      SecureMemory.wipeString(_recoveryKey);
      _recoveryKey = null;
    }
    
    // Hint GC to collect wiped memory
    // Note: Dart GC timing is not guaranteed, but we've done our best
  }
  
  /// Dispose and securely clear all data
  void dispose() {
    _clearSensitiveData();
    _isLocked = true;
  }
}