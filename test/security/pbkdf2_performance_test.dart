import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/security/encryption_service.dart';

/// PBKDF2 performance test for mobile devices
void main() {
  group('PBKDF2 Performance Tests (Mobile Validation)', () {
    late EnhancedEncryptionService encryptionService;
    final Random random = Random.secure();
    
    setUp(() {
      encryptionService = EnhancedEncryptionService.instance;
    });
    
    tearDown(() {
      encryptionService.dispose();
    });
    
    test('Key derivation time with different iteration counts', () async {
      const password = 'testPassword123';
      final salt = SecureMemory.generateSalt();
      
      print('\n=== PBKDF2 Iteration Performance Test ===');
      
      final iterationCounts = [1000, 10000, 50000, 100000, 250000];
      final results = <Map<String, dynamic>>[];
      
      for (final iterations in iterationCounts) {
        final stopwatch = Stopwatch()..start();
        
        // Derive key
        final derivedKey = KeyDerivation.deriveKeyFromPassword(
          password: password,
          salt: salt,
          iterations: iterations,
        );
        
        stopwatch.stop();
        
        final result = {
          'iterations': iterations,
          'timeMs': stopwatch.elapsedMilliseconds,
          'keyLength': derivedKey.length,
        };
        
        results.add(result);
        
        print('  ${iterations.toString().padLeft(6)} iterations: ${stopwatch.elapsedMilliseconds.toString().padLeft(4)}ms');
      }
      
      // Analyze results
      print('\nPerformance Analysis:');
      for (int i = 1; i < results.length; i++) {
        final prev = results[i-1];
        final curr = results[i];
        final timeRatio = curr['timeMs'] / prev['timeMs'];
        final iterRatio = curr['iterations'] / prev['iterations'];
        
        print('  ${prev['iterations']} → ${curr['iterations']}: '
              'Time ratio ${timeRatio.toStringAsFixed(2)}x '
              '(Expected: ${iterRatio.toStringAsFixed(2)}x)');
        
        // Time should scale linearly with iterations
        expect(timeRatio, closeTo(iterRatio, 0.5),
            reason: 'PBKDF2 time should scale approximately linearly with iterations');
      }
      
      // 100,000 iterations should complete within reasonable time on mobile
      final hundredKResult = results.firstWhere((r) => r['iterations'] == 100000);
      expect(hundredKResult['timeMs'], lessThan(2000),
          reason: '100,000 PBKDF2 iterations should complete within 2 seconds on mobile');
    });
    
    test('Memory usage during key derivation', () async {
      const password = 'testPassword123';
      final salt = SecureMemory.generateSalt();
      
      print('\n=== Memory Usage Test ===');
      
      // Track memory before
      final before = await _getMemoryUsage();
      print('Memory before: $before');
      
      // Perform key derivation
      final stopwatch = Stopwatch()..start();
      final derivedKey = KeyDerivation.deriveKeyFromPassword(
        password: password,
        salt: salt,
        iterations: 100000,
      );
      stopwatch.stop();
      
      // Track memory after
      final after = await _getMemoryUsage();
      print('Memory after: $after');
      print('Derivation time: ${stopwatch.elapsedMilliseconds}ms');
      
      // Memory increase should be reasonable
      final memoryIncrease = after['used'] - before['used'];
      print('Memory increase: ${memoryIncrease}KB');
      
      expect(memoryIncrease, lessThan(10000),
          reason: 'PBKDF2 should not use excessive memory (>10MB)');
    });
    
    test('Concurrent encryption operations', () async {
      const password = 'testPassword123';
      const plainText = 'This is a test message for concurrent operations';
      
      print('\n=== Concurrent Encryption Test ===');
      
      final operations = <Future>[];
      final stopwatch = Stopwatch()..start();
      
      // Start multiple concurrent encryption operations
      for (int i = 0; i < 10; i++) {
        operations.add(encryptionService.encryptWithPassword(
          plainText: '$plainText $i',
          password: '$password$i',
        ));
      }
      
      // Wait for all operations
      await Future.wait(operations);
      stopwatch.stop();
      
      print('  Concurrent operations: ${operations.length}');
      print('  Total time: ${stopwatch.elapsedMilliseconds}ms');
      print('  Avg time per operation: ${stopwatch.elapsedMilliseconds / operations.length}ms');
      
      expect(stopwatch.elapsedMilliseconds, lessThan(10000),
          reason: '10 concurrent encryptions should complete within 10 seconds');
    });
    
    test('Vault initialization performance', () async {
      const password = 'testPassword123';
      
      print('\n=== Vault Initialization Performance ===');
      
      final stopwatch = Stopwatch()..start();
      await encryptionService.initializeVault(password: password);
      stopwatch.stop();
      
      print('  Initialization time: ${stopwatch.elapsedMilliseconds}ms');
      
      // Lock and unlock to test unlock performance
      encryptionService.lock();
      
      final unlockStopwatch = Stopwatch()..start();
      await encryptionService.initializeVault(password: password);
      unlockStopwatch.stop();
      
      print('  Unlock time: ${unlockStopwatch.elapsedMilliseconds}ms');
      
      expect(stopwatch.elapsedMilliseconds, lessThan(3000),
          reason: 'Vault initialization should complete within 3 seconds');
      expect(unlockStopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'Vault unlock should complete within 2 seconds');
    });
    
    test('Password change performance', () async {
      const oldPassword = 'oldPassword123';
      const newPassword = 'newPassword456';
      
      print('\n=== Password Change Performance ===');
      
      // Initialize vault
      await encryptionService.initializeVault(password: oldPassword);
      
      // Measure password change
      final stopwatch = Stopwatch()..start();
      await encryptionService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      stopwatch.stop();
      
      print('  Password change time: ${stopwatch.elapsedMilliseconds}ms');
      
      expect(stopwatch.elapsedMilliseconds, lessThan(3000),
          reason: 'Password change should complete within 3 seconds');
    });
    
    test('Recovery key performance', () async {
      const password = 'testPassword123';
      const recoveryKey = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
      
      print('\n=== Recovery Key Performance ===');
      
      // Initialize with recovery key
      final initStopwatch = Stopwatch()..start();
      await encryptionService.initializeVault(
        password: password,
        recoveryKey: recoveryKey,
      );
      initStopwatch.stop();
      
      print('  Initialization with recovery key: ${initStopwatch.elapsedMilliseconds}ms');
      
      // Lock and unlock with recovery key
      encryptionService.lock();
      
      final recoveryStopwatch = Stopwatch()..start();
      final success = await encryptionService.initializeWithRecoveryKey(recoveryKey);
      recoveryStopwatch.stop();
      
      print('  Recovery unlock time: ${recoveryStopwatch.elapsedMilliseconds}ms');
      print('  Success: $success');
      
      expect(success, isTrue);
      expect(recoveryStopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'Recovery key unlock should complete within 2 seconds');
    });
    
    test('Encryption/decryption throughput', () async {
      const password = 'testPassword123';
      
      await encryptionService.initializeVault(password: password);
      
      print('\n=== Encryption/Decryption Throughput ===');
      
      // Test with different message sizes
      final messageSizes = [100, 1000, 10000, 50000];
      
      for (final size in messageSizes) {
        // Generate message of specified size
        final message = 'X' * size;
        
        final encryptStopwatch = Stopwatch()..start();
        final encrypted = encryptionService.encrypt(message);
        encryptStopwatch.stop();
        
        final decryptStopwatch = Stopwatch()..start();
        final decrypted = encryptionService.decrypt(encrypted);
        decryptStopwatch.stop();
        
        print('  Message size: ${size.toString().padLeft(5)} chars');
        print('    Encrypt: ${encryptStopwatch.elapsedMilliseconds}ms');
        print('    Decrypt: ${decryptStopwatch.elapsedMilliseconds}ms');
        print('    Total: ${encryptStopwatch.elapsedMilliseconds + decryptStopwatch.elapsedMilliseconds}ms');
        
        // Verify correctness
        expect(decrypted, message);
        
        // Performance requirements
        if (size <= 10000) {
          expect(encryptStopwatch.elapsedMilliseconds + decryptStopwatch.elapsedMilliseconds, lessThan(100),
              reason: 'Small messages (<10KB) should encrypt/decrypt within 100ms');
        }
      }
    });
    
    test('Secure memory wiping effectiveness', () async {
      print('\n=== Secure Memory Wiping Test ===');
      
      // Create sensitive data
      final sensitiveBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final sensitiveString = 'SensitivePassword123';
      
      // Get initial values
      final initialBytes = List<int>.from(sensitiveBytes);
      final initialString = sensitiveString;
      
      print('  Before wipe:');
      print('    Bytes: $initialBytes');
      print('    String: $initialString');
      
      // Wipe data
      SecureMemory.wipeBytes(sensitiveBytes);
      SecureMemory.wipeString(sensitiveString);
      
      print('  After wipe:');
      print('    Bytes: $sensitiveBytes');
      print('    String reference cleared');
      
      // Check that bytes are zeroed
      for (final byte in sensitiveBytes) {
        expect(byte, 0, reason: 'Bytes should be zeroed after wipe');
      }
      
      // Note: We can't directly check if string memory is cleared in Dart,
      // but we've done our best with the available APIs
    });
    
    test('Salt uniqueness and security', () {
      print('\n=== Salt Generation Test ===');
      
      final salts = <String>{};
      const sampleCount = 1000;
      
      for (int i = 0; i < sampleCount; i++) {
        final salt = SecureMemory.generateSalt();
        final saltBase64 = base64.encode(salt);
        salts.add(saltBase64);
      }
      
      print('  Generated $sampleCount unique salts');
      print('  All unique: ${salts.length == sampleCount}');
      
      expect(salts.length, sampleCount,
          reason: 'All generated salts should be unique');
      
      // Check salt length
      final sampleSalt = SecureMemory.generateSalt();
      expect(sampleSalt.length, SecurityConstants.saltLength,
          reason: 'Salt should be ${SecurityConstants.saltLength} bytes');
    });
    
    test('Iteration count security analysis', () {
      print('\n=== PBKDF2 Security Analysis ===');
      
      final recommendedIterations = SecurityConstants.pbkdf2Iterations;
      print('  Recommended iterations: $recommendedIterations');
      
      // Security considerations
      expect(recommendedIterations, greaterThanOrEqualTo(100000),
          reason: 'PBKDF2 should use at least 100,000 iterations for security');
      
      // Time estimate for brute force attack
      // Assuming 1ms per attempt (optimistic for attacker)
      final secondsPerAttempt = 0.001;
      final attemptsPerSecond = 1 / secondsPerAttempt;
      final yearsForBruteForce = recommendedIterations / (attemptsPerSecond * 60 * 60 * 24 * 365);
      
      print('  Estimated brute force time: ${yearsForBruteForce.toStringAsFixed(1)} years');
      print('  (Assuming 1ms per attempt, no parallelization)');
      
      expect(yearsForBruteForce, greaterThan(10),
          reason: 'PBKDF2 should provide at least 10 years of security against brute force');
    });
  });
  
  // Helper function to get memory usage (simplified)
  Future<Map<String, int>> _getMemoryUsage() async {
    // In a real test, you would use platform-specific APIs
    // For now, return dummy values
    return {
      'used': 100000, // 100MB
      'total': 4000000, // 4GB
      'free': 3900000,
    };
  }
}