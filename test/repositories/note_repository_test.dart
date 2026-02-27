import 'package:flutter_test/flutter_test.dart';
import '../lib/features/notes/repositories/inote_repository.dart';
import '../lib/features/notes/repositories/mock_note_repository.dart';
import '../lib/features/notes/models/note_model.dart';

/// Test cases for Note Repository
/// Following SOLID principles: Testable and maintainable code
void main() {
  group('NoteRepository Tests', () {
    late INoteRepository repository;

    setUp(() {
      repository = MockNoteRepository();
    });

    tearDown(() {
      if (repository is MockNoteRepository) {
        (repository as MockNoteRepository).clearAll();
      }
    });

    group('CRUD Operations', () {
      test('should create a note successfully', () async {
        // Arrange
        final note = Note(
          title: 'Test Note',
          content: 'Test content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          tags: ['test'],
        );

        // Act
        final noteId = await repository.insertNote(note);

        // Assert
        expect(noteId, isA<int>());
        expect(noteId, greaterThan(0));
      });

      test('should retrieve a note by ID', () async {
        // Arrange
        final note = Note(
          title: 'Test Note',
          content: 'Test content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        final noteId = await repository.insertNote(note);

        // Act
        final retrievedNote = await repository.getNoteById(noteId);

        // Assert
        expect(retrievedNote, isNotNull);
        expect(retrievedNote!.title, equals('Test Note'));
        expect(retrievedNote.content, equals('Test content'));
      });

      test('should update a note successfully', () async {
        // Arrange
        final note = Note(
          title: 'Original Title',
          content: 'Original content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        final noteId = await repository.insertNote(note);
        final updatedNote = note.copyWith(
          id: noteId,
          title: 'Updated Title',
          content: 'Updated content',
        );

        // Act
        await repository.updateNote(updatedNote);
        final retrievedNote = await repository.getNoteById(noteId);

        // Assert
        expect(retrievedNote, isNotNull);
        expect(retrievedNote!.title, equals('Updated Title'));
        expect(retrievedNote.content, equals('Updated content'));
      });

      test('should delete a note successfully', () async {
        // Arrange
        final note = Note(
          title: 'Test Note',
          content: 'Test content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        final noteId = await repository.insertNote(note);

        // Act
        await repository.deleteNote(noteId);
        final retrievedNote = await repository.getNoteById(noteId);

        // Assert
        expect(retrievedNote, isNull);
      });

      test('should get all notes', () async {
        // Arrange
        final notes = [
          Note(
            title: 'Note 1',
            content: 'Content 1',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          Note(
            title: 'Note 2',
            content: 'Content 2',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];

        for (final note in notes) {
          await repository.insertNote(note);
        }

        // Act
        final allNotes = await repository.getAllNotes();

        // Assert
        expect(allNotes.length, equals(2));
        expect(allNotes[0].title, equals('Note 2')); // Should be in reverse order
        expect(allNotes[1].title, equals('Note 1'));
      });
    });

    group('Search Operations', () {
      setUp(() {
        if (repository is MockNoteRepository) {
          (repository as MockNoteRepository).addSampleData();
        }
      });

      test('should search notes by title', () async {
        // Act
        final results = await repository.searchNotes('Test');

        // Assert
        expect(results.length, greaterThan(0));
        expect(results.every((note) => 
          note.title.toLowerCase().contains('test'.toLowerCase()) ||
          note.content.toLowerCase().contains('test'.toLowerCase())
        ), isTrue);
      });

      test('should get recent notes', () async {
        // Act
        final recentNotes = await repository.getRecentNotes(limit: 3);

        // Assert
        expect(recentNotes.length, lessThanOrEqualTo(3));
        // Notes should be in descending order by updatedAt
        for (int i = 0; i < recentNotes.length - 1; i++) {
          expect(recentNotes[i].updatedAt, greaterThanOrEqualTo(recentNotes[i + 1].updatedAt));
        }
      });

      test('should get pending tasks', () async {
        // Act
        final pendingTasks = await repository.getPendingTasks();

        // Assert
        expect(pendingTasks.every((note) => note.content.contains('- [ ')), isTrue);
      });
    });

    group('Filter Operations', () {
      test('should get notes by folder', () async {
        // Arrange
        final note = Note(
          title: 'Folder Note',
          content: 'Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          folderName: 'Test Folder',
        );
        await repository.insertNote(note);

        // Act
        final folderNotes = await repository.getNotesByFolder('Test Folder');

        // Assert
        expect(folderNotes.length, greaterThan(0));
        expect(folderNotes.every((note) => note.folderName == 'Test Folder'), isTrue);
      });

      test('should get notes by tag', () async {
        // Arrange
        final note = Note(
          title: 'Tagged Note',
          content: 'Content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          tags: ['flutter', 'test'],
        );
        await repository.insertNote(note);

        // Act
        final taggedNotes = await repository.getNotesByTag('flutter');

        // Assert
        expect(taggedNotes.length, greaterThan(0));
        expect(taggedNotes.every((note) => note.tags.contains('flutter')), isTrue);
      });

      test('should get all folders', () async {
        // Arrange
        final folders = ['Work', 'Personal', 'Projects'];
        for (final folder in folders) {
          final note = Note(
            title: 'Note in $folder',
            content: 'Content',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            folderName: folder,
          );
          await repository.insertNote(note);
        }

        // Act
        final allFolders = await repository.getAllFolders();

        // Assert
        expect(allFolders.length, greaterThanOrEqualTo(folders.length));
        expect(allFolders.contains('Genel'), isTrue); // Default folder should always be present
      });
    });

    group('Batch Operations', () {
      test('should insert multiple notes', () async {
        // Arrange
        final notes = [
          Note(
            title: 'Batch Note 1',
            content: 'Content 1',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          Note(
            title: 'Batch Note 2',
            content: 'Content 2',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];

        // Act
        await repository.insertNotes(notes);
        final allNotes = await repository.getAllNotes();

        // Assert
        expect(allNotes.length, greaterThanOrEqualTo(2));
      });

      test('should delete multiple notes', () async {
        // Arrange
        final noteIds = <int>[];
        for (int i = 0; i < 3; i++) {
          final note = Note(
            title: 'Note $i',
            content: 'Content $i',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          final id = await repository.insertNote(note);
          noteIds.add(id);
        }

        // Act
        await repository.deleteNotes(noteIds.take(2).toList());
        final remainingNotes = await repository.getAllNotes();

        // Assert
        expect(remainingNotes.length, equals(1));
      });
    });

    group('Statistics', () {
      test('should get database statistics', () async {
        // Arrange
        final notes = [
          Note(
            title: 'Regular Note',
            content: 'Regular content',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          Note(
            title: 'Task Note',
            content: 'Task - [ ] incomplete',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];

        for (final note in notes) {
          await repository.insertNote(note);
        }

        // Act
        final stats = await repository.getDatabaseStats();

        // Assert
        expect(stats['totalNotes'], equals(2));
        expect(stats['totalTasks'], equals(1));
        expect(stats['lastNoteDate'], isNotNull);
      });
    });
  });
}
