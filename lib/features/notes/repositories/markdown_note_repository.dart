import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:connected_notebook/core/storage/note_markdown_codec.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/services/git_sync_service.dart';

/// File-backed [NoteRepository]: every note is a standalone markdown file
/// with YAML frontmatter under `<documents>/GumusNot/notes`. Changes are
/// committed to a local git repository when git is available, which gives
/// note history for free.
///
/// Backlinks are derived from note content on demand instead of being stored,
/// so the files always remain the single source of truth.
class MarkdownNoteRepository implements NoteRepository {
  MarkdownNoteRepository([GitSyncService? gitSyncService])
      : _gitSyncService = gitSyncService ?? GitSyncService();

  final GitSyncService _gitSyncService;

  bool get _isAvailable => !kIsWeb;

  Future<Directory> _notesDir() async {
    final dir = Directory(await _gitSyncService.getRepoPath());
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> _fileFor(Directory dir, int id) =>
      Future.value(File(p.join(dir.path, NoteMarkdownCodec.fileNameFor(id))));

  Future<void> _commit(String message) async {
    try {
      await _gitSyncService.initRepo();
      await _gitSyncService.commitChanges(message);
    } catch (_) {
      // Git is optional; file persistence must never depend on it.
    }
  }

  @override
  Future<List<Note>> getAllNotes() async {
    if (!_isAvailable) return [];
    final dir = await _notesDir();
    final notes = <Note>[];
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (!NoteMarkdownCodec.isNoteFileName(fileName)) continue;
      final raw = entity.readAsStringSync();
      notes.add(NoteMarkdownCodec.deserialize(
        NoteMarkdownCodec.idFromFileName(fileName),
        raw,
      ));
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<Note?> getNoteById(int id) async {
    if (!_isAvailable) return null;
    final dir = await _notesDir();
    final file = await _fileFor(dir, id);
    if (!file.existsSync()) return null;
    return NoteMarkdownCodec.deserialize(id, file.readAsStringSync());
  }

  @override
  Future<int> addNote(Note note) async {
    if (!_isAvailable) {
      throw UnsupportedError(
        'Notes are stored as markdown files, which requires a platform '
        'filesystem; this operation is not supported on the web.',
      );
    }
    final dir = await _notesDir();

    var id = note.id ?? DateTime.now().millisecondsSinceEpoch;
    var file = await _fileFor(dir, id);
    while (file.existsSync()) {
      id++;
      file = await _fileFor(dir, id);
    }

    await file.writeAsString(NoteMarkdownCodec.serialize(note.copyWith(id: id)));
    await _commit('Add note: ${note.title}');
    return id;
  }

  @override
  Future<void> updateNote(Note note) async {
    if (!_isAvailable) {
      throw UnsupportedError('Note file updates are not supported on the web.');
    }
    final id = note.id;
    if (id == null) {
      await addNote(note);
      return;
    }
    final dir = await _notesDir();
    final file = await _fileFor(dir, id);
    final toSave = note.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    await file.writeAsString(NoteMarkdownCodec.serialize(toSave));
    await _commit('Update note: ${note.title}');
  }

  @override
  Future<void> deleteNote(int id) async {
    if (!_isAvailable) return;
    final dir = await _notesDir();
    final file = await _fileFor(dir, id);
    if (file.existsSync()) {
      await file.delete();
      await _commit('Delete note: $id');
    }
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final allNotes = await getAllNotes();
    final q = query.toLowerCase();
    return allNotes
        .where((note) =>
            note.title.toLowerCase().contains(q) ||
            note.content.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    final allNotes = await getAllNotes();
    return allNotes.take(limit).toList();
  }

  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    final allNotes = await getAllNotes();
    final pending = allNotes
        .where((note) => RegExp(r'- \[ \]').hasMatch(note.content))
        .take(limit)
        .toList();
    return pending;
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final allNotes = await getAllNotes();
    final taskNoteCount =
        allNotes.where((note) => RegExp(r'- \[ \]').hasMatch(note.content)).length;
    return {
      'totalNotes': allNotes.length,
      'totalTasks': taskNoteCount,
      'lastNoteDate': allNotes.isNotEmpty ? allNotes.first.updatedAt : null,
    };
  }

  // Backlinks are derived from content; there is nothing to persist.

  @override
  Future<List<Backlink>> getBacklinksForNote(int noteId) async {
    final allNotes = await getAllNotes();
    final target = allNotes.where((note) => note.id == noteId).toList();
    if (target.isEmpty) return [];

    final targetTitle = target.first.title.toLowerCase();
    final backlinks = <Backlink>[];
    for (final note in allNotes) {
      if (note.id == noteId) continue;
      for (final linkText in note.extractLinks()) {
        if (linkText.toLowerCase() == targetTitle) {
          backlinks.add(Backlink(
            sourceNoteId: note.id ?? -1,
            targetNoteId: noteId,
            linkText: linkText,
            createdAt: note.updatedAt,
          ));
        }
      }
    }
    return backlinks;
  }

  @override
  Future<List<Backlink>> getOutgoingLinksForNote(int noteId) async {
    final allNotes = await getAllNotes();
    final source = allNotes.where((note) => note.id == noteId).toList();
    if (source.isEmpty) return [];

    final byTitle = <String, Note>{
      for (final note in allNotes) note.title.toLowerCase(): note,
    };

    final links = <Backlink>[];
    for (final linkText in source.first.extractLinks()) {
      final resolved = byTitle[linkText.toLowerCase()];
      if (resolved == null || resolved.id == noteId) continue;
      links.add(Backlink(
        sourceNoteId: noteId,
        targetNoteId: resolved.id ?? -1,
        linkText: linkText,
        createdAt: source.first.updatedAt,
      ));
    }
    return links;
  }

  @override
  Future<void> updateBacklinks(Note note, List<Note> allNotes) async {}

  @override
  Future<List<String>> getFolders() async {
    final allNotes = await getAllNotes();
    final folders = allNotes.map((note) => note.folderName).toSet();
    if (!folders.contains('Genel')) folders.add('Genel');
    return folders.toList()..sort();
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) => note.folderName == folderName).length;
  }

  @override
  Future<List<Note>> getNotesByTag(String tag) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) => note.tags.contains(tag)).toList();
  }

  @override
  Future<Map<String, int>> getTagFrequency() async {
    final allNotes = await getAllNotes();
    final frequency = <String, int>{};
    for (final note in allNotes) {
      for (final tag in note.tags) {
        frequency[tag] = (frequency[tag] ?? 0) + 1;
      }
    }
    return frequency;
  }

  // Bulk helpers kept from the previous SQL-backed repository so callers
  // that import the concrete type keep working.

  Future<List<Note>> getNotesByFolder(String folderName) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) => note.folderName == folderName).toList();
  }

  Future<List<String>> getAllFolders() => getFolders();

  Future<void> insertNotes(List<Note> notes) async {
    for (final note in notes) {
      await addNote(note);
    }
  }

  Future<void> deleteNotes(List<int> noteIds) async {
    for (final id in noteIds) {
      await deleteNote(id);
    }
  }

  Future<List<Map<String, dynamic>>> exportAllNotes() async {
    final notes = await getAllNotes();
    return notes.map((note) => note.toJson()).toList();
  }

  Future<void> importNotes(List<Map<String, dynamic>> notesData) async {
    final notes = notesData.map(Note.fromJson).toList();
    await insertNotes(notes);
  }

  Future<void> close() async {}
}
