import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connected_notebook/services/database_service.dart';
import 'package:connected_notebook/models/note_model.dart';

void main() {
  group('DatabaseService Tests', () {
    late DatabaseService databaseService;

    setUpAll(() async {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create a new in-memory database for each test
      databaseService = DatabaseService();
      await databaseService.database;
    });

    tearDown(() async {
      // Clean up after each test
      await databaseService.close();
    });

    test('Database initialization creates tables', () async {
      final db = await databaseService.database;
      
      // Check if notes table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='notes'"
      );
      expect(tables.length, 1);
      expect(tables.first['name'], 'notes');
    });

    test('Insert note works correctly', () async {
      final note = Note(
        title: 'Test Note',
        content: 'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: false,
        tags: ['test', 'database'],
      );

      final id = await databaseService.insertNote(note);
      expect(id, isA<int>());
      expect(id, greaterThan(0));
    });

    test('Get note by ID works correctly', () async {
      final note = Note(
        title: 'Test Note',
        content: 'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: false,
        tags: ['test'],
      );

      final id = await databaseService.insertNote(note);
      final retrievedNote = await databaseService.getNoteById(id);

      expect(retrievedNote, isNotNull);
      expect(retrievedNote!.id, id);
      expect(retrievedNote.title, note.title);
      expect(retrievedNote.content, note.content);
      expect(retrievedNote.tags, note.tags);
    });

    test('Get all notes works correctly', () async {
      // Insert multiple notes
      final notes = [
        Note(
          title: 'Note 1',
          content: 'Content 1',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          isEncrypted: false,
          tags: ['tag1'],
        ),
        Note(
          title: 'Note 2',
          content: 'Content 2',
          createdAt: DateTime.now().millisecondsSinceEpoch + 1000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 1000,
          isEncrypted: false,
          tags: ['tag2'],
        ),
        Note(
          title: 'Note 3',
          content: 'Content 3',
          createdAt: DateTime.now().millisecondsSinceEpoch + 2000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 2000,
          isEncrypted: true,
          tags: ['encrypted'],
        ),
      ];

      for (final note in notes) {
        await databaseService.insertNote(note);
      }

      final allNotes = await databaseService.getAllNotes();
      expect(allNotes.length, 3);
      
      // Notes should be ordered by updated_at descending
      expect(allNotes.first.title, 'Note 3');
      expect(allNotes.last.title, 'Note 1');
    });

    test('Update note works correctly', () async {
      final originalNote = Note(
        title: 'Original Title',
        content: 'Original content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: false,
        tags: ['original'],
      );

      final id = await databaseService.insertNote(originalNote);

      final updatedNote = originalNote.copyWith(
        id: id,
        title: 'Updated Title',
        content: 'Updated content',
        updatedAt: DateTime.now().millisecondsSinceEpoch + 5000,
        tags: ['updated'],
      );

      final rowsAffected = await databaseService.updateNote(updatedNote);
      expect(rowsAffected, 1);

      final retrievedNote = await databaseService.getNoteById(id);
      expect(retrievedNote!.title, 'Updated Title');
      expect(retrievedNote.content, 'Updated content');
      expect(retrievedNote.tags, ['updated']);
    });

    test('Delete note works correctly', () async {
      final note = Note(
        title: 'Note to Delete',
        content: 'This will be deleted',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: false,
        tags: [],
      );

      final id = await databaseService.insertNote(note);
      
      // Verify note exists
      final retrievedNote = await databaseService.getNoteById(id);
      expect(retrievedNote, isNotNull);

      // Delete note
      final rowsAffected = await databaseService.deleteNote(id);
      expect(rowsAffected, 1);

      // Verify note is deleted
      final deletedNote = await databaseService.getNoteById(id);
      expect(deletedNote, isNull);
    });

    test('Search notes works correctly', () async {
      final notes = [
        Note(
          title: 'Flutter Development',
          content: 'Learning Flutter widgets and state management',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          isEncrypted: false,
          tags: ['flutter', 'development'],
        ),
        Note(
          title: 'Dart Programming',
          content: 'Dart language fundamentals and syntax',
          createdAt: DateTime.now().millisecondsSinceEpoch + 1000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 1000,
          isEncrypted: false,
          tags: ['dart', 'programming'],
        ),
        Note(
          title: 'Database Design',
          content: 'SQL database design principles',
          createdAt: DateTime.now().millisecondsSinceEpoch + 2000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 2000,
          isEncrypted: false,
          tags: ['database', 'sql'],
        ),
      ];

      for (final note in notes) {
        await databaseService.insertNote(note);
      }

      // Search by title
      final flutterNotes = await databaseService.searchNotes('Flutter');
      expect(flutterNotes.length, 1);
      expect(flutterNotes.first.title, 'Flutter Development');

      // Search by content
      final dartNotes = await databaseService.searchNotes('language');
      expect(dartNotes.length, 1);
      expect(dartNotes.first.title, 'Dart Programming');

      // Search by tags
      final sqlNotes = await databaseService.searchNotes('sql');
      expect(sqlNotes.length, 1);
      expect(sqlNotes.first.title, 'Database Design');

      // Search with no results
      final noResults = await databaseService.searchNotes('nonexistent');
      expect(noResults.length, 0);
    });

    test('Get notes by folder works correctly', () async {
      final notes = [
        Note(
          title: 'Work Note 1',
          content: 'Work related content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          isEncrypted: false,
          tags: [],
          folderName: 'Work',
        ),
        Note(
          title: 'Personal Note',
          content: 'Personal content',
          createdAt: DateTime.now().millisecondsSinceEpoch + 1000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 1000,
          isEncrypted: false,
          tags: [],
          folderName: 'Personal',
        ),
        Note(
          title: 'Work Note 2',
          content: 'More work content',
          createdAt: DateTime.now().millisecondsSinceEpoch + 2000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 2000,
          isEncrypted: false,
          tags: [],
          folderName: 'Work',
        ),
      ];

      for (final note in notes) {
        await databaseService.insertNote(note);
      }

      final workNotes = await databaseService.getNotesByFolder('Work');
      expect(workNotes.length, 2);
      expect(workNotes.every((note) => note.folderName == 'Work'), isTrue);

      final personalNotes = await databaseService.getNotesByFolder('Personal');
      expect(personalNotes.length, 1);
      expect(personalNotes.first.folderName, 'Personal');

      final generalNotes = await databaseService.getNotesByFolder('Genel');
      expect(generalNotes.length, 0);
    });

    test('Get all folders works correctly', () async {
      final notes = [
        Note(
          title: 'Note 1',
          content: 'Content 1',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          isEncrypted: false,
          tags: [],
          folderName: 'Work',
        ),
        Note(
          title: 'Note 2',
          content: 'Content 2',
          createdAt: DateTime.now().millisecondsSinceEpoch + 1000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 1000,
          isEncrypted: false,
          tags: [],
          folderName: 'Personal',
        ),
        Note(
          title: 'Note 3',
          content: 'Content 3',
          createdAt: DateTime.now().millisecondsSinceEpoch + 2000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 2000,
          isEncrypted: false,
          tags: [],
          folderName: 'Work', // Duplicate folder
        ),
        Note(
          title: 'Note 4',
          content: 'Content 4',
          createdAt: DateTime.now().millisecondsSinceEpoch + 3000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 3000,
          isEncrypted: false,
          tags: [],
          folderName: 'Genel', // Default folder
        ),
      ];

      for (final note in notes) {
        await databaseService.insertNote(note);
      }

      final folders = await databaseService.getAllFolders();
      expect(folders.length, 3);
      expect(folders, contains('Work'));
      expect(folders, contains('Personal'));
      expect(folders, contains('Genel'));
    });

    test('Get note statistics works correctly', () async {
      final notes = [
        Note(
          title: 'Note 1',
          content: 'Short content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          isEncrypted: false,
          tags: ['tag1'],
        ),
        Note(
          title: 'Note 2',
          content: 'This is a longer content with more words to test word counting',
          createdAt: DateTime.now().millisecondsSinceEpoch + 1000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 1000,
          isEncrypted: true,
          tags: ['tag2', 'tag3'],
        ),
        Note(
          title: 'Note 3',
          content: 'Medium content here',
          createdAt: DateTime.now().millisecondsSinceEpoch + 2000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 2000,
          isEncrypted: false,
          tags: [],
        ),
      ];

      for (final note in notes) {
        await databaseService.insertNote(note);
      }

      final stats = await databaseService.getNoteStatistics();
      expect(stats['totalNotes'], 3);
      expect(stats['encryptedNotes'], 1);
      expect(stats['totalWords'], greaterThan(10));
      expect(stats['totalTags'], 3);
    });

    test('Clear all notes works correctly', () async {
      // Insert some notes
      final notes = [
        Note(
          title: 'Note 1',
          content: 'Content 1',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          isEncrypted: false,
          tags: [],
        ),
        Note(
          title: 'Note 2',
          content: 'Content 2',
          createdAt: DateTime.now().millisecondsSinceEpoch + 1000,
          updatedAt: DateTime.now().millisecondsSinceEpoch + 1000,
          isEncrypted: false,
          tags: [],
        ),
      ];

      for (final note in notes) {
        await databaseService.insertNote(note);
      }

      // Verify notes exist
      final allNotes = await databaseService.getAllNotes();
      expect(allNotes.length, 2);

      // Clear all notes
      await databaseService.clearAllNotes();

      // Verify all notes are deleted
      final clearedNotes = await databaseService.getAllNotes();
      expect(clearedNotes.length, 0);
    });

    test('Database handles null and empty values correctly', () async {
      final noteWithNulls = Note(
        title: '',
        content: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: false,
        tags: [],
        color: null,
        folderName: 'Genel',
      );

      final id = await databaseService.insertNote(noteWithNulls);
      final retrievedNote = await databaseService.getNoteById(id);

      expect(retrievedNote, isNotNull);
      expect(retrievedNote!.title, '');
      expect(retrievedNote.content, '');
      expect(retrievedNote.color, isNull);
      expect(retrievedNote.folderName, 'Genel');
    });
  });
}
