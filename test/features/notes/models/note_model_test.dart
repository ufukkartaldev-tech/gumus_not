import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

void main() {
  group('Note Model Tests', () {
    test('Should create a valid Note instance', () {
      final note = Note(
        id: 1,
        title: 'Test Note',
        content: 'This is a test note content.',
        folderName: 'Genel',
        createdAt: 100000,
        updatedAt: 100000,
        tags: ['test', 'flutter'],
        isEncrypted: false,
      );

      expect(note.id, 1);
      expect(note.title, 'Test Note');
      expect(note.content, 'This is a test note content.');
      expect(note.tags, contains('flutter'));
    });

    test('Should convert Note to Map correctly', () {
      final note = Note(
        id: 1,
        title: 'Map Note',
        content: 'Map content',
        createdAt: 12345,
        updatedAt: 67890,
      );

      final map = note.toMap();

      expect(map['id'], 1);
      expect(map['title'], 'Map Note');
      expect(map['content'], 'Map content');
      expect(map['folder_name'], 'Genel'); // Default
    });

    test('Should create Note from Map correctly', () {
      final map = {
        'id': 2,
        'title': 'From Map',
        'content': 'Hello World',
        'created_at': 1000,
        'updated_at': 2000,
        'folder_name': 'Work',
        'tags': 'work,test',
        'is_encrypted': 0,
      };

      final note = Note.fromMap(map);

      expect(note.id, 2);
      expect(note.title, 'From Map');
      expect(note.content, 'Hello World');
      expect(note.folderName, 'Work');
      expect(note.tags.length, 2);
      expect(note.tags, contains('work'));
    });

    test('Should copy Note with updated fields using copyWith', () {
      final note = Note(
        id: 1,
        title: 'Original Title',
        content: 'Original content',
        createdAt: 100,
        updatedAt: 100,
      );

      final updatedNote = note.copyWith(
        title: 'New Title',
        content: 'New content',
      );

      expect(updatedNote.id, 1);
      expect(updatedNote.title, 'New Title');
      expect(updatedNote.content, 'New content');
      expect(updatedNote.createdAt, 100);
      expect(updatedNote.folderName, 'Genel');
    });
  });
}
