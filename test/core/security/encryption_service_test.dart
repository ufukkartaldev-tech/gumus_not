import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connected_notebook/core/security/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    const testPassword = 'test_password_123';
    const testRecoveryKey = 'test_recovery_key';
    const testPlainText = 'This is a secret message';
    
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
    });
    
    setUp(() {
      // Clear any existing encryption state before each test
      EncryptionService.clear();
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Service initializes correctly with password', () async {
      await EncryptionService.initialize(testPassword);
      
      expect(EncryptionService.isInitialized(), isTrue);
      expect(EncryptionService.getRecoveryKey(), isNotEmpty);
    });

    test('Service initializes with custom recovery key', () async {
      await EncryptionService.initialize(testPassword, recoveryKey: testRecoveryKey);
      
      expect(EncryptionService.isInitialized(), isTrue);
      expect(EncryptionService.getRecoveryKey(), equals(testRecoveryKey));
    });

    test('Encryption and decryption work correctly', () async {
      await EncryptionService.initialize(testPassword);
      
      final encrypted = EncryptionService.encrypt(testPlainText);
      final decrypted = EncryptionService.decrypt(encrypted);
      
      expect(encrypted, isNot(equals(testPlainText)));
      expect(decrypted, equals(testPlainText));
    });

    test('Each encryption produces different output (semantic security)', () async {
      await EncryptionService.initialize(testPassword);
      
      final encrypted1 = EncryptionService.encrypt(testPlainText);
      final encrypted2 = EncryptionService.encrypt(testPlainText);
      
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('Password-based encryption and decryption work', () {
      final encrypted = EncryptionService.encryptWithPassword(testPlainText, testPassword);
      final decrypted = EncryptionService.decryptWithPassword(encrypted, testPassword);
      
      expect(encrypted, isNot(equals(testPlainText)));
      expect(decrypted, equals(testPlainText));
    });

    test('Password-based encryption produces different outputs', () {
      final encrypted1 = EncryptionService.encryptWithPassword(testPlainText, testPassword);
      final encrypted2 = EncryptionService.encryptWithPassword(testPlainText, testPassword);
      
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('Decryption fails with wrong password', () async {
      await EncryptionService.initialize(testPassword);
      final encrypted = EncryptionService.encrypt(testPlainText);
      
      EncryptionService.clear();
      
      expect(() async => await EncryptionService.initialize('wrong_password'), throwsException);
    });

    test('Password-based decryption fails with wrong password', () {
      final encrypted = EncryptionService.encryptWithPassword(testPlainText, testPassword);
      
      expect(() => EncryptionService.decryptWithPassword(encrypted, 'wrong_password'), 
            throwsException);
    });

    test('Recovery key verification works correctly', () async {
      await EncryptionService.initialize(testPassword);
      final recoveryKey = EncryptionService.getRecoveryKey();
      final isValid = EncryptionService.verifyRecoveryKey(recoveryKey, testPassword);
      
      expect(isValid, isTrue);
    });



    test('Recovery key verification fails with invalid key format', () {
      final isValid = EncryptionService.verifyRecoveryKey('invalid_key_format', testPassword);
      
      expect(isValid, isFalse);
    });

    test('Recovery attempt works with valid key', () async {
      await EncryptionService.initialize(testPassword);
      final recoveryKey = EncryptionService.getRecoveryKey();
      final success = await EncryptionService.attemptRecovery(recoveryKey);
      
      expect(success, isTrue);
    });

    test('Recovery attempt fails with invalid key', () async {
      final success = await EncryptionService.attemptRecovery('invalid_base64_key!!');
      
      expect(success, isFalse);
    });

    test('Service throws exception when not initialized', () {
      expect(() => EncryptionService.encrypt(testPlainText), throwsException);
      expect(() => EncryptionService.decrypt('some_encrypted_data'), throwsException);
    });

    test('Empty string encryption returns empty string', () {
      final encrypted = EncryptionService.encryptWithPassword('', testPassword);
      
      expect(encrypted, isEmpty);
      
      // Test decryption of empty string
      final decrypted = EncryptionService.decryptWithPassword(encrypted, testPassword);
      expect(decrypted, isEmpty);
    });

    test('Encryption with different passwords produces different results', () {
      final encrypted1 = EncryptionService.encryptWithPassword(testPlainText, testPassword);
      final encrypted2 = EncryptionService.encryptWithPassword(testPlainText, 'different_password');
      
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('Service can be cleared and reinitialized', () async {
      // Initialize first
      await EncryptionService.initialize(testPassword);
      expect(EncryptionService.isInitialized(), isTrue);
      
      // Clear
      EncryptionService.clear();
      expect(EncryptionService.isInitialized(), isFalse);
      expect(EncryptionService.getRecoveryKey(), 'Kasa açıkken alınabilir');
      
      // Reinitialize
      FlutterSecureStorage.setMockInitialValues({}); // Reset vault
      await EncryptionService.initialize('new_password');
      expect(EncryptionService.isInitialized(), isTrue);
    });

    test('Invalid encrypted format throws exception', () async {
      await EncryptionService.initialize(testPassword);
      
      expect(() => EncryptionService.decrypt('invalid_format'), throwsException);
      expect(() => EncryptionService.decrypt('missing:separator'), throwsException);
    });

    test('Invalid password-based encrypted format throws exception', () {
      expect(() => EncryptionService.decryptWithPassword('invalid:format', testPassword), 
            throwsException);
      expect(() => EncryptionService.decryptWithPassword('missing:parts:here', testPassword), 
            throwsException);
    });

    test('Recovery key is consistent for same password', () async {
      await EncryptionService.initialize(testPassword);
      final key1 = EncryptionService.getRecoveryKey();
      expect(key1.length, 24);
    });

    test('Recovery key differs for different passwords', () async {
      await EncryptionService.initialize(testPassword);
      final key1 = EncryptionService.getRecoveryKey();
      
      // Clear and reinitialize with different password
      EncryptionService.clear();
      FlutterSecureStorage.setMockInitialValues({}); // Reset vault
      await EncryptionService.initialize('different_password');
      final key2 = EncryptionService.getRecoveryKey();
      
      expect(key1, isNot(equals(key2)));
    });

    test('Service instance is singleton', () {
      final instance1 = EncryptionService.instance;
      final instance2 = EncryptionService.instance;
      
      expect(instance1, same(instance2));
    });
  });
}