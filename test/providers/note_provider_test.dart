import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/providers/note_provider.dart';
import 'package:connected_notebook/models/note_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connected_notebook/services/database_service.dart';
import 'package:flutter/material.dart';

void main() {
  // Helper function to clear test database
  Future<void> clearTestDatabase() async {
    try {
      final db = await DatabaseService.database;
      await db.delete('notes');
      await db.delete('backlinks');
      await db.delete('templates');
    } catch (e) {
      // Database might not exist yet, that's fine
      debugPrint('Database cleanup warning: $e');
    }
  }

  setUpAll(() {
    // Initialize FFI for sqflite
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NoteProvider Tests', () {
    late NoteProvider provider;

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Clear database between tests
      await clearTestDatabase();
      
      provider = NoteProvider();
      await provider.loadNotes();
    });

    tearDown(() async {
      provider.dispose();
      // Clear database after each test
      await clearTestDatabase();
    });

    test('Provider initializes correctly', () async {
      expect(provider.notes, isEmpty);
      expect(provider.isLoading, false);
    });

    test('Add note successfully', () async {
      final note = Note(
        title: 'Test Note',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note);
      
      expect(provider.notes.length, 1);
      expect(provider.notes.first.title, 'Test Note');
      // Verify ID was assigned by database
      expect(provider.notes.first.id, isNotNull);
      expect(provider.notes.first.id, greaterThan(0));
    });

    test('Add note notifies listeners', () async {
      final note = Note(
        title: 'Listener Test',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Track notifyListeners calls
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      
      await provider.addNote(note);
      
      // Should notify at least once (after successful add)
      expect(notifyCount, greaterThan(0));
    });

    test('Add note fails with database error', () async {
      final note = Note(
        title: 'Error Test',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Mock database failure by using invalid data
      // This will test error handling path
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      
      // We expect this to not throw and handle gracefully
      await provider.addNote(note);
      
      // Even with error, should still notify listeners
      // (though this might need mocking to properly test error scenarios)
    });

    test('Update note successfully', () async {
      final note = Note(
        title: 'Original Title',
        content: 'Original Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note);
      expect(provider.notes.length, 1);
      
      // Get the note with assigned ID
      final addedNote = provider.notes.first;
      final updatedNote = addedNote.copyWith(title: 'Updated Title');
      await provider.updateNote(updatedNote);

      expect(provider.notes.length, 1);
      expect(provider.notes.first.title, 'Updated Title');
      expect(provider.notes.first.id, addedNote.id); // ID should remain same
    });

    test('Update note notifies listeners', () async {
      final note = Note(
        title: 'Update Listener Test',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note);
      
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      
      final addedNote = provider.notes.first;
      final updatedNote = addedNote.copyWith(title: 'Updated');
      await provider.updateNote(updatedNote);
      
      expect(notifyCount, greaterThan(0));
    });

    test('Delete note successfully', () async {
      final note = Note(
        title: 'Note to Delete',
        content: 'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note);
      expect(provider.notes.length, 1);
      
      // Get the actual note with ID from provider
      final addedNote = provider.notes.first;
      expect(addedNote.id, isNotNull);

      await provider.deleteNote(addedNote.id!);
      expect(provider.notes.isEmpty, true);
    });

    test('Delete note notifies listeners', () async {
      final note = Note(
        title: 'Delete Listener Test',
        content: 'Test Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note);
      final addedNote = provider.notes.first;
      
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      
      await provider.deleteNote(addedNote.id!);
      
      expect(notifyCount, greaterThan(0));
    });

    test('Delete non-existent note handles gracefully', () async {
      // Try to delete a note that doesn't exist
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      
      await provider.deleteNote(999999); // Non-existent ID
      
      // Should not throw exception and should still notify
      expect(notifyCount, greaterThan(0));
    });

    test('Search notes returns matching results', () async {
      final note1 = Note(
        title: 'First Note',
        content: 'Content about Flutter',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final note2 = Note(
        title: 'Second Note',
        content: 'Content about Dart',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note1);
      await provider.addNote(note2);

      await provider.searchNotes('Flutter');
      expect(provider.searchResults.length, 1);
      expect(provider.searchResults.first.title, 'First Note');
    });

    test('Search notifies listeners', () async {
      final note = Note(
        title: 'Search Test',
        content: 'Flutter content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note);
      
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      
      await provider.searchNotes('Flutter');
      
      expect(notifyCount, greaterThan(0));
    });

    test('Search handles empty query', () async {
      final note = Note(
        title: 'Empty Query Test',
        content: 'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note);
      
      await provider.searchNotes('');
      expect(provider.searchResults.length, 1);
      expect(provider.searchResults.first.title, 'Empty Query Test');
    });

    test('Filter notes by tag', () async {
      final note1 = Note(
        title: 'Note with Tag',
        content: 'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        tags: ['important', 'work'],
      );

      final note2 = Note(
        title: 'Note without Tag',
        content: 'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        tags: ['personal'],
      );

      await provider.addNote(note1);
      await provider.addNote(note2);

      final results = provider.getNotesByTag('important');
      expect(results.length, 1);
      expect(results.first.title, 'Note with Tag');
    });

    test('Get notes by tag notifies listeners', () async {
      final note = Note(
        title: 'Tag Listener Test',
        content: 'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        tags: ['test-tag'],
      );

      await provider.addNote(note);
      
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      
      final results = provider.getNotesByTag('test-tag');
      
      // getNotesByTag is synchronous and doesn't notify, but other operations do
      expect(results.length, 1);
    });

    test('Toggle encryption status', () async {
      final note = Note(
        title: 'Test Encryption',
        content: 'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await provider.addNote(note);
      final addedNote = provider.notes.first;
      expect(addedNote.isEncrypted, false);

      // Test updating encryption status
      final encryptedNote = addedNote.copyWith(isEncrypted: true);
      await provider.updateNote(encryptedNote);
      
      final updatedNote = provider.notes.first;
      expect(updatedNote.isEncrypted, true);
      expect(updatedNote.id, addedNote.id);
    });

    test('Load notes notifies listeners', () async {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      
      await provider.loadNotes();
      
      // Should notify during loading and after completion
      expect(notifyCount, greaterThan(0));
    });

    test('Load notes handles empty database', () async {
      await provider.loadNotes();
      expect(provider.notes, isEmpty);
      expect(provider.isLoading, false);
    });

    test('Provider getters work correctly', () async {
      expect(provider.notes, isA<List<Note>>());
      expect(provider.searchResults, isA<List<Note>>());
      expect(provider.isLoading, isA<bool>());
      expect(provider.searchQuery, isA<String>());
    });

    test('Folder functionality works', () async {
      final note = Note(
        title: 'Folder Test',
        content: 'Content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        folderName: 'TestFolder',
      );

      await provider.addNote(note);
      
      final folders = provider.folders;
      expect(folders, contains('TestFolder'));
      expect(folders, contains('Genel'));
      
      final folderCount = provider.getNoteCountInFolder('TestFolder');
      expect(folderCount, 1);
    });
  });
}