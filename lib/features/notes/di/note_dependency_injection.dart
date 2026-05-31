import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/sqlite_note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/mock_note_repository.dart';
import 'package:connected_notebook/features/notes/services/search_service_interface.dart';
import 'package:connected_notebook/features/notes/services/advanced_search_service.dart';
import 'package:connected_notebook/features/notes/providers/refactored_note_provider.dart';

/// Dependency injection configuration for notes feature
/// Follows Dependency Inversion Principle: High-level modules depend on abstractions
class NoteDependencyInjection {
  static bool _isTestMode = false;
  
  /// Enable test mode (uses mock repositories)
  static void enableTestMode() {
    _isTestMode = true;
  }
  
  /// Disable test mode (uses real repositories)
  static void disableTestMode() {
    _isTestMode = false;
  }
  
  /// Get all providers for the notes feature
  static List<ChangeNotifierProvider> getProviders() {
    return [
      // Repository
      Provider<NoteRepository>(
        create: (_) => _isTestMode ? MockNoteRepository() : SqliteNoteRepository(),
      ),
      
      // Services
      Provider<SearchService>(
        create: (_) => AdvancedSearchService(),
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
  static List<ChangeNotifierProvider> getTestProviders() {
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
      final repository = context.read<NoteRepository>();
      if (repository is SqliteNoteRepository) {
        // Database will be initialized lazily
      }
      
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
  
  /// Check if we're in test mode
  static bool get isTestMode => _isTestMode;
}

/// Extension methods for easier access to note services
extension NoteDependencyInjectionExtension on BuildContext {
  /// Get Note Repository
  NoteRepository get noteRepository => read<NoteRepository>();
  
  /// Get Search Service
  SearchService get searchService => read<SearchService>();
  
  /// Get Note Provider
  NoteProvider get noteProvider => read<NoteProvider>();
}