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
        'createdAt': 1234567890,
        'updatedAt': 1234567890,
        'isEncrypted': true,
        'tags': ['tag1', 'tag2'],
        'color': 0xFFFFFFFF,
        'folderName': 'Genel',
      };

      final note = Note.fromJson(json);

      expect(note.id, 1);
      expect(note.title, 'Test Title');
      expect(note.content, 'Test Content');
      expect(note.createdAt, 1234567890);
      expect(note.updatedAt, 1234567890);
      expect(note.isEncrypted, true);
      expect(note.tags, ['tag1', 'tag2']);
      expect(note.color, 0xFFFFFFFF);
      expect(note.folderName, 'Genel');
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
        folderName: 'Genel',
      );

      final json = note.toJson();

      expect(json['id'], 1);
      expect(json['title'], 'Test Title');
      expect(json['content'], 'Test Content');
      expect(json['createdAt'], 1234567890);
      expect(json['updatedAt'], 1234567890);
      expect(json['isEncrypted'], true);
      expect(json['tags'], ['tag1', 'tag2']);
      expect(json['color'], 0xFFFFFFFF);
      expect(json['folderName'], 'Genel');
    });

    test('Note toJson/fromJson roundtrip preserves data', () {
      final originalNote = Note(
        id: 123,
        title: 'Roundtrip Test',
        content: 'Test content with [[links]] and #hashtags',
        createdAt: 1640995200000, // 2022-01-01
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: ['test', 'roundtrip', 'json'],
        color: 0xFFE3F2FD,
        folderName: 'Test Folder',
      );

      final json = originalNote.toJson();
      final restoredNote = Note.fromJson(json);

      expect(restoredNote.id, originalNote.id);
      expect(restoredNote.title, originalNote.title);
      expect(restoredNote.content, originalNote.content);
      expect(restoredNote.createdAt, originalNote.createdAt);
      expect(restoredNote.updatedAt, originalNote.updatedAt);
      expect(restoredNote.isEncrypted, originalNote.isEncrypted);
      expect(restoredNote.tags, originalNote.tags);
      expect(restoredNote.color, originalNote.color);
      expect(restoredNote.folderName, originalNote.folderName);
    });

    test('Note fromJson handles missing fields gracefully', () {
      final json = {
        'id': 1,
        'title': 'Test Title',
        'content': 'Test Content',
      };

      final note = Note.fromJson(json);

      expect(note.id, 1);
      expect(note.title, 'Test Title');
      expect(note.content, 'Test Content');
      expect(note.createdAt, 0);
      expect(note.updatedAt, 0);
      expect(note.isEncrypted, false);
      expect(note.tags, []);
      expect(note.color, null);
      expect(note.folderName, 'Genel');
    });

    test('Note excerpt extraction', () {
      final note = Note(
        id: 1,
        title: 'Test Note',
        content: 'This is a long content that should be truncated when creating an excerpt. It contains multiple sentences and should be properly handled.',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: false,
        tags: [],
      );

      final excerpt = note.excerpt;
      expect(excerpt, isNotEmpty);
      expect(excerpt.length, lessThanOrEqualTo(100));
    });

    test('Note link extraction', () {
      final note = Note(
        id: 1,
        title: 'Test Note',
        content: 'This note has [[link1]] and [[link2]] references.',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: false,
        tags: [],
      );

      final links = note.extractLinks();
      expect(links.length, 2);
      expect(links, contains('link1'));
      expect(links, contains('link2'));
    });

    test('Note word count calculation', () {
      final note = Note(
        id: 1,
        title: 'Test Note',
        content: 'This is a test content with five words.',
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: false,
        tags: [],
      );

      expect(note.wordCount, 5);
    });

    test('Note reading time calculation', () {
      final note = Note(
        id: 1,
        title: 'Test Note',
        content: 'This is a test content with multiple words. ' * 20, // ~100 words
        createdAt: 1234567890,
        updatedAt: 1234567890,
        isEncrypted: false,
        tags: [],
      );

      final readingTime = note.readingTime;
      expect(readingTime, greaterThan(0));
      expect(readingTime, lessThan(5)); // Should be less than 5 minutes
    });
  });
}