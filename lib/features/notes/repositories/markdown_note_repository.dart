import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/core/storage/note_markdown_codec.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/services/git_sync_service.dart';

/// File-backed [NoteRepository]: every note is a standalone markdown file
/// with YAML frontmatter under `<documents>/GumusNot/notes`. Changes are
/// committed to a local git repository when git is available, which gives
/// note history for free.
///
/// Notes flagged `isEncrypted` have their body stored as an AES-256-GCM
/// payload (see [NoteEncryptionService]); frontmatter metadata stays
/// readable so title/tag search still works. Bodies produced before real
/// encryption existed were plain text and remain readable until the next
/// save re-encrypts them.
///
/// Backlinks are derived from note content on demand instead of being stored,
/// so the files always remain the single source of truth.
class MarkdownNoteRepository implements NoteRepository {
  MarkdownNoteRepository({
    GitSyncService? gitSyncService,
    NoteEncryptionService? encryptionService,
    bool enableGit = true,
    Future<Directory> Function()? notesDirResolver,
  })  : _gitSyncService = gitSyncService ?? GitSyncService(),
        _encryption = encryptionService ?? NoteEncryptionService(),
        _enableGit = enableGit,
        _notesDirResolver = notesDirResolver;

  final GitSyncService _gitSyncService;
  final NoteEncryptionService _encryption;
  final bool _enableGit;
  final Future<Directory> Function()? _notesDirResolver;
  final Map<int, String> _idToFilePath = {};

  bool get _isAvailable => !kIsWeb;

  Future<Directory> _notesDir() async {
    final Directory dir;
    if (_notesDirResolver != null) {
      dir = await _notesDirResolver!();
    } else {
      dir = Directory(await _gitSyncService.getRepoPath());
    }
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  File? _findFileById(Directory dir, int id) {
    final cachedPath = _idToFilePath[id];
    if (cachedPath != null) {
      final cachedFile = File(cachedPath);
      if (cachedFile.existsSync()) {
        try {
          if (NoteMarkdownCodec.deserializeFromFile(cachedFile).id == id) {
            return cachedFile;
          }
        } catch (_) {}
      }
      _idToFilePath.remove(id);
    }

    // Legacy fallback: `<id>.md`
    final legacyFile = File(p.join(dir.path, '$id.md'));
    if (legacyFile.existsSync()) {
      try {
        if (NoteMarkdownCodec.deserializeFromFile(legacyFile).id == id) {
          _idToFilePath[id] = legacyFile.path;
          return legacyFile;
        }
      } catch (_) {}
    }

    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (!NoteMarkdownCodec.isNoteFileName(fileName)) continue;
      try {
        final note = NoteMarkdownCodec.deserializeFromFile(entity);
        if (note.id != null) {
          _idToFilePath[note.id!] = entity.path;
          if (note.id == id) return entity;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _writeAndReplaceOldFile({
    required Directory dir,
    required Note noteToSave,
    required File? existingFile,
  }) async {
    final targetFile = NoteMarkdownCodec.resolveUniqueFile(
      dir,
      noteToSave,
      currentFile: existingFile,
    );

    if (existingFile != null &&
        existingFile.existsSync() &&
        existingFile.path != targetFile.path &&
        existingFile.path.toLowerCase() == targetFile.path.toLowerCase()) {
      await existingFile.rename(targetFile.path);
    }

    await targetFile.writeAsString(NoteMarkdownCodec.serialize(noteToSave));

    if (existingFile != null &&
        existingFile.existsSync() &&
        existingFile.path.toLowerCase() != targetFile.path.toLowerCase()) {
      await existingFile.delete();
    }

    if (noteToSave.id != null) {
      _idToFilePath[noteToSave.id!] = targetFile.path;
    }
  }

  Future<void> _commit(String message) async {
    if (!_enableGit) return;
    try {
      await _gitSyncService.initRepo();
      await _gitSyncService.commitChanges(message);
    } catch (_) {
      // Git is optional; file persistence must never depend on it.
    }
  }

  /// Returns the body to store for [note]: plaintext unless the note is
  /// flagged encrypted. Already-encrypted payloads (internal re-saves) pass
  /// through unchanged; anything else is sealed with the vault key.
  Future<String> _persistableBody(Note note) async {
    if (!note.isEncrypted || NoteEncryptionService.isEncryptedPayload(note.content)) {
      return note.content;
    }
    return _encryption.encrypt(note.content);
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
      final note = NoteMarkdownCodec.deserializeFromFile(entity);
      if (note.id != null) {
        _idToFilePath[note.id!] = entity.path;
      }
      notes.add(note);
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<Note?> getNoteById(int id) async {
    if (!_isAvailable) return null;
    final dir = await _notesDir();
    final file = _findFileById(dir, id);
    if (file == null || !file.existsSync()) return null;
    return NoteMarkdownCodec.deserializeFromFile(file);
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
    final existingIds =
        (await getAllNotes()).map((n) => n.id).whereType<int>().toSet();

    var id = note.id ?? DateTime.now().millisecondsSinceEpoch;
    while (existingIds.contains(id)) {
      id++;
    }

    final body = await _persistableBody(note);
    final toSave = note.copyWith(id: id, content: body);
    final file = NoteMarkdownCodec.resolveUniqueFile(dir, toSave);
    await file.writeAsString(NoteMarkdownCodec.serialize(toSave));
    _idToFilePath[id] = file.path;
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
    final existingFile = _findFileById(dir, id);

    // A locked note re-saved without unlocking carries only the placeholder
    // in its content; persisting it would destroy the stored ciphertext.
    if (note.isEncrypted &&
        note.content == NoteEncryptionService.lockedNotePlaceholder &&
        existingFile != null &&
        existingFile.existsSync()) {
      final existing = NoteMarkdownCodec.deserializeFromFile(existingFile);
      final toSave = note.copyWith(
        content: existing.content,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _writeAndReplaceOldFile(
        dir: dir,
        noteToSave: toSave,
        existingFile: existingFile,
      );
      await _commit('Update note metadata: ${note.title}');
      return;
    }

    final body = await _persistableBody(note);
    final toSave = note.copyWith(
      content: body,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _writeAndReplaceOldFile(
      dir: dir,
      noteToSave: toSave,
      existingFile: existingFile,
    );
    await _commit('Update note: ${note.title}');
  }

  @override
  Future<void> deleteNote(int id) async {
    if (!_isAvailable) return;
    final dir = await _notesDir();
    final file = _findFileById(dir, id);
    if (file != null && file.existsSync()) {
      await file.delete();
      _idToFilePath.remove(id);
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
