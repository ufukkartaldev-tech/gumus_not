import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/models/note_model.dart';

void main() {
  group('Note Model Tests', () {
    test('Note creation with valid data', () {
      final note = Note(
        id: 1,
        title: 'Test Title',
        content: 'Test Content',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: false,
        tags: ['tag1', 'tag2'],
        color: 0xFFFFFFFF,
      );

      expect(note.id, 1);
      expect(note.title, 'Test Title');
      expect(note.content, 'Test Content');
      expect(note.createdAt, 1234567890);
      expect(note.updatedAt, 1234567890);
      expect(note.isEncrypted, false);
      expect(note.tags, ['tag1', 'tag2']);
      expect(note.color, 0xFFFFFFFF);
    });

    test('Note copyWith creates new instance with updated values', () {
      final originalNote = Note(
        id: 1,
        title: 'Original Title',
        content: 'Original Content',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: false,
        tags: [],
        color: 0xFFFFFFFF,
      );

      final updatedNote = originalNote.copyWith(title: 'Updated Title');

      expect(updatedNote.id, 1);
      expect(updatedNote.title, 'Updated Title');
      expect(updatedNote.content, 'Original Content');
      expect(updatedNote.createdAt, 1234567890);
      expect(updatedNote.updatedAt, 1234567890);
      expect(updatedNote.isEncrypted, false);
      expect(updatedNote.tags, []);
      expect(updatedNote.color, 0xFFFFFFFF);
    });

    test('Note equality comparison', () {
      final note1 = Note(
        id: 1,
        title: 'Title',
        content: 'Content',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: false,
        tags: [],
        color: 0xFFFFFFFF,
      );

      final note2 = Note(
        id: 1,
        title: 'Title',
        content: 'Content',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: false,
        tags: [],
        color: 0xFFFFFFFF,
      );

      expect(note1, equals(note2));
    });

    test('Note fromJson creates instance correctly', () {
      final json = {
        'id': 1,
        'title': 'Test Title',
        'content': 'Test Content',
        'created_at': 1234567890,
        'updated_at': 1234567890,
        'is_encrypted': 1,
        'tags': 'tag1,tag2',
        'color': 0xFFFFFFFF,
        'folder_name': 'Genel',
      };

      final note = Note.fromMap(json);

      expect(note.id, 1);
      expect(note.title, 'Test Title');
      expect(note.content, 'Test Content');
      expect(note.createdAt, 1234567890);
      expect(note.updatedAt, 1234567890);
      expect(note.isEncrypted, true);
      expect(note.tags, ['tag1', 'tag2']);
      expect(note.color, 0xFFFFFFFF);
    });

    test('Note toJson creates correct map', () {
      final note = Note(
        id: 1,
        title: 'Test Title',
        content: 'Test Content',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: true,
        tags: ['tag1', 'tag2'],
        color: 0xFFFFFFFF,
      );

      final json = note.toMap();

      expect(json['id'], 1);
      expect(json['title'], 'Test Title');
      expect(json['content'], 'Test Content');
      expect(json['created_at'], 1234567890);
      expect(json['updated_at'], 1234567890);
      expect(json['is_encrypted'], 1);
      expect(json['tags'], 'tag1,tag2');
      expect(json['folder_name'], 'Genel');
    });
  });
}