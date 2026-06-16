import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:connected_notebook/core/database/idatabase_service.dart';

import 'package:connected_notebook/core/database/legacy_database_service_adapter.dart';
import 'package:connected_notebook/core/database/secure_database_service.dart';
import 'package:connected_notebook/core/migration/migration_manager.dart';
import 'package:connected_notebook/core/security/crypto_engine.dart';
import 'package:connected_notebook/core/security/key_derivation_component.dart';
import 'package:connected_notebook/core/security/legacy_encryption_service_adapter.dart';
import 'package:connected_notebook/core/security/vault_service_v2.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/providers/vault_provider.dart';
import 'package:connected_notebook/features/notes/providers/note_editor_provider.dart';
import 'package:connected_notebook/features/notes/repositories/mock_note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/sql_note_repository.dart';
import 'package:connected_notebook/features/notes/services/advanced_search_service.dart';
import 'package:connected_notebook/features/notes/services/backlink_service.dart';
import 'package:connected_notebook/features/notes/services/note_service.dart';
import 'package:connected_notebook/features/notes/services/search_service_interface.dart';

/// Dependency injection configuration for notes feature.
///
/// This configuration keeps the existing feature API intact while routing note
/// persistence through the new secure database service and routing encryption
/// through the new vault and crypto engine layers.
class NoteDependencyInjection {
  static bool _isTestMode = false;
  static bool _useOptimizedRepository = true;

  /// Enable test mode (uses mock repositories).
  static void enableTestMode() {
    _isTestMode = true;
  }

  /// Disable test mode (uses real repositories).
  static void disableTestMode() {
    _isTestMode = false;
  }

  /// Keep compatibility with previous toggles.
  static void setUseOptimizedRepository(bool useOptimized) {
    _useOptimizedRepository = useOptimized;
  }

  /// Get all providers for the notes feature.
  static List<SingleChildWidget> getProviders() {
    return [
      Provider<FlutterSecureStorage>(
        create: (_) => const FlutterSecureStorage(),
      ),
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
      Provider<ISecureDatabaseService>(
        create: (_) => SecureSqliteDatabaseService(),
      ),
      Provider<IDatabaseService>(
        create: (context) {
          if (kIsWeb) {
            return InMemoryDatabaseService();
          }

          return LegacyDatabaseServiceAdapter(
            context.read<ISecureDatabaseService>(),
          );
        },
      ),

      // Repository chain: UI -> NoteRepository -> legacy contract adapter -> secure DB.
      Provider<NoteRepository>(
        create: (context) {
          if (_isTestMode) {
            return MockNoteRepository();
          }
          return SqlNoteRepository(context.read<IDatabaseService>());
        },
      ),

      // Feature services.
      Provider<BacklinkService>(
        create: (context) => BacklinkService(context.read<NoteRepository>()),
      ),
      Provider<SearchService>(
        create: (context) =>
            AdvancedSearchService(context.read<NoteRepository>()),
      ),
      Provider<MigrationManager>(create: (_) => MigrationManager()),
      Provider<NoteService>(
        create: (context) => NoteService(
          context.read<NoteRepository>(),
          context.read<BacklinkService>(),
          encryptionAdapter: context.read<LegacyEncryptionServiceAdapter>(),
        ),
      ),

      ChangeNotifierProvider<VaultProvider>(
        create: (context) => VaultProvider(
          encryptionAdapter: context.read<LegacyEncryptionServiceAdapter>(),
          vaultService: context.read<IVaultServiceV2>(),
          noteService: context.read<NoteService>(),
        )..syncState(),
      ),

      // State provider remains unchanged for UI stability.
      ChangeNotifierProvider<NoteProvider>(
        create: (context) => NoteProvider(
          repository: context.read<NoteRepository>(),
          searchService: context.read<SearchService>(),
        ),
      ),
      ChangeNotifierProvider<NoteEditorProvider>(
        create: (context) =>
            NoteEditorProvider(vaultProvider: context.read<VaultProvider>()),
      ),
    ];
  }

  /// Get providers for testing.
  static List<SingleChildWidget> getTestProviders() {
    enableTestMode();
    return getProviders();
  }

  /// Setup providers for a specific widget tree.
  static Widget setupProviders({
    required Widget child,
    bool isTestMode = false,
  }) {
    if (isTestMode) {
      enableTestMode();
    }

    return MultiProvider(providers: getProviders(), child: child);
  }

  /// Get a specific service (for manual injection if needed).
  static T getService<T>(BuildContext context) {
    return context.read<T>();
  }

  /// Initialize all note-related services.
  static Future<void> initializeServices(BuildContext context) async {
    try {
      await context.read<IDatabaseService>().database;
      debugPrint('Note services initialized successfully');
    } catch (e) {
      debugPrint('Error initializing note services: $e');
      rethrow;
    }
  }

  /// Cleanup note-related services.
  static Future<void> cleanupServices(BuildContext context) async {
    try {
      await context.read<IDatabaseService>().close();
      await context.read<IVaultServiceV2>().lock();
      debugPrint('Note services cleaned up successfully');
    } catch (e) {
      debugPrint('Error cleaning up note services: $e');
    }
  }

  /// Optimize database performance.
  static Future<void> optimizeDatabase(BuildContext context) async {
    try {
      await context.read<IDatabaseService>().optimize();
      debugPrint('Database optimization completed');
    } catch (e) {
      debugPrint('Error optimizing database: $e');
    }
  }

  /// Get performance statistics.
  static Map<String, dynamic> getPerformanceStats(BuildContext context) {
    try {
      return {
        'usesOptimizedRepository': _useOptimizedRepository,
        'isTestMode': _isTestMode,
        'secureDatabaseEnabled': true,
        'vaultV2Enabled': true,
      };
    } catch (e) {
      debugPrint('Error getting performance stats: $e');
      return {};
    }
  }

  static bool get isTestMode => _isTestMode;
  static bool get isUsingOptimizedRepository => _useOptimizedRepository;
}

/// Extension methods for easier access to note services.
extension NoteDependencyInjectionExtension on BuildContext {
  NoteRepository get noteRepository => read<NoteRepository>();
  SearchService get searchService => read<SearchService>();
  NoteProvider get noteProvider => read<NoteProvider>();
  VaultProvider get vaultProvider => read<VaultProvider>();
  NoteEditorProvider get noteEditorProvider => read<NoteEditorProvider>();
  MigrationManager get migrationManager => read<MigrationManager>();
  LegacyEncryptionServiceAdapter get encryptionService =>
      read<LegacyEncryptionServiceAdapter>();
  Future<void> optimizeNoteDatabase() async =>
      NoteDependencyInjection.optimizeDatabase(this);
  Map<String, dynamic> getNotePerformanceStats() =>
      NoteDependencyInjection.getPerformanceStats(this);

  Future<Map<String, dynamic>> checkMigrationStatus() async {
    return MigrationManager.checkMigrationNeeded();
  }

  Future<Map<String, dynamic>> executeMigration({
    bool backupBeforeMigration = true,
    bool validateAfterMigration = true,
  }) async {
    return MigrationManager.executeMigration(
      backupBeforeMigration: backupBeforeMigration,
      validateAfterMigration: validateAfterMigration,
    );
  }
}
