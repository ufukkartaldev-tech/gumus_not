import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/storage/markdown_frontmatter.dart';
import 'package:connected_notebook/core/storage/note_markdown_codec.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

void main() {
  group('MarkdownFrontmatter', () {
    test('roundtrips scalars and lists', () {
      final doc = MarkdownFrontmatter.encode({
        'title': 'Toplantı: "önemli"',
        'count': 42,
        'flag': true,
        'tags': ['iş', 'günlük'],
        'empty': <String>[],
        'nothing': null,
      }, 'Gövde metni');

      final (meta, body) = MarkdownFrontmatter.decode(doc);
      expect(body, 'Gövde metni');
      expect(MarkdownFrontmatter.getString(meta, 'title'), 'Toplantı: "önemli"');
      expect(MarkdownFrontmatter.getInt(meta, 'count'), 42);
      expect(MarkdownFrontmatter.getBool(meta, 'flag'), isTrue);
      expect(MarkdownFrontmatter.getStringList(meta, 'tags'), ['iş', 'günlük']);
      expect(meta.containsKey('empty'), isFalse);
      expect(meta.containsKey('nothing'), isFalse);
    });

    test('returns raw body for documents without frontmatter', () {
      final (meta, body) = MarkdownFrontmatter.decode('# Sadece markdown');
      expect(meta, isEmpty);
      expect(body, '# Sadece markdown');
    });

    test('keeps body readable when frontmatter is malformed', () {
      final (meta, body) = MarkdownFrontmatter.decode(
        '---\n::: bozuk :::\n---\n# Başlık',
      );
      expect(meta, isEmpty);
      expect(body, '# Başlık');
    });
  });

  group('NoteMarkdownCodec', () {
    final note = Note(
      id: 123,
      title: 'Araştırma: **fikirler**',
      content: '# İçerik\n\n- madde\n- [[Bağlantı]]',
      createdAt: 1760000000000,
      updatedAt: 1760000001000,
      isEncrypted: false,
      tags: ['araştırma', 'fikir'],
      color: 0xFFFF0000,
      folderName: 'İş',
      emojiIcon: '💡',
    );

    test('roundtrips every note field', () {
      final restored = NoteMarkdownCodec.deserialize(
        123,
        NoteMarkdownCodec.serialize(note),
      );
      expect(restored.id, 123);
      expect(restored.title, note.title);
      expect(restored.content, note.content);
      expect(restored.createdAt, note.createdAt);
      expect(restored.updatedAt, note.updatedAt);
      expect(restored.tags, note.tags);
      expect(restored.color, note.color);
      expect(restored.folderName, note.folderName);
      expect(restored.emojiIcon, note.emojiIcon);
      expect(restored.isEncrypted, isFalse);
    });

    test('stores id in the file name, not the frontmatter', () {
      final doc = NoteMarkdownCodec.serialize(note);
      expect(doc.startsWith('---\ntitle:'), isTrue);
      expect(doc.contains('id:'), isFalse);
      expect(NoteMarkdownCodec.fileNameFor(123), '123.md');
      expect(NoteMarkdownCodec.idFromFileName('123.md'), 123);
    });

    test('derives a stable id for hand-dropped files', () {
      final id = NoteMarkdownCodec.idFromFileName('my daily journal.md');
      expect(id, NoteMarkdownCodec.idFromFileName('my daily journal.md'));
      expect(id, isNonZero);
    });
  });
}
