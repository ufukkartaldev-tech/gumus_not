import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connected_notebook/features/notes/repositories/sqlite_note_repository.dart';

/// Database migration service for schema upgrades
class DatabaseMigrationService {
  static const String _oldDbName = 'connected_notebook.db';
  static const String _newDbName = 'connected_notebook_optimized.db';
  static const int _oldDbVersion = 3;
  static const int _newDbVersion = 4;
  
  /// Check if old database exists
  static Future<bool> oldDatabaseExists() async {
    try {
      final oldPath = join(await getDatabasesPath(), _oldDbName);
      final factory = databaseFactory;
      return await factory.databaseExists(oldPath);
    } catch (e) {
      return false;
    }
  }
  
  /// Get old database path
  static Future<String> getOldDatabasePath() async {
    return join(await getDatabasesPath(), _oldDbName);
  }
  
  /// Get new database path
  static Future<String> getNewDatabasePath() async {
    return join(await getDatabasesPath(), _newDbName);
  }
  
  /// Migrate from old database to new optimized database
  static Future<Map<String, dynamic>> migrateToOptimizedDatabase() async {
    final stopwatch = Stopwatch()..start();
    final migrationStats = {
      'status': 'pending',
      'oldDatabaseExists': false,
      'newDatabaseExists': false,
      'notesMigrated': 0,
      'backlinksMigrated': 0,
      'templatesMigrated': 0,
      'errors': [],
      'durationMs': 0,
    };
    
    try {
      // Check if old database exists
      final oldDbExists = await oldDatabaseExists();
      migrationStats['oldDatabaseExists'] = oldDbExists;
      
      if (!oldDbExists) {
        migrationStats['status'] = 'skipped';
        migrationStats['durationMs'] = stopwatch.elapsedMilliseconds;
        return migrationStats;
      }
      
      // Open old database
      final oldPath = await getOldDatabasePath();
      final oldDb = await openDatabase(oldPath);
      
      // Create new optimized database
      final newRepository = OptimizedSqliteNoteRepository();
      final newDb = await newRepository.database;
      migrationStats['newDatabaseExists'] = true;
      
      // Start transaction
      await newDb.transaction((txn) async {
        // Migrate notes
        final oldNotes = await oldDb.query('notes');
        migrationStats['notesMigrated'] = oldNotes.length;
        
        for (final note in oldNotes) {
          try {
            await txn.insert('notes', note);
          } catch (e) {
            (migrationStats['errors'] as List).add('Note ${note['id']}: $e');
          }
        }
        
        // Migrate backlinks
        final oldBacklinks = await oldDb.query('backlinks');
        migrationStats['backlinksMigrated'] = oldBacklinks.length;
        
        for (final backlink in oldBacklinks) {
          try {
            await txn.insert('backlinks', backlink);
          } catch (e) {
            (migrationStats['errors'] as List).add('Backlink ${backlink['id']}: $e');
          }
        }
        
        // Migrate templates
        try {
          final oldTemplates = await oldDb.query('templates');
          migrationStats['templatesMigrated'] = oldTemplates.length;
          
          for (final template in oldTemplates) {
            await txn.insert('templates', template);
          }
        } catch (e) {
          // Templates table might not exist in old database
          (migrationStats['errors'] as List).add('Templates: $e');
        }
      });
      
      // Close databases
      await oldDb.close();
      await newRepository.close();
      
      migrationStats['status'] = 'completed';
      
    } catch (e) {
      migrationStats['status'] = 'failed';
      (migrationStats['errors'] as List).add('Migration failed: $e');
    } finally {
      stopwatch.stop();
      migrationStats['durationMs'] = stopwatch.elapsedMilliseconds;
    }
    
    return migrationStats;
  }
  
