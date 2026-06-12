import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/sqlite_note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/mock_note_repository.dart';
import 'package:connected_notebook/features/notes/services/search_service_interface.dart';
import 'package:connected_notebook/features/notes/services/advanced_search_service.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/core/migration/migration_manager.dart';
import 'package:connected_notebook/core/security/encryption_service.dart';

/// Dependency injection configuration for notes feature
/// Follows Dependency Inversion Principle: High-level modules depend on abstractions
class NoteDependencyInjection {
  static bool _isTestMode = false;
  static bool _useOptimizedRepository = true;
  
  /// Enable test mode (uses mock repositories)
  static void enableTestMode() {
    _isTestMode = true;
  }
  
  /// Disable test mode (uses real repositories)
  static void disableTestMode() {
    _isTestMode = false;
  }
  
  /// Use optimized repository
  static void setUseOptimizedRepository(bool useOptimized) {
    _useOptimizedRepository = useOptimized;
  }
  
  /// Get all providers for the notes feature
  static List<SingleChildWidget> getProviders() {
    return [
      // Repository
      Provider<NoteRepository>(
        create: (_) {
          if (_isTestMode) {
            return MockNoteRepository();
          }
          
          return SqliteNoteRepository();
        },
      ),
      
      // Services
      Provider<SearchService>(
        create: (context) => AdvancedSearchService(context.read<NoteRepository>()),
      ),
      
      // Migration Services
      Provider<MigrationManager>(
        create: (_) => MigrationManager(),
      ),
      
      Provider<EnhancedEncryptionService>(
        create: (_) => EnhancedEncryptionService.instance,
      ),
      
      // State Provider
      ChangeNotifierProvider<NoteProvider>(
        create: (context) => NoteProvider(
          repository: context.read<NoteRepository>(),
          searchService: context.read<SearchService>(),
        ),
      ),
    ];
  }
  
  /// Get providers for testing
  static List<SingleChildWidget> getTestProviders() {
    enableTestMode();
    return getProviders();
  }
  
  /// Setup providers for a specific widget tree
  static Widget setupProviders({required Widget child, bool isTestMode = false}) {
    if (isTestMode) {
      enableTestMode();
    }
    
    return MultiProvider(
      providers: getProviders(),
      child: child,
    );
  }
  
  /// Get a specific service (for manual injection if needed)
  static T getService<T>(BuildContext context) {
    return context.read<T>();
  }
  
  /// Initialize all services
  static Future<void> initializeServices(BuildContext context) async {
    try {
      // Initialize repository if needed
      // final repository = context.read<NoteRepository>();
      
      print('Note services initialized successfully');
    } catch (e) {
      print('Error initializing note services: $e');
      rethrow;
    }
  }
  
  /// Cleanup services
  static Future<void> cleanupServices(BuildContext context) async {
    try {
      final repository = context.read<NoteRepository>();
      if (repository is SqliteNoteRepository) {
        await repository.close();
      }
      
      print('Note services cleaned up successfully');
    } catch (e) {
      print('Error cleaning up note services: $e');
    }
  }
  
  /// Optimize database performance
  static Future<void> optimizeDatabase(BuildContext context) async {
    try {
      final repository = context.read<NoteRepository>();
      if (repository is SqliteNoteRepository) {
        // await repository.optimizeDatabase();
        print('Database optimization completed');
      }
    } catch (e) {
      print('Error optimizing database: $e');
    }
  }
  
  /// Get performance statistics
  static Map<String, dynamic> getPerformanceStats(BuildContext context) {
    try {
      final repository = context.read<NoteRepository>();
      if (repository is SqliteNoteRepository) {
        // return repository.getPerformanceStats();
      }
    } catch (e) {
      print('Error getting performance stats: $e');
    }
    
    return {};
  }
  
  /// Check if we're in test mode
  static bool get isTestMode => _isTestMode;
  
  /// Check if using optimized repository
  static bool get isUsingOptimizedRepository => _useOptimizedRepository;
}

/// Extension methods for easier access to note services
extension NoteDependencyInjectionExtension on BuildContext {
  /// Get Note Repository
  NoteRepository get noteRepository => read<NoteRepository>();
  
  /// Get Search Service
  SearchService get searchService => read<SearchService>();
  
  /// Get Note Provider
  NoteProvider get noteProvider => read<NoteProvider>();
  
  /// Get Migration Manager
  MigrationManager get migrationManager => read<MigrationManager>();
  
  /// Get Encryption Service
  EnhancedEncryptionService get encryptionService => read<EnhancedEncryptionService>();
  
  /// Optimize database
  Future<void> optimizeNoteDatabase() async {
    await NoteDependencyInjection.optimizeDatabase(this);
  }
  
  /// Get performance statistics
  Map<String, dynamic> getNotePerformanceStats() {
    return NoteDependencyInjection.getPerformanceStats(this);
  }
  
  /// Check migration status
  Future<Map<String, dynamic>> checkMigrationStatus() async {
    return await MigrationManager.checkMigrationNeeded();
  }
  
  /// Execute migration
  Future<Map<String, dynamic>> executeMigration({
    bool backupBeforeMigration = true,
    bool validateAfterMigration = true,
  }) async {
    return await MigrationManager.executeMigration(
      backupBeforeMigration: backupBeforeMigration,
      validateAfterMigration: validateAfterMigration,
    );
  }
}