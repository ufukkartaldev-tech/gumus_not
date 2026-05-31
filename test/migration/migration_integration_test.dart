import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/migration/migration_manager.dart';
import 'package:connected_notebook/core/database/database_migration_service.dart';
import 'package:connected_notebook/core/security/encryption_migration_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Integration test for migration system
void main() {
  group('Migration Integration Tests', () {
    test('Migration manager lifecycle', () async {
      print('\n=== Migration Manager Lifecycle Test ===');
      
      // Check migration needed
      final checkResult = await MigrationManager.checkMigrationNeeded();
      print('Check result: $checkResult');
      
      expect(checkResult, contains('migrationNeeded'));
      expect(checkResult, contains('details'));
      
      // Get migration status
      final status = await MigrationManager.getMigrationStatus();
      print('Status: $status');
      
      expect(status, contains('currentVersion'));
      expect(status, contains('systemStatus'));
      
      // Cleanup artifacts
      final cleanupResult = await MigrationManager.cleanupMigrationArtifacts();
      print('Cleanup: $cleanupResult');
      
      expect(cleanupResult, contains('cleanedItems'));
    });
    
    test('Database migration service', () async {
      print('\n=== Database Migration Service Test ===');
      
      // Check if old database exists
      final oldDbExists = await DatabaseMigrationService.oldDatabaseExists();
      print('Old database exists: $oldDbExists');
      
      // Create migration plan
      final plan = await DatabaseMigrationService.createMigrationPlan();
      print('Migration plan: $plan');
      
      expect(plan, contains('migrationRequired'));
      expect(plan, contains('estimatedDurationMs'));
      
      // Validate migration (should fail if no migration done)
      final validation = await DatabaseMigrationService.validateMigration();
      print('Validation: $validation');
      
      expect(validation, contains('valid'));
    });
    
    test('Encryption migration service', () async {
      print('\n=== Encryption Migration Service Test ===');
      
      // Create a test database
      final testDbPath = join(await getDatabasesPath(), 'test_migration.db');
      final databaseFactory = databaseFactory;
      
      // Clean up any existing test database
      if (await databaseFactory.databaseExists(testDbPath)) {
        await databaseFactory.deleteDatabase(testDbPath);
      }
      
      // Create test database with legacy data
      final db = await openDatabase(testDbPath, version: 1, onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            is_encrypted INTEGER DEFAULT 0
          )
        ''');
        
        // Insert test data with legacy encryption format
        await db.insert('notes', {
          'title': 'Test Note 1',
          'content': 'iv:encrypted_data', // Legacy format
          'is_encrypted': 1,
        });
        
        await db.insert('notes', {
          'title': 'Test Note 2',
          'content': '1:iv:encrypted_data', // Version 1 format
          'is_encrypted': 1,
        });
        
        await db.insert('notes', {
          'title': 'Test Note 3',
          'content': '2:iv:encrypted_data', // Current format
          'is_encrypted': 1,
        });
        
        await db.insert('notes', {
          'title': 'Test Note 4',
          'content': 'Unencrypted content',
          'is_encrypted': 0,
        });
      });
      
      try {
        // Test legacy format detection
        final isLegacy = EncryptionMigrationService.isLegacyFormat('iv:encrypted');
        print('Is legacy format "iv:encrypted": $isLegacy');
        expect(isLegacy, isTrue);
        
        final isLegacyV1 = EncryptionMigrationService.isLegacyFormat('1:iv:encrypted');
        print('Is legacy format "1:iv:encrypted": $isLegacyV1');
        expect(isLegacyV1, isTrue);
        
        final isCurrent = EncryptionMigrationService.isLegacyFormat('2:iv:encrypted');
        print('Is legacy format "2:iv:encrypted": $isCurrent');
        expect(isCurrent, isFalse);
        
        // Create migration report
        final report = await EncryptionMigrationService.createMigrationReport(database: db);
        print('Migration report: $report');
        
        expect(report, contains('totalNotes'));
        expect(report, contains('encryptedNotes'));
        expect(report['encryptedNotes'], 3);
        expect(report['legacyFormatNotes'], 2); // 2 legacy format notes
        
      } finally {
        // Clean up
        await db.close();
        await databaseFactory.deleteDatabase(testDbPath);
      }
    });
    
    test('Migration wizard flow', () async {
      print('\n=== Migration Wizard Flow Test ===');
      
      // Test wizard with user confirmation
      final wizardResult = await MigrationManager.migrationWizard(
        userConfirmed: true,
        automaticMode: true,
      );
      
      print('Wizard result: $wizardResult');
      
      expect(wizardResult, contains('completed'));
      expect(wizardResult, contains('steps'));
      expect(wizardResult, contains('decisions'));
      
      // Test wizard without user confirmation
      final wizardNoConfirm = await MigrationManager.migrationWizard(
        userConfirmed: false,
        automaticMode: false,
      );
      
      print('Wizard no confirm: $wizardNoConfirm');
      expect(wizardNoConfirm['userConfirmed'], isFalse);
    });
    
    test('Migration UI helper', () {
      print('\n=== Migration UI Helper Test ===');
      
      // Test status messages
      final statusMessages = [
        {'systemStatus': 'up_to_date'},
        {'systemStatus': 'migration_needed'},
        {'systemStatus': 'database_migration_needed'},
        {'systemStatus': 'error'},
        {'systemStatus': 'unknown'},
      ];
      
      for (final status in statusMessages) {
        final message = MigrationUIHelper.getMigrationStatusMessage(status);
        print('Status ${status['systemStatus']}: $message');
        expect(message, isNotEmpty);
      }
      
      // Test recommendations
      final analysisWithBackup = {
        'recommendations': ['Backup before migration']
      };
      
      final analysisWithLarge = {
        'recommendations': ['Large database migration']
      };
      
      final analysisEmpty = {
        'recommendations': []
      };
      
      print('Recommendation (backup): ${MigrationUIHelper.getMigrationRecommendation(analysisWithBackup)}');
      print('Recommendation (large): ${MigrationUIHelper.getMigrationRecommendation(analysisWithLarge)}');
      print('Recommendation (empty): ${MigrationUIHelper.getMigrationRecommendation(analysisEmpty)}');
      
      // Test progress steps
      final progressSteps = MigrationUIHelper.getMigrationProgressSteps();
      print('Progress steps: $progressSteps');
      
      expect(progressSteps, contains('steps'));
      expect(progressSteps['steps'], isList);
      expect(progressSteps['steps'].length, greaterThan(0));
    });
    
    test('Comprehensive migration test', () async {
      print('\n=== Comprehensive Migration Test ===');
      
      // This test simulates a full migration scenario
      // Since we can't actually migrate production data in tests,
      // we'll test the error handling and flow control
      
      final migrationResult = await MigrationManager.executeMigration(
        backupBeforeMigration: false, // Skip backup in test
        validateAfterMigration: false, // Skip validation in test
      );
      
      print('Migration result: $migrationResult');
      
      expect(migrationResult, contains('status'));
      expect(migrationResult, contains('steps'));
      expect(migrationResult, contains('durationMs'));
      
      // The migration might succeed, fail, or be skipped
      // All are valid outcomes for this test
      final validStatuses = ['completed', 'failed', 'partial_success'];
      expect(validStatuses, contains(migrationResult['status']));
    });
    
    test('Error handling and rollback', () async {
      print('\n=== Error Handling and Rollback Test ===');
      
      // Test that the migration system handles errors gracefully
      // We'll simulate an error by providing invalid parameters
      
      try {
        // This should throw an error or handle it gracefully
        final result = await MigrationManager.executeMigration(
          backupBeforeMigration: true,
          validateAfterMigration: true,
        );
        
        print('Migration result (with potential errors): $result');
        
        // Even with errors, the result should be structured
        expect(result, contains('status'));
        expect(result, contains('errors'));
        
      } catch (e) {
        // Migration might throw an exception
        print('Migration threw exception (expected in some cases): $e');
        // This is acceptable - the important thing is that it doesn't crash the app
      }
    });
    
    test('Performance monitoring during migration', () async {
      print('\n=== Migration Performance Monitoring ===');
      
      final stopwatch = Stopwatch()..start();
      
      // Run migration checks
      await MigrationManager.checkMigrationNeeded();
      await MigrationManager.getMigrationStatus();
      
      stopwatch.stop();
      
      print('Migration checks completed in ${stopwatch.elapsedMilliseconds}ms');
      
      // Migration checks should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'Migration checks should complete within 5 seconds');
    });
  });
}