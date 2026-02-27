import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/notes/repositories/inote_repository.dart';
import '../features/notes/repositories/sql_note_repository.dart';
import '../features/notes/repositories/mock_note_repository.dart';
import '../features/notes/services/note_service.dart';
import '../features/notes/services/backlink_service.dart';
import '../features/notes/services/note_search_service.dart';
import '../features/notes/providers/note_state_provider.dart';
import '../features/notes/providers/note_action_provider.dart';
import '../core/database/idatabase_service.dart';
import '../core/database/sqlite_database_service.dart';

/// Dependency Injection configuration
/// Follows Dependency Inversion Principle: High-level modules don't depend on low-level modules
class DependencyInjection {
  static bool _isTestMode = false;

  /// Enable test mode (uses mock repositories)
  static void enableTestMode() {
    _isTestMode = true;
  }

  /// Disable test mode (uses real repositories)
  static void disableTestMode() {
    _isTestMode = false;
  }

  /// Get all providers for the application
  static List<ChangeNotifierProvider> getProviders() {
    return [
      // Database service
      Provider<IDatabaseService>(
        create: (_) => _isTestMode ? _createMockDatabaseService() : SqliteDatabaseService(),
      ),

      // Repository
      Provider<INoteRepository>(
        create: (context) => _isTestMode ? MockNoteRepository() : SqlNoteRepository(),
      ),

      // Services
      Provider<BacklinkService>(
        create: (context) => BacklinkService(context.read<INoteRepository>()),
      ),

      Provider<NoteSearchService>(
        create: (context) => NoteSearchService(
          context.read<INoteRepository>(),
          context.read<BacklinkService>(),
        ),
      ),

      Provider<NoteService>(
        create: (context) => NoteService(
          context.read<INoteRepository>(),
          context.read<BacklinkService>(),
        ),
      ),

      // Providers
      ChangeNotifierProvider<NoteStateProvider>(
        create: (_) => NoteStateProvider(),
      ),

      ChangeNotifierProvider<NoteActionProvider>(
        create: (context) => NoteActionProvider(
          context.read<NoteService>(),
          context.read<NoteSearchService>(),
          context.read<NoteStateProvider>(),
        ),
      ),
    ];
  }

  /// Get providers for testing (uses mocks)
  static List<ChangeNotifierProvider> getTestProviders() {
    enableTestMode();
    return getProviders();
  }

  /// Create mock database service for testing
  static IDatabaseService _createMockDatabaseService() {
    // This would be a mock implementation of IDatabaseService
    // For now, we'll use the real one but in a test scenario
    return SqliteDatabaseService();
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
      // Initialize database
      final databaseService = context.read<IDatabaseService>();
      await databaseService.database;

      // Preload any necessary data
      final noteService = context.read<NoteService>();
      // await noteService.loadInitialData(); // If needed

      print('Services initialized successfully');
    } catch (e) {
      print('Error initializing services: $e');
      rethrow;
    }
  }

  /// Cleanup services
  static Future<void> cleanupServices(BuildContext context) async {
    try {
      final databaseService = context.read<IDatabaseService>();
      await databaseService.close();
      print('Services cleaned up successfully');
    } catch (e) {
      print('Error cleaning up services: $e');
    }
  }

  /// Reset all providers (useful for testing)
  static void resetProviders(BuildContext context) {
    // Reset state providers
    context.read<NoteStateProvider>().clearAll();
  }

  /// Check if we're in test mode
  static bool get isTestMode => _isTestMode;
}

/// Extension methods for easier access to services
extension DependencyInjectionExtension on BuildContext {
  /// Get Note Service
  NoteService get noteService => read<NoteService>();

  /// Get Search Service
  NoteSearchService get searchService => read<NoteSearchService>();

  /// Get Backlink Service
  BacklinkService get backlinkService => read<BacklinkService>();

  /// Get Note State Provider
  NoteStateProvider get noteStateProvider => read<NoteStateProvider>();

  /// Get Note Action Provider
  NoteActionProvider get noteActionProvider => read<NoteActionProvider>();

  /// Get Repository
  INoteRepository get noteRepository => read<INoteRepository>();

  /// Get Database Service
  IDatabaseService get databaseService => read<IDatabaseService>();
}

/// Provider configuration for different environments
enum Environment { development, production, test }

class ProviderConfig {
  static Environment _currentEnvironment = Environment.development;

  static Environment get currentEnvironment => _currentEnvironment;

  static void setEnvironment(Environment environment) {
    _currentEnvironment = environment;
  }

  static bool get isDevelopment => _currentEnvironment == Environment.development;
  static bool get isProduction => _currentEnvironment == Environment.production;
  static bool get isTest => _currentEnvironment == Environment.test;

  static void configureForEnvironment() {
    switch (_currentEnvironment) {
      case Environment.test:
        DependencyInjection.enableTestMode();
        break;
      case Environment.development:
      case Environment.production:
        DependencyInjection.disableTestMode();
        break;
    }
  }
}
