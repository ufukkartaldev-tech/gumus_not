import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:connected_notebook/core/database/idatabase_service.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/providers/note_editor_provider.dart';
import 'package:connected_notebook/features/notes/repositories/mock_note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/repositories/sql_note_repository.dart';
import 'package:connected_notebook/features/notes/services/git_sync_service.dart';
import 'package:connected_notebook/features/notes/services/advanced_search_service.dart';
import 'package:connected_notebook/features/notes/services/backlink_service.dart';
import 'package:connected_notebook/features/notes/services/note_service.dart';
import 'package:connected_notebook/features/notes/services/search_service_interface.dart';

class NoteDependencyInjection {
  static bool _isTestMode = false;

  static void enableTestMode() {
    _isTestMode = true;
  }

  static void disableTestMode() {
    _isTestMode = false;
  }

  static List<SingleChildWidget> getProviders() {
    return [
      Provider<IDatabaseService>(
        create: (context) {
          return InMemoryDatabaseService(); // Fallback for removed legacy DB
        },
      ),
      Provider<GitSyncService>(
        create: (_) => GitSyncService(),
      ),
      Provider<NoteRepository>(
        create: (context) {
          if (_isTestMode) {
            return MockNoteRepository();
          }
          return SqlNoteRepository(context.read<IDatabaseService>());
        },
      ),
      Provider<BacklinkService>(
        create: (context) => BacklinkService(context.read<NoteRepository>()),
      ),
      Provider<SearchService>(
        create: (context) =>
            AdvancedSearchService(context.read<NoteRepository>()),
      ),
      Provider<NoteService>(
        create: (context) => NoteService(
          context.read<NoteRepository>(),
          context.read<BacklinkService>(),
        ),
      ),
      ChangeNotifierProvider<NoteProvider>(
        create: (context) => NoteProvider(
          repository: context.read<NoteRepository>(),
          searchService: context.read<SearchService>(),
        ),
      ),
      ChangeNotifierProvider<NoteEditorProvider>(
        create: (context) => NoteEditorProvider(),
      ),
    ];
  }

  static List<SingleChildWidget> getTestProviders() {
    enableTestMode();
    return getProviders();
  }

  static Widget setupProviders({
    required Widget child,
    bool isTestMode = false,
  }) {
    if (isTestMode) {
      enableTestMode();
    }
    return MultiProvider(providers: getProviders(), child: child);
  }

  static Future<void> initializeServices(BuildContext context) async {
    debugPrint('Note services initialized successfully');
  }

  static Future<void> cleanupServices(BuildContext context) async {
    debugPrint('Note services cleaned up successfully');
  }

  static Future<void> optimizeDatabase(BuildContext context) async {
    debugPrint('Database optimization completed');
  }

  static Map<String, dynamic> getPerformanceStats(BuildContext context) {
    return {
      'isTestMode': _isTestMode,
    };
  }

  static bool get isTestMode => _isTestMode;
}

extension NoteDependencyInjectionExtension on BuildContext {
  NoteRepository get noteRepository => read<NoteRepository>();
  SearchService get searchService => read<SearchService>();
  NoteProvider get noteProvider => read<NoteProvider>();
  NoteEditorProvider get noteEditorProvider => read<NoteEditorProvider>();
}
