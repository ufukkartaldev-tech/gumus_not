import 'package:flutter_test/flutter_test.dart';
import '../lib/features/notes/services/note_service.dart';
import '../lib/features/notes/services/backlink_service.dart';
import '../lib/features/notes/repositories/mock_note_repository.dart';
import '../lib/features/notes/models/note_model.dart';

/// Test cases for Note Service
/// Following SOLID principles: Testable and maintainable code
void main() {
  group('NoteService Tests', () {
    late NoteService noteService;
    late MockNoteRepository mockRepository;

    setUp(() {
      mockRepository = MockNoteRepository();
      final backlinkService = BacklinkService(mockRepository);
      noteService = NoteService(mockRepository, backlinkService);
    });

    tearDown(() {
      mockRepository.clearAll();
    });

    group('Note Creation', () {
      test('should create a note with all parameters', () async {
        // Act
        final note = await noteService.createNote(
          title: 'Test Note',
          content: 'Test content with [[link]]',
          tags: ['test', 'sample'],
          folderName: 'Test Folder',
          color: 0xFF0000FF,
          isEncrypted: false,
        );

        // Assert
        expect(note, isNotNull);
        expect(note.title, equals('Test Note'));
        expect(note.content, equals('Test content with [[link]]'));
        expect(note.tags, contains('test'));
        expect(note.tags, contains('sample'));
        expect(note.folderName, equals('Test Folder'));
        expect(note.color, equals(0xFF0000FF));
        expect(note.isEncrypted, isFalse);
        expect(note.id, isNotNull);
        expect(note.id, greaterThan(0));
      });

      test('should create a note with default values', () async {
        // Act
        final note = await noteService.createNote(
          title: 'Simple Note',
          content: 'Simple content',
        );

        // Assert
        expect(note, isNotNull);
        expect(note.folderName, equals('Genel')); // Default folder
        expect(note.tags, isEmpty); // Default empty tags
        expect(note.color, isNull); // Default no color
        expect(note.isEncrypted, isFalse); // Default not encrypted
      });

      test('should validate note before creation', () async {
        // Test empty title
        expect(
          () => noteService.createNote(title: '', content: 'Content'),
          throwsA(anything),
        );

        // Test empty content
        expect(
          () => noteService.createNote(title: 'Title', content: ''),
          throwsA(anything),
        );

        // Test title too long
        expect(
          () => noteService.createNote(
            title: 'A' * 201, // 201 characters
            content: 'Content',
          ),
          throwsA(anything),
        );
      });
    });

    group('Note Update', () {
      test('should update an existing note', () async {
        // Arrange
        final originalNote = await noteService.createNote(
          title: 'Original Title',
          content: 'Original content',
        );

        // Act
        final updatedNote = await noteService.updateNote(
          originalNote.copyWith(
            title: 'Updated Title',
            content: 'Updated content',
          ),
        );

        // Assert
        expect(updatedNote.title, equals('Updated Title'));
        expect(updatedNote.content, equals('Updated content'));
        expect(updatedNote.updatedAt, greaterThan(originalNote.updatedAt));
      });

      test('should update timestamp when note is updated', () async {
        // Arrange
        final note = await noteService.createNote(
          title: 'Timestamp Test',
          content: 'Content',
        );
        final originalTimestamp = note.updatedAt;

        // Wait a bit to ensure different timestamp
        await Future.delayed(Duration(milliseconds: 10));

        // Act
        final updatedNote = await noteService.updateNote(
          note.copyWith(title: 'Updated'),
        );

        // Assert
        expect(updatedNote.updatedAt, greaterThan(originalTimestamp));
      });
    });

    group('Note Deletion', () {
      test('should delete a note successfully', () async {
        // Arrange
        final note = await noteService.createNote(
          title: 'To Delete',
          content: 'Content',
        );

        // Act
        await noteService.deleteNote(note.id!);
        final retrievedNote = await noteService.getNoteById(note.id!);

        // Assert
        expect(retrievedNote, isNull);
      });
    });

    group('Note Retrieval', () {
      setUp(() async {
        // Create sample data
        await noteService.createNote(
          title: 'Work Note',
          content: 'Work related content',
          tags: ['work'],
          folderName: 'Work',
        );

        await noteService.createNote(
          title: 'Personal Note',
          content: 'Personal content',
          tags: ['personal'],
          folderName: 'Personal',
        );

        await noteService.createNote(
          title: 'Task Note',
          content: 'Task - [ ] incomplete task',
          tags: ['task'],
        );
      });

      test('should get all notes', () async {
        // Act
        final allNotes = await noteService.getAllNotes();

        // Assert
        expect(allNotes.length, equals(3));
      });

      test('should get notes by folder', () async {
        // Act
        final workNotes = await noteService.getNotesByFolder('Work');
        final personalNotes = await noteService.getNotesByFolder('Personal');

        // Assert
        expect(workNotes.length, equals(1));
        expect(workNotes.first.title, equals('Work Note'));
        expect(personalNotes.length, equals(1));
        expect(personalNotes.first.title, equals('Personal Note'));
      });

      test('should get notes by tag', () async {
        // Act
        final workTaggedNotes = await noteService.getNotesByTag('work');
        final personalTaggedNotes = await noteService.getNotesByTag('personal');

        // Assert
        expect(workTaggedNotes.length, equals(1));
        expect(workTaggedNotes.first.title, equals('Work Note'));
        expect(personalTaggedNotes.length, equals(1));
        expect(personalTaggedNotes.first.title, equals('Personal Note'));
      });

      test('should get recent notes', () async {
        // Act
        final recentNotes = await noteService.getRecentNotes(limit: 2);

        // Assert
        expect(recentNotes.length, equals(2));
        // Should be in descending order by updatedAt
        for (int i = 0; i < recentNotes.length - 1; i++) {
          expect(recentNotes[i].updatedAt, greaterThanOrEqualTo(recentNotes[i + 1].updatedAt));
        }
      });

      test('should get pending tasks', () async {
        // Act
        final pendingTasks = await noteService.getPendingTasks();

        // Assert
        expect(pendingTasks.length, equals(1));
        expect(pendingTasks.first.title, equals('Task Note'));
        expect(pendingTasks.first.content, contains('- [ '));
      });
    });

    group('Statistics', () {
      test('should get tag frequency', () async {
        // Arrange
        await noteService.createNote(
          title: 'Note 1',
          content: 'Content',
          tags: ['flutter', 'dart'],
        );

        await noteService.createNote(
          title: 'Note 2',
          content: 'Content',
          tags: ['flutter', 'ui'],
        );

        await noteService.createNote(
          title: 'Note 3',
          content: 'Content',
          tags: ['dart'],
        );

        // Act
        final tagFrequency = await noteService.getTagFrequency();

        // Assert
        expect(tagFrequency['flutter'], equals(2));
        expect(tagFrequency['dart'], equals(2));
        expect(tagFrequency['ui'], equals(1));
      });

      test('should get folder statistics', () async {
        // Arrange
        await noteService.createNote(
          title: 'Work Note 1',
          content: 'Content',
          folderName: 'Work',
        );

        await noteService.createNote(
          title: 'Work Note 2',
          content: 'Content',
          folderName: 'Work',
        );

        await noteService.createNote(
          title: 'Personal Note',
          content: 'Content',
          folderName: 'Personal',
        );

        // Act
        final folderStats = await noteService.getFolderStats();

        // Assert
        expect(folderStats['Work'], equals(2));
        expect(folderStats['Personal'], equals(1));
      });

      test('should get comprehensive database stats', () async {
        // Arrange
        await noteService.createNote(
          title: 'Regular Note',
          content: 'Regular content',
        );

        await noteService.createNote(
          title: 'Task Note',
          content: 'Task - [ ] incomplete',
        );

        // Act
        final stats = await noteService.getDatabaseStats();

        // Assert
        expect(stats['totalNotes'], greaterThan(0));
        expect(stats['totalTasks'], greaterThan(0));
        expect(stats['totalTags'], greaterThan(0));
        expect(stats['totalFolders'], greaterThan(0);
        expect(stats['tagFrequency'], isA<Map<String, int>>());
        expect(stats['folderStats'], isA<Map<String, int>>());
      });
    });

    group('Batch Operations', () {
      test('should create multiple notes', () async {
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
        await noteService.createMultipleNotes(notes);
        final allNotes = await noteService.getAllNotes();

        // Assert
        expect(allNotes.length, greaterThanOrEqualTo(2));
      });

      test('should delete multiple notes', () async {
        // Arrange
        final noteIds = <int>[];
        for (int i = 0; i < 3; i++) {
          final note = await noteService.createNote(
            title: 'Note $i',
            content: 'Content $i',
          );
          noteIds.add(note.id!);
        }

        // Act
        await noteService.deleteMultipleNotes(noteIds.take(2).toList());
        final remainingNotes = await noteService.getAllNotes();

        // Assert
        expect(remainingNotes.length, equals(1));
      });
    });

    group('Utility Methods', () {
      test('should suggest tags based on content', () async {
        // Arrange
        await noteService.createNote(
          title: 'Flutter Tutorial',
          content: 'Learn flutter widgets',
          tags: ['flutter', 'tutorial'],
        );

        await noteService.createNote(
          title: 'Dart Guide',
          content: 'Dart programming language',
          tags: ['dart', 'programming'],
        );

        // Act
        final suggestions = await noteService.suggestTags('Learn flutter development');

        // Assert
        expect(suggestions, contains('flutter'));
      });

      test('should validate note data', () {
        // Valid note
        final validNote = Note(
          title: 'Valid Note',
          content: 'Valid content',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        expect(noteService.validateNote(validNote), isTrue);

        // Invalid notes
        final emptyTitleNote = validNote.copyWith(title: '');
        expect(noteService.validateNote(emptyTitleNote), isFalse);

        final emptyContentNote = validNote.copyWith(content: '');
        expect(noteService.validateNote(emptyContentNote), isFalse);

        final longTitleNote = validNote.copyWith(title: 'A' * 201);
        expect(noteService.validateNote(longTitleNote), isFalse);
      });
    });
  });
}