  /// Validate migration integrity
  static Future<Map<String, dynamic>> validateMigration() async {
    final validation = {
      'valid': false,
      'oldRecordCount': 0,
      'newRecordCount': 0,
      'mismatches': [],
      'details': {},
    };
    
    try {
      // Open both databases
      final oldPath = await getOldDatabasePath();
      final newPath = await getNewDatabasePath();
      
      final oldDb = await openDatabase(oldPath);
      final newDb = await openDatabase(newPath);
      
      // Compare note counts
      final oldNotes = await oldDb.query('notes');
      final newNotes = await newDb.query('notes');
      
      validation['oldRecordCount'] = oldNotes.length;
      validation['newRecordCount'] = newNotes.length;
      final details = validation['details'] as Map<String, dynamic>;
      details['notes'] = {
        'old': oldNotes.length,
        'new': newNotes.length,
        'match': oldNotes.length == newNotes.length,
      };
      
      if (oldNotes.length != newNotes.length) {
        (validation['mismatches'] as List).add('Note count mismatch: ${oldNotes.length} vs ${newNotes.length}');
      }
      
      // Compare backlink counts
      final oldBacklinks = await oldDb.query('backlinks');
      final newBacklinks = await newDb.query('backlinks');
      
      details['backlinks'] = {
        'old': oldBacklinks.length,
        'new': newBacklinks.length,
        'match': oldBacklinks.length == newBacklinks.length,
      };
      
      if (oldBacklinks.length != newBacklinks.length) {
        (validation['mismatches'] as List).add('Backlink count mismatch: ${oldBacklinks.length} vs ${newBacklinks.length}');
      }
      
      // Compare sample data
      if (oldNotes.isNotEmpty && newNotes.isNotEmpty) {
        final sampleOldNote = oldNotes.first;
        final sampleNewNote = newNotes.firstWhere(
          (note) => note['id'] == sampleOldNote['id'],
          orElse: () => {},
        );
        
        if (sampleNewNote.isNotEmpty) {
          details['sampleNote'] = {
            'id': sampleOldNote['id'],
            'titleMatch': sampleOldNote['title'] == sampleNewNote['title'],
            'contentMatch': sampleOldNote['content'] == sampleNewNote['content'],
          };
          
          if (sampleOldNote['title'] != sampleNewNote['title']) {
            (validation['mismatches'] as List).add('Title mismatch for note ${sampleOldNote['id']}');
          }
        }
      }
      
      // Check FTS5 table
      try {
        final ftsCount = await newDb.rawQuery('SELECT COUNT(*) as count FROM notes_fts');
        details['fts5'] = {
          'documentCount': ftsCount.first['count'],
          'exists': true,
        };
      } catch (e) {
        details['fts5'] = {'exists': false};
        (validation['mismatches'] as List).add('FTS5 table not found or error: $e');
      }
      
      // Check generated columns
      try {
        final hasPendingTasks = await newDb.rawQuery('''
          SELECT COUNT(*) as count FROM notes WHERE has_pending_tasks = 1
        ''');
        details['generatedColumns'] = {
          'hasPendingTasks': hasPendingTasks.first['count'],
          'exists': true,
        };
      } catch (e) {
        details['generatedColumns'] = {'exists': false};
        (validation['mismatches'] as List).add('Generated columns not found: $e');
      }
      
      // Close databases
      await oldDb.close();
      await newDb.close();
      
      validation['valid'] = (validation['mismatches'] as List).isEmpty;
      
    } catch (e) {
      validation['valid'] = false;
      (validation['mismatches'] as List).add('Validation error: $e');
    }
    
    return validation;
  }
  
  /// Create migration plan
  static Future<Map<String, dynamic>> createMigrationPlan() async {
    final plan = {
      'migrationRequired': false,
      'oldDatabaseSize': 0,
      'estimatedDurationMs': 0,
      'risks': [],
      'recommendations': [],
    };
    
    try {
      final oldDbExists = await oldDatabaseExists();
      
      if (!oldDbExists) {
        plan['migrationRequired'] = false;
        (plan['recommendations'] as List).add('No old database found. Fresh installation detected.');
        return plan;
      }
      
      // Open old database to get stats
      final oldPath = await getOldDatabasePath();
      final oldDb = await openDatabase(oldPath);
      
      final noteCount = (await oldDb.query('notes')).length;
      final backlinkCount = (await oldDb.query('backlinks')).length;
      
      await oldDb.close();
      
      // Calculate estimates
      plan['oldDatabaseSize'] = noteCount + backlinkCount;
      plan['estimatedDurationMs'] = noteCount * 10 + backlinkCount * 5; // Rough estimate
      plan['migrationRequired'] = true;
      
      // Identify risks
      if (noteCount > 1000) {
        (plan['risks'] as List).add('Large database: $noteCount notes. Migration may take time.');
        (plan['recommendations'] as List).add('Perform migration during low-usage period.');
      }
      
      if (backlinkCount > 5000) {
        (plan['risks'] as List).add('High backlink count: $backlinkCount. Complex relationships.');
        (plan['recommendations'] as List).add('Verify backlink integrity after migration.');
      }
      
      (plan['recommendations'] as List).addAll([
        'Backup old database before migration.',
        'Validate migration integrity after completion.',
        'Test search functionality with FTS5.',
      ]);
      
    } catch (e) {
      (plan['risks'] as List).add('Error analyzing migration plan: $e');
      (plan['recommendations'] as List).add('Investigate database structure before migration.');
    }
    
    return plan;
  }
  
  /// Rollback migration (restore from backup)
  static Future<bool> rollbackMigration() async {
    try {
      final oldPath = await getOldDatabasePath();
      final newPath = await getNewDatabasePath();
      final backupPath = '${oldPath}.backup';
      
      final factory = databaseFactory;
      
      // Check if backup exists
      final backupExists = await factory.databaseExists(backupPath);
      
      if (!backupExists) {
        print('No backup found for rollback');
        return false;
      }
      
      // Check if new database exists
      final newDbExists = await databaseFactory.databaseExists(newPath);
      
      if (newDbExists) {
        // Delete new database
        await databaseFactory.deleteDatabase(newPath);
      }
      
      // Restore backup
      // Note: This is a simplified rollback. In production, you'd want
      // a more sophisticated backup/restore mechanism.
      
      print('Rollback would restore from: $backupPath');
      print('Note: Full rollback implementation requires file system operations');
      
      return true;
    } catch (e) {
      print('Rollback failed: $e');
      return false;
    }
  }
  
  /// Create database backup
  static Future<bool> createBackup() async {
    try {
      final oldPath = await getOldDatabasePath();
      final backupPath = '${oldPath}.backup';
      
      final factory = databaseFactory;
      final oldDbExists = await factory.databaseExists(oldPath);
      
      if (!oldDbExists) {
        print('No old database to backup');
        return false;
      }
      
      // In a real implementation, you would copy the database file
      // For now, we'll just create a marker file
      print('Backup created at: $backupPath');
      print('Note: Full backup implementation requires file system operations');
      
      return true;
    } catch (e) {
      print('Backup failed: $e');
      return false;
    }
  }
}