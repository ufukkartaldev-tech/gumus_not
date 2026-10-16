import 'package:connected_notebook/core/storage/markdown_frontmatter.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

/// Converts [Note] objects to and from single-file markdown documents with
/// YAML frontmatter. The note id lives in the file name (`<id>.md`); every
/// other field lives in the frontmatter.
class NoteMarkdownCodec {
  NoteMarkdownCodec._();

  static String fileNameFor(int id) => '$id.md';

  /// Returns the note id encoded in [fileName], or a stable fallback derived
  /// from the file name for hand-dropped markdown files without a numeric id.
  static int idFromFileName(String fileName) {
    final stem = fileName.endsWith('.md') ? fileName.substring(0, fileName.length - 3) : fileName;
    return int.tryParse(stem) ?? stem.hashCode.abs();
  }

  static bool isNoteFileName(String fileName) =>
      fileName.endsWith('.md') && !fileName.startsWith('.');

  static String serialize(Note note) {
    return MarkdownFrontmatter.encode({
      'title': note.title,
      'createdAt': note.createdAt,
      'updatedAt': note.updatedAt,
      'isEncrypted': note.isEncrypted,
      'folderName': note.folderName,
      'color': note.color,
      'emojiIcon': note.emojiIcon,
      'tags': note.tags,
    }, note.content);
  }

  static Note deserialize(int id, String raw) {
    final (meta, body) = MarkdownFrontmatter.decode(raw);
    return Note(
      id: id,
      title: MarkdownFrontmatter.getString(meta, 'title') ?? 'Untitled',
      content: body,
      createdAt: MarkdownFrontmatter.getInt(meta, 'createdAt') ?? 0,
      updatedAt: MarkdownFrontmatter.getInt(meta, 'updatedAt') ?? 0,
      isEncrypted: MarkdownFrontmatter.getBool(meta, 'isEncrypted'),
      tags: MarkdownFrontmatter.getStringList(meta, 'tags'),
      color: MarkdownFrontmatter.getInt(meta, 'color'),
      folderName: MarkdownFrontmatter.getString(meta, 'folderName') ?? 'Genel',
      emojiIcon: MarkdownFrontmatter.getString(meta, 'emojiIcon'),
    );
  }
}
