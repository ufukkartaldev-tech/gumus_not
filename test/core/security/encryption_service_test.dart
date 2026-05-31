import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/security/encryption_service.dart';

void main() {
  group('EnhancedEncryptionService Tests', () {
    late EnhancedEncryptionService encryptionService;
    
    setUp(() {
      encryptionService = EnhancedEncryptionService.instance;
    });
    
    tearDown(() {
      encryptionService.dispose();
    });
    
    test('Singleton instance works', () {
      final instance1 = EnhancedEncryptionService.instance;
      final instance2 = EnhancedEncryptionService.instance;
      
      expect(instance1, same(instance2));
    });
    
    test('Vault initialization and unlocking', () async {
      const password = 'testPassword123';
      
      // Initialize new vault
      await encryptionService.initializeVault(password: password);
      
      expect(encryptionService.isUnlocked(), isTrue);
      expect(encryptionService.getRecoveryKey(), isNotNull);
    });
    
    test('Encryption and decryption with master key', () async {
      const password = 'testPassword123';
      const plainText = 'This is a secret message';
      
      await encryptionService.initializeVault(password: password);
      
      // Encrypt
      final encrypted = encryptionService.encrypt(plainText);
      
      expect(encrypted, isNotEmpty);
      expect(encrypted, contains(':'));
      
      // Decrypt
      final decrypted = encryptionService.decrypt(encrypted);
      
      expect(decrypted, plainText);
    });
    
    test('Encryption with password (individual notes)', () async {
      const password = 'noteSpecificPassword';
      const plainText = 'Individual note content';
      
      // Encrypt with password
      final encrypted = encryptionService.encryptWithPassword(
        plainText: plainText,
        password: password,
      );
      
      expect(encrypted, isNotEmpty);
      expect(encrypted.split(':'), hasLength(4));
      
      // Decrypt with same password
      final decrypted = encryptionService.decryptWithPassword(
        encryptedPackage: encrypted,
        password: password,
      );
      
      expect(decrypted, plainText);
    });
    
    test('Password change', () async {
      const oldPassword = 'oldPassword123';
      const newPassword = 'newPassword456';
      const plainText = 'Test message';
      
      await encryptionService.initializeVault(password: oldPassword);
      
      // Encrypt something
      final encrypted = encryptionService.encrypt(plainText);
      
      // Change password
      await encryptionService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      
      // Lock and unlock with new password
      encryptionService.lock();
      
      await encryptionService.initializeVault(password: newPassword);
      
      // Should still be able to decrypt
      final decrypted = encryptionService.decrypt(encrypted);
      expect(decrypted, plainText);
    });
    
    test('Recovery key initialization', () async {
      const recoveryKey = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
      const plainText = 'Recovery test';
      
      // Initialize with recovery key
      await encryptionService.initializeVault(
        password: 'password',
        recoveryKey: recoveryKey,
      );
      
      // Lock vault
      encryptionService.lock();
      
      // Unlock with recovery key
      final success = await encryptionService.initializeWithRecoveryKey(recoveryKey);
      
      expect(success, isTrue);
      expect(encryptionService.isUnlocked(), isTrue);
      
      // Should be able to encrypt/decrypt
      final encrypted = encryptionService.encrypt(plainText);
      final decrypted = encryptionService.decrypt(encrypted);
      
      expect(decrypted, plainText);
    });
    
    test('Invalid password throws exception', () async {
      const correctPassword = 'correctPassword';
      const wrongPassword = 'wrongPassword';
      
      await encryptionService.initializeVault(password: correctPassword);
      encryptionService.lock();
      
      expect(
        () async => await encryptionService.initializeVault(password: wrongPassword),
        throwsA(isA<Exception>()),
      );
    });
    
    test('Lock clears sensitive data', () async {
      const password = 'testPassword';
      const plainText = 'Sensitive data';
      
      await encryptionService.initializeVault(password: password);
      
      // Encrypt something
      final encrypted = encryptionService.encrypt(plainText);
      
      // Lock vault
      encryptionService.lock();
      
      expect(encryptionService.isUnlocked(), isFalse);
      expect(encryptionService.getRecoveryKey(), isNull);
      
      // Should not be able to encrypt/decrypt while locked
      expect(
        () => encryptionService.encrypt(plainText),
        throwsA(isA<Exception>()),
      );
      
      expect(
        () => encryptionService.decrypt(encrypted),
        throwsA(isA<Exception>()),
      );
    });
    
    test('Different salts produce different keys', () {
      const password = 'samePassword';
      const plainText = 'Test message';
      
      // Encrypt same text with same password twice
      final encrypted1 = encryptionService.encryptWithPassword(
        plainText: plainText,
        password: password,
      );
      
      final encrypted2 = encryptionService.encryptWithPassword(
        plainText: plainText,
        password: password,
      );
      
      // Should be different due to different salts
      expect(encrypted1, isNot(encrypted2));
      
      // But both should decrypt to same plaintext
      final decrypted1 = encryptionService.decryptWithPassword(
        encryptedPackage: encrypted1,
        password: password,
      );
      
      final decrypted2 = encryptionService.decryptWithPassword(
        encryptedPackage: encrypted2,
        password: password,
      );
      
      expect(decrypted1, plainText);
      expect(decrypted2, plainText);
    });
    
    test('Encryption format versioning', () async {
      const password = 'testPassword';
      const plainText = 'Version test';
      
      await encryptionService.initializeVault(password: password);
      
      final encrypted = encryptionService.encrypt(plainText);
      final parts = encrypted.split(':');
      
      // Should have version 2 format
      expect(parts[0], '2');
      expect(parts, hasLength(3)); // version:iv:encrypted
    });
    
    test('Password encryption format', () {
      const password = 'testPassword';
      const plainText = 'Format test';
      
      final encrypted = encryptionService.encryptWithPassword(
        plainText: plainText,
        password: password,
      );
      
      final parts = encrypted.split(':');
      
      // Should have version 2 format with salt
      expect(parts[0], '2');
      expect(parts, hasLength(4)); // version:salt:iv:encrypted
    });
  });
}