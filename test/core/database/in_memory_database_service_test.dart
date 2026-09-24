import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/database/idatabase_service.dart';

void main() {
  group('InMemoryDatabaseService CRUD Tests', () {
    late InMemoryDatabaseService dbService;

    setUp(() {
      dbService = InMemoryDatabaseService();
    });

    test('Should insert note and auto-increment ID', () async {
      final note1 = {
        'title': 'Test 1',
        'content': 'Content 1',
      };
      
      final note2 = {
        'title': 'Test 2',
        'content': 'Content 2',
      };

      final id1 = await dbService.insertNote(note1);
      final id2 = await dbService.insertNote(note2);

      expect(id1, 1);
      expect(id2, 2);

      final allNotes = await dbService.getAllNotes();
      expect(allNotes.length, 2);
    });

    test('Should update an existing note without changing ID', () async {
      final id = await dbService.insertNote({
        'title': 'Old Title',
        'content': 'Old Content',
      });

      final updatedNote = {
        'id': id,
        'title': 'New Title',
        'content': 'New Content',
      };

      final updatedRowCount = await dbService.updateNote(updatedNote);
      expect(updatedRowCount, 1);

      final retrieved = await dbService.getNoteById(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.first['title'], 'New Title');
    });

    test('Should delete a note and not return it', () async {
      final id = await dbService.insertNote({
        'title': 'Delete Me',
      });

      final allBefore = await dbService.getAllNotes();
      expect(allBefore.length, 1);

      final deletedRowCount = await dbService.deleteNote(id);
      expect(deletedRowCount, 1);

      final allAfter = await dbService.getAllNotes();
      expect(allAfter.length, 0);

      final retrieved = await dbService.getNoteById(id);
      expect(retrieved, isNull); // or empty depending on implementation
    });

    test('Should return all notes sorted (if applicable)', () async {
      await dbService.insertNote({'id': 1, 'title': 'A'});
      await dbService.insertNote({'id': 2, 'title': 'B'});

      final notes = await dbService.getAllNotes();
      expect(notes.length, 2);
      expect(notes[0]['title'], 'A');
      expect(notes[1]['title'], 'B');
    });
  });
}
