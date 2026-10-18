import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:connected_notebook/core/storage/markdown_frontmatter.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

/// Converts [Note] objects to and from single-file markdown documents with
/// YAML frontmatter. Files are named after the note title (`<Başlık>.md`) so
/// they remain human-readable in external editors; the numeric `id` is stored
/// in the frontmatter.
class NoteMarkdownCodec {
  NoteMarkdownCodec._();

  static final RegExp _forbiddenChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static final RegExp _multiWhitespace = RegExp(r'\s+');
  static final RegExp _edgeDotsOrSpaces = RegExp(r'^[.\s]+|[.\s]+$');
  static final RegExp _reservedWindowsNames = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
    caseSensitive: false,
  );

  /// Sanitizes [title] into a cross-platform safe filename stem (without `.md`).
  static String sanitizeTitleForFileName(String title) {
    var stem = title
        .replaceAll(_forbiddenChars, ' ')
        .replaceAll(_multiWhitespace, ' ')
        .replaceAll(_edgeDotsOrSpaces, '');

    if (stem.isEmpty) {
      stem = 'Adsız Not';
    } else if (_reservedWindowsNames.hasMatch(stem)) {
      stem = '_$stem';
    }

    if (stem.length > 100) {
      stem = stem.substring(0, 100).replaceAll(_edgeDotsOrSpaces, '');
    }
    return stem.isEmpty ? 'Adsız Not' : stem;
  }

  /// Returns the preferred `.md` filename for [title].
  /// When [collisionIndex] > 1, appends ` (<collisionIndex>)` before `.md`.
  static String fileNameForTitle(String title, {int collisionIndex = 1}) {
    final stem = sanitizeTitleForFileName(title);
    if (collisionIndex <= 1) return '$stem.md';
    return '$stem ($collisionIndex).md';
  }

  /// Legacy helper kept for compatibility; prefers title when a [title] is given.
  static String fileNameFor(int id, {String? title}) {
    if (title != null && title.trim().isNotEmpty) {
      return fileNameForTitle(title);
    }
    return '$id.md';
  }

  /// Picks an available `.md` file in [dir] for [note] based on its title.
  /// If `<Başlık>.md` is already taken by another note, tries
  /// `<Başlık> (2).md`, `<Başlık> (3).md`, etc.
  static File resolveUniqueFile(
    Directory dir,
    Note note, {
    File? currentFile,
  }) {
    var index = 1;
    while (true) {
      final fileName = fileNameForTitle(note.title, collisionIndex: index);
      final candidate = File(p.join(dir.path, fileName));
      if (!candidate.existsSync()) {
        return candidate;
      }
      if (currentFile != null &&
          candidate.path.toLowerCase() == currentFile.path.toLowerCase()) {
        return candidate;
      }
      // Also allow overwriting if the existing file on disk has the same note ID.
      try {
        final existing = deserializeFromFile(candidate);
        if (note.id != null && existing.id == note.id) {
          return candidate;
        }
      } catch (_) {}
      index++;
    }
  }

  /// Returns the note id encoded in [fileName], or a stable fallback derived
  /// from the file name for hand-dropped markdown files without a numeric id.
  static int idFromFileName(String fileName) {
    final stem = fileName.endsWith('.md')
        ? fileName.substring(0, fileName.length - 3)
        : fileName;
    return int.tryParse(stem) ?? stem.hashCode.abs();
  }

  static String _titleFromFileName(String fileName) {
    final stem = fileName.endsWith('.md')
        ? fileName.substring(0, fileName.length - 3)
        : fileName;
    return stem.trim().isEmpty ? 'Untitled' : stem;
  }

  static bool isNoteFileName(String fileName) =>
      fileName.endsWith('.md') && !fileName.startsWith('.');

  static String serialize(Note note) {
    return MarkdownFrontmatter.encode({
      'id': note.id,
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

  static Note deserialize(int fallbackId, String raw, {String? fileName}) {
    final (meta, body) = MarkdownFrontmatter.decode(raw);
    final resolvedId = MarkdownFrontmatter.getInt(meta, 'id') ?? fallbackId;
    final defaultTitle =
        fileName != null ? _titleFromFileName(fileName) : 'Untitled';
    return Note(
      id: resolvedId,
      title: MarkdownFrontmatter.getString(meta, 'title') ?? defaultTitle,
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

  static Note deserializeFromFile(File file) {
    final fileName = p.basename(file.path);
    return deserialize(
      idFromFileName(fileName),
      file.readAsStringSync(),
      fileName: fileName,
    );
  }
}

