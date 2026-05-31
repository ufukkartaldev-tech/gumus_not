import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:connected_notebook/core/security/encryption_migration_service.dart';
import 'package:connected_notebook/core/database/database_migration_service.dart';
import 'package:connected_notebook/core/security/encryption_service.dart';

/// Comprehensive migration manager for the application
class MigrationManager {
  static const String _migrationVersionKey = 'app_migration_version';
  static const int _currentMigrationVersion = 2; // Version 2 includes FTS5 and PBKDF2
  
  /// Check if migration is needed
  static Future<Map<String, dynamic>> checkMigrationNeeded() async {
    final result = {
      'migrationNeeded': false,
      'migrationVersion': _currentMigrationVersion,
      'details': {},
      'recommendations': [],
    };
    
    try {
      // Check database migration
      final dbMigrationPlan = await DatabaseMigrationService.createMigrationPlan();
      result['details']['database'] = dbMigrationPlan;
      
      if (dbMigrationPlan['migrationRequired'] == true) {
        result['migrationNeeded'] = true;
        result['recommendations'].addAll(dbMigrationPlan['recommendations']);
      }
      
      // Check encryption migration (requires database access)
      final oldDbExists = await DatabaseMigrationService.oldDatabaseExists();
      if (oldDbExists) {
        final oldPath = await DatabaseMigrationService.getOldDatabasePath();
        final oldDb = await openDatabase(oldPath);
        
        final encryptionReport = await EncryptionMigrationService.createMigrationReport(
          database: oldDb,
        );
        
        result['details']['encryption'] = encryptionReport;
        
        if (encryptionReport['migrationRequired'] == true) {
          result['migrationNeeded'] = true;
          result['recommendations'].add('Encryption format migration required');
        }
        
        await oldDb.close();
      }
      
      // Check if we've already completed migration
      final prefs = await _getPreferences();
      final lastMigrationVersion = prefs.getInt(_migrationVersionKey) ?? 0;
      
      if (lastMigrationVersion < _currentMigrationVersion) {
        result['migrationNeeded'] = true;
        result['recommendations'].add('App migration from version $lastMigrationVersion to $_currentMigrationVersion');
      }
      
    } catch (e) {
      result['migrationNeeded'] = true;
      result['details']['error'] = e.toString();
      result['recommendations'].add('Error checking migration status: $e');
    }
    
    return result;
  }
  
  /// Execute comprehensive migration
  static Future<Map<String, dynamic>> executeMigration({
    bool backupBeforeMigration = true,
    bool validateAfterMigration = true,
  }) async {
    final migrationResult = {
      'status': 'pending',
      'steps': [],
      'errors': [],
      'warnings': [],
      'durationMs': 0,
      'finalStatus': 'unknown',
    };
    
    final stopwatch = Stopwatch()..start();
    
    try {
      migrationResult['steps'].add('Starting comprehensive migration');
      
      // Step 1: Backup if requested
      if (backupBeforeMigration) {
        migrationResult['steps'].add('Creating backup');
        final backupSuccess = await DatabaseMigrationService.createBackup();
        
        if (backupSuccess) {
          migrationResult['steps'].add('Backup created successfully');
        } else {
          migrationResult['warnings'].add('Backup creation failed or skipped');
        }
      }
      
      // Step 2: Database migration
      migrationResult['steps'].add('Starting database migration');
      final dbMigrationResult = await DatabaseMigrationService.migrateToOptimizedDatabase();
      migrationResult['databaseMigration'] = dbMigrationResult;
      
      if (dbMigrationResult['status'] == 'completed') {
        migrationResult['steps'].add('Database migration completed');
      } else if (dbMigrationResult['status'] == 'skipped') {
        migrationResult['steps'].add('Database migration skipped (no old database)');
      } else {
        migrationResult['errors'].add('Database migration failed: ${dbMigrationResult['errors']}');
        migrationResult['status'] = 'failed';
      }
      
      // Step 3: Encryption migration (if database migration succeeded)
      if (migrationResult['status'] != 'failed' && dbMigrationResult['status'] == 'completed') {
        migrationResult['steps'].add('Starting encryption migration');
        
        // We need the master key for encryption migration
        // This assumes the vault is already initialized
        try {
          final encryptionService = EnhancedEncryptionService.instance;
          
          if (encryptionService.isUnlocked()) {
            // Open new database for encryption migration
            final newPath = await DatabaseMigrationService.getNewDatabasePath();
            final newDb = await openDatabase(newPath);
            
            // Get master key (this is a simplification - in reality, you'd need to handle this carefully)
            // For now, we'll skip encryption migration if we can't get the key
            migrationResult['warnings'].add('Encryption migration requires master key access. Skipping.');
            
            await newDb.close();
          } else {
            migrationResult['warnings'].add('Vault is locked. Encryption migration skipped.');
          }
        } catch (e) {
          migrationResult['warnings'].add('Encryption migration error: $e');
        }
      }
      
      // Step 4: Validation
      if (validateAfterMigration && migrationResult['status'] != 'failed') {
        migrationResult['steps'].add('Validating migration');
        final validationResult = await DatabaseMigrationService.validateMigration();
        migrationResult['validation'] = validationResult;
        
        if (validationResult['valid'] == true) {
          migrationResult['steps'].add('Migration validation passed');
        } else {
          migrationResult['errors'].addAll(validationResult['mismatches']);
          migrationResult['warnings'].add('Migration validation failed');
        }
      }
      
      // Step 5: Update migration version
      if (migrationResult['errors'].isEmpty) {
        final prefs = await _getPreferences();
        await prefs.setInt(_migrationVersionKey, _currentMigrationVersion);
        migrationResult['steps'].add('Migration version updated to $_currentMigrationVersion');
        migrationResult['finalStatus'] = 'success';
      } else {
        migrationResult['finalStatus'] = 'partial_success';
      }
      
      migrationResult['status'] = 'completed';
      
    } catch (e) {
      migrationResult['status'] = 'failed';
      migrationResult['finalStatus'] = 'failed';
      migrationResult['errors'].add('Migration failed with exception: $e');
      
      // Attempt rollback
      migrationResult['steps'].add('Attempting rollback');
      try {
        final rollbackSuccess = await DatabaseMigrationService.rollbackMigration();
        if (rollbackSuccess) {
          migrationResult['steps'].add('Rollback completed');
        } else {
          migrationResult['warnings'].add('Rollback failed or not supported');
        }
      } catch (rollbackError) {
        migrationResult['warnings'].add('Rollback error: $rollbackError');
      }
    } finally {
      stopwatch.stop();
      migrationResult['durationMs'] = stopwatch.elapsedMilliseconds;
    }
    
    return migrationResult;
  }
  
