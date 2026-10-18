import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:connected_notebook/core/storage/note_markdown_codec.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/services/git_sync_service.dart';
import 'package:connected_notebook/features/notes/services/template_file_storage.dart';

/// One-time migration from the retired SQLite database to markdown files.
///
/// On the first launch after the storage switch, every note and template row
/// is exported to `<documents>/GumusNot` as `.md` files. The legacy database
/// file is then renamed to `connected_notebook.db.migrated` and a marker file
/// is written so the migration never runs twice. Exports are idempotent
/// (files are named `<id>.md`), so a failed attempt safely retries on the
/// next launch; a migration failure never blocks app startup.
class SqliteToMarkdownMigrator {
  static const String _markerFileName = '.migrated_from_sqlite';
  static const String _legacyDbName = 'connected_notebook.db';

  Future<void> migrateIfNeeded() async {
    if (kIsWeb) return;

    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = Directory(p.join(docs.path, 'GumusNot'));
      if (!root.existsSync()) root.createSync(recursive: true);

      final marker = File(p.join(root.path, _markerFileName));
      if (marker.existsSync()) return;

      final counts = await _exportLegacyDatabase();
      await marker.writeAsString(
        'migrated at ${DateTime.now().toIso8601String()}: '
        '${counts[0]} notes, ${counts[1]} templates',
      );
      debugPrint('SQLite -> markdown migration done: '
          '${counts[0]} notes, ${counts[1]} templates');
    } catch (e) {
      debugPrint('SQLite -> markdown migration skipped: $e');
    }
  }

  /// Returns `(noteCount, templateCount)`.
  Future<List<int>> _exportLegacyDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = p.join(await getDatabasesPath(), _legacyDbName);
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) return [0, 0];

    final db = await openDatabase(dbPath, readOnly: true);
    List<int> counts;
    try {
      final notesDir = Directory(await GitSyncService().getRepoPath());
      if (!notesDir.existsSync()) notesDir.createSync(recursive: true);

      var noteCount = 0;
      for (final row in await db.query('notes')) {
        final note = Note.fromMap(row);
        final id = note.id;
        if (id == null) continue;
        final file = NoteMarkdownCodec.resolveUniqueFile(notesDir, note);
        await file.writeAsString(NoteMarkdownCodec.serialize(note));
        noteCount++;
      }

      var templateCount = 0;
      for (final row in await db.query('templates')) {
        final template = Template.fromMap(row);
        if (template.id == null) continue;
        await TemplateFileStorage.write(template);
        templateCount++;
      }

      counts = [noteCount, templateCount];
    } finally {
      await db.close();
    }

    // Retire the legacy file so no code path opens it again.
    try {
      await dbFile.rename('$dbPath.migrated');
    } catch (_) {}

    return counts;
  }
}
