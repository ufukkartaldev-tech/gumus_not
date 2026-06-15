import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/analytics/services/analytics_service.dart';
import '../../features/media/services/image_service.dart';
import '../../features/media/services/note_image_service.dart';
import '../../features/notes/providers/note_action_provider.dart';
import '../../features/notes/providers/note_state_provider.dart';
import '../../features/notes/repositories/mock_note_repository.dart';
import '../../features/notes/repositories/note_repository.dart';
import '../../features/notes/repositories/sql_note_repository.dart';
import '../../features/notes/services/backlink_service.dart';
import '../../features/notes/services/note_search_service.dart';
import '../../features/notes/services/note_service.dart';
import '../database/idatabase_service.dart';
import '../database/legacy_database_service_adapter.dart';
import '../database/secure_database_service.dart';
import '../security/crypto_engine.dart';
import '../security/key_derivation_component.dart';
import '../security/legacy_encryption_service_adapter.dart';
import '../security/vault_service_v2.dart';
import '../theme/theme_provider.dart';

/// Dependency Injection configuration
///
/// The application is wired in a staged manner so legacy UI and repository
/// flows keep working while new secure database and vault services operate
/// underneath through adapters.
class DependencyInjection {
  static bool _isTestMode = false;

  /// Enable test mode (uses mock repositories).
  static void enableTestMode() {
    _isTestMode = true;
  }

  /// Disable test mode (uses real repositories).
  static void disableTestMode() {
    _isTestMode = false;
  }

  /// Get all providers for the application.
  static List<SingleChildWidget> getProviders() {
    return [
      // Theme Provider should be available early in the widget tree.
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider()..loadTheme(),
      ),

      // Shared secure storage for vault metadata.
      Provider<FlutterSecureStorage>(
        create: (_) => const FlutterSecureStorage(),
      ),

      // New cryptographic building blocks.
      Provider<IKeyDerivationComponent>(
        create: (_) => Pbkdf2KeyDerivationComponent(),
      ),
      Provider<ICryptoEngine>(
        create: (context) => Aes256GcmCryptoEngine(
          keyDerivation: context.read<IKeyDerivationComponent>(),
        ),
      ),
      Provider<IVaultServiceV2>(
        create: (context) => VaultServiceV2(
          cryptoEngine: context.read<ICryptoEngine>(),
          secureStorage: context.read<FlutterSecureStorage>(),
        ),
      ),
      Provider<LegacyEncryptionServiceAdapter>(
        create: (context) => LegacyEncryptionServiceAdapter(
          vaultService: context.read<IVaultServiceV2>(),
          cryptoEngine: context.read<ICryptoEngine>(),
        ),
      ),

      // New secure database implementation.
      Provider<ISecureDatabaseService>(
        create: (_) => SecureSqliteDatabaseService(),
      ),

      // Legacy database contract bridged onto the new secure database layer.
      Provider<IDatabaseService>(
        create: (context) => _isTestMode
            ? _createMockDatabaseService()
            : LegacyDatabaseServiceAdapter(
                context.read<ISecureDatabaseService>(),
              ),
      ),

      // Repository remains unchanged at call sites, but is now backed by the
      // new secure database via the legacy adapter contract.
      Provider<NoteRepository>(
        create: (context) => _isTestMode
            ? MockNoteRepository()
            : SqlNoteRepository(context.read<IDatabaseService>()),
      ),

      // Note services.
      Provider<BacklinkService>(
        create: (context) => BacklinkService(context.read<NoteRepository>()),
      ),
      Provider<NoteSearchService>(
        create: (context) => NoteSearchService(
          context.read<NoteRepository>(),
          context.read<BacklinkService>(),
        ),
      ),
      Provider<NoteService>(
        create: (context) => NoteService(
          context.read<NoteRepository>(),
          context.read<BacklinkService>(),
          encryptionAdapter: context.read<LegacyEncryptionServiceAdapter>(),
        ),
      ),

      // Media Services.
      Provider<ImageService>(
        create: (_) => ImageService(),
      ),
      Provider<NoteImageService>(
        create: (_) => NoteImageService(),
      ),

      // Analytics.
      Provider<AnalyticsService>(
        create: (context) => AnalyticsService(context.read<NoteRepository>()),
      ),

      // UI state providers.
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

  /// Get providers for testing (uses mocks).
  static List<SingleChildWidget> getTestProviders() {
    enableTestMode();
    return getProviders();
  }

  /// Create mock database service for testing.
  static IDatabaseService _createMockDatabaseService() {
    return LegacyDatabaseServiceAdapter(SecureSqliteDatabaseService());
  }

  /// Setup providers for a specific widget tree.
  static Widget setupProviders({required Widget child, bool isTestMode = false}) {
    if (isTestMode) {
      enableTestMode();
    }

    return MultiProvider(
      providers: getProviders(),
      child: child,
    );
  }

  /// Get a specific service (for manual injection if needed).
  static T getService<T>(BuildContext context) {
    return context.read<T>();
  }

  /// Initialize all services.
  static Future<void> initializeServices(BuildContext context) async {
    try {
      // Ensure database is opened and ready.
      final databaseService = context.read<IDatabaseService>();
      await databaseService.database;

      debugPrint('Services initialized successfully');
    } catch (e) {
      debugPrint('Error initializing services: $e');
      rethrow;
    }
  }

  /// Cleanup services.
  static Future<void> cleanupServices(BuildContext context) async {
    try {
      await context.read<IDatabaseService>().close();
      await context.read<IVaultServiceV2>().lock();
      debugPrint('Services cleaned up successfully');
    } catch (e) {
      debugPrint('Error cleaning up services: $e');
    }
  }

  /// Reset all providers (useful for testing).
  static void resetProviders(BuildContext context) {
    context.read<NoteStateProvider>().clearAll();
  }

  /// Check if we're in test mode.
  static bool get isTestMode => _isTestMode;
}

/// Extension methods for easier access to services.
extension DependencyInjectionExtension on BuildContext {
  NoteService get noteService => read<NoteService>();
  NoteSearchService get searchService => read<NoteSearchService>();
  BacklinkService get backlinkService => read<BacklinkService>();
  NoteStateProvider get noteStateProvider => read<NoteStateProvider>();
  NoteActionProvider get noteActionProvider => read<NoteActionProvider>();
  NoteRepository get noteRepository => read<NoteRepository>();
  IDatabaseService get databaseService => read<IDatabaseService>();
  ISecureDatabaseService get secureDatabaseService => read<ISecureDatabaseService>();
  LegacyEncryptionServiceAdapter get encryptionAdapter => read<LegacyEncryptionServiceAdapter>();
  IVaultServiceV2 get vaultServiceV2 => read<IVaultServiceV2>();
  ImageService get imageService => read<ImageService>();
  NoteImageService get noteImageService => read<NoteImageService>();
  AnalyticsService get analyticsService => read<AnalyticsService>();
  ThemeProvider get themeProvider => read<ThemeProvider>();
}

/// Provider configuration for different environments.
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