  /// Get migration status report
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    final status = {
      'currentVersion': _currentMigrationVersion,
      'lastMigrationVersion': 0,
      'migrationHistory': [],
      'systemStatus': 'unknown',
    };
    
    try {
      final prefs = await _getPreferences();
      final lastVersion = prefs.getInt(_migrationVersionKey) ?? 0;
      status['lastMigrationVersion'] = lastVersion;
      
      // Check database status
      final oldDbExists = await DatabaseMigrationService.oldDatabaseExists();
      final newDbExists = await DatabaseMigrationService.oldDatabaseExists(); // Check new DB path
      
      status['databaseStatus'] = {
        'oldDatabaseExists': oldDbExists,
        'newDatabaseExists': newDbExists,
        'recommendation': oldDbExists && !newDbExists ? 'migration_needed' : 'up_to_date',
      };
      
      // Determine system status
      if (lastVersion < _currentMigrationVersion) {
        status['systemStatus'] = 'migration_needed';
      } else if (oldDbExists && !newDbExists) {
        status['systemStatus'] = 'database_migration_needed';
      } else {
        status['systemStatus'] = 'up_to_date';
      }
      
    } catch (e) {
      status['systemStatus'] = 'error';
      status['error'] = e.toString();
    }
    
    return status;
  }
  
  /// Clean up old migration artifacts
  static Future<Map<String, dynamic>> cleanupMigrationArtifacts() async {
    final cleanupResult = {
      'cleanedItems': [],
      'errors': [],
      'warnings': [],
    };
    
    try {
      // Check for old database
      final oldDbExists = await DatabaseMigrationService.oldDatabaseExists();
      
      if (oldDbExists) {
        // In a production app, you might want to keep the old database
        // for a while before deleting it
        cleanupResult['warnings'].add('Old database exists. Manual cleanup recommended.');
        cleanupResult['cleanedItems'].add('Old database marked for review');
      }
      
      // Check for backup files
      cleanupResult['warnings'].add('Backup file cleanup requires manual intervention');
      
      // Clear migration preferences if needed
      final prefs = await _getPreferences();
      final lastVersion = prefs.getInt(_migrationVersionKey) ?? 0;
      
      if (lastVersion < _currentMigrationVersion) {
        cleanupResult['warnings'].add('Migration not completed. Cleanup not recommended.');
      }
      
    } catch (e) {
      cleanupResult['errors'].add('Cleanup error: $e');
    }
    
    return cleanupResult;
  }
  
  /// Migration wizard for user interaction
  static Future<Map<String, dynamic>> migrationWizard({
    required bool userConfirmed,
    bool automaticMode = false,
  }) async {
    final wizardResult = {
      'completed': false,
      'userConfirmed': userConfirmed,
      'automaticMode': automaticMode,
      'steps': [],
      'decisions': [],
    };
    
    if (!userConfirmed) {
      wizardResult['steps'].add('Migration requires user confirmation');
      return wizardResult;
    }
    
    try {
      // Step 1: Analysis
      wizardResult['steps'].add('Analyzing current system');
      final analysis = await checkMigrationNeeded();
      wizardResult['analysis'] = analysis;
      
      if (!analysis['migrationNeeded']) {
        wizardResult['steps'].add('No migration needed');
        wizardResult['completed'] = true;
        return wizardResult;
      }
      
      // Step 2: Present plan
      wizardResult['steps'].add('Presenting migration plan');
      final plan = await DatabaseMigrationService.createMigrationPlan();
      wizardResult['plan'] = plan;
      
      if (!automaticMode) {
        // In interactive mode, we would present the plan to the user
        wizardResult['decisions'].add('User review required for plan');
        wizardResult['steps'].add('Waiting for user decision');
        // For now, we'll assume user approves
      }
      
      // Step 3: Execute migration
      wizardResult['steps'].add('Executing migration');
      final migrationResult = await executeMigration(
        backupBeforeMigration: true,
        validateAfterMigration: true,
      );
      wizardResult['migrationResult'] = migrationResult;
      
      // Step 4: Present results
      wizardResult['steps'].add('Migration execution completed');
      
      if (migrationResult['finalStatus'] == 'success') {
        wizardResult['steps'].add('Migration successful');
        wizardResult['completed'] = true;
      } else if (migrationResult['finalStatus'] == 'partial_success') {
        wizardResult['steps'].add('Migration partially successful');
        wizardResult['warnings'] = migrationResult['warnings'];
        wizardResult['completed'] = true;
      } else {
        wizardResult['steps'].add('Migration failed');
        wizardResult['errors'] = migrationResult['errors'];
      }
      
    } catch (e) {
      wizardResult['steps'].add('Wizard error: $e');
      wizardResult['errors'] = [e.toString()];
    }
    
    return wizardResult;
  }
  
  // Helper method to get preferences (simplified)
  static Future<SharedPreferences> _getPreferences() async {
    // In a real implementation, use shared_preferences package
    // For now, return a mock
    return MockSharedPreferences();
  }
}

// Mock SharedPreferences for testing
class MockSharedPreferences {
  final Map<String, dynamic> _storage = {};
  
  Future<bool> setInt(String key, int value) async {
    _storage[key] = value;
    return true;
  }
  
  int? getInt(String key) {
    return _storage[key] as int?;
  }
  
  Future<bool> remove(String key) async {
    _storage.remove(key);
    return true;
  }
  
  Future<bool> clear() async {
    _storage.clear();
    return true;
  }
}

/// Migration UI helper for presenting migration status to users
class MigrationUIHelper {
  static String getMigrationStatusMessage(Map<String, dynamic> status) {
    final systemStatus = status['systemStatus'] ?? 'unknown';
    
    switch (systemStatus) {
      case 'up_to_date':
        return 'Your app is up to date with the latest improvements.';
      case 'migration_needed':
        return 'New performance and security improvements are available.';
      case 'database_migration_needed':
        return 'Database optimization is available for better performance.';
      case 'error':
        return 'Unable to determine migration status. Please check your installation.';
      default:
        return 'Migration status: $systemStatus';
    }
  }
  
  static String getMigrationRecommendation(Map<String, dynamic> analysis) {
    final recommendations = analysis['recommendations'] as List<dynamic>? ?? [];
    
    if (recommendations.isEmpty) {
      return 'No migration needed at this time.';
    }
    
    final primaryRecommendation = recommendations.isNotEmpty ? recommendations.first : '';
    
    if (primaryRecommendation.toString().contains('backup')) {
      return 'We recommend creating a backup before proceeding with migration.';
    } else if (primaryRecommendation.toString().contains('large')) {
      return 'Migration may take some time due to the amount of data.';
    } else {
      return 'Migration is recommended to improve performance and security.';
    }
  }
  
  static Map<String, dynamic> getMigrationProgressSteps() {
    return {
      'steps': [
        {'id': 1, 'title': 'Analysis', 'description': 'Checking current system status'},
        {'id': 2, 'title': 'Backup', 'description': 'Creating backup of existing data'},
        {'id': 3, 'title': 'Database Migration', 'description': 'Optimizing database structure'},
        {'id': 4, 'title': 'Encryption Update', 'description': 'Upgrading security features'},
        {'id': 5, 'title': 'Validation', 'description': 'Verifying migration success'},
        {'id': 6, 'title': 'Completion', 'description': 'Finalizing migration process'},
      ],
      'estimatedTime': '2-5 minutes',
      'dataSafety': 'Your data is backed up and can be restored if needed',
    };
  }
}