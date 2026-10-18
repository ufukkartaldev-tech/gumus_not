import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:connected_notebook/core/security/note_encryption_service.dart';
import 'package:connected_notebook/core/storage/note_markdown_codec.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/services/git_sync_service.dart';

class _CachedNoteEntry {
  const _CachedNoteEntry({
    required this.note,
    required this.modified,
    required this.size,
  });

  final Note note;
  final DateTime modified;
  final int size;
}

/// File-backed [NoteRepository]: every note is a standalone markdown file
/// with YAML frontmatter under `<documents>/GumusNot/notes`. Changes are
/// committed to a local git repository when git is available, which gives
/// note history for free.
///
/// Uses an in-memory cache backed by asynchronous file I/O and incremental
/// `FileStat` checks so repeated queries (search, backlinks, folders, tags)
/// never block the UI thread or re-parse unchanged markdown files.
class MarkdownNoteRepository implements NoteRepository {
  MarkdownNoteRepository({
    GitSyncService? gitSyncService,
    NoteEncryptionService? encryptionService,
    bool enableGit = true,
    Future<Directory> Function()? notesDirResolver,
    Duration cacheTtl = const Duration(seconds: 2),
  })  : _gitSyncService = gitSyncService ?? GitSyncService(),
        _encryption = encryptionService ?? NoteEncryptionService(),
        _enableGit = enableGit,
        _notesDirResolver = notesDirResolver,
        _cacheTtl = cacheTtl;

  final GitSyncService _gitSyncService;
  final NoteEncryptionService _encryption;
  final bool _enableGit;
  final Future<Directory> Function()? _notesDirResolver;
  final Duration _cacheTtl;

  final Map<String, _CachedNoteEntry> _fileCache = {};
  final Map<int, String> _idToFilePath = {};
  List<Note>? _sortedCache;
  DateTime? _lastDirectorySync;
  int _debugDiskReadCount = 0;

  @visibleForTesting
  int get debugDiskReadCount => _debugDiskReadCount;

  bool get _isAvailable => !kIsWeb;

  String _normPath(String path) => p.normalize(path).toLowerCase();

  /// Forces the next query to rescan the notes directory for external changes.
  void invalidateCache() {
    _lastDirectorySync = null;
    _sortedCache = null;
  }

  Future<Directory> _notesDir() async {
    final Directory dir;
    final resolver = _notesDirResolver;
    if (resolver != null) {
      dir = await resolver();
    } else {
      dir = Directory(await _gitSyncService.getRepoPath());
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Note> _readAndCacheFile(File file, {FileStat? stat}) async {
    final fileStat = stat ?? await file.stat();
    _debugDiskReadCount++;
    final note = await NoteMarkdownCodec.deserializeFromFileAsync(file);
    final key = _normPath(file.path);
    _fileCache[key] = _CachedNoteEntry(
      note: note,
      modified: fileStat.modified,
      size: fileStat.size,
    );
    if (note.id != null) {
      _idToFilePath[note.id!] = file.path;
    }
    _sortedCache = null;
    return note;
  }

  Future<void> _cacheSavedNote(File file, Note savedNote) async {
    final stat = await file.stat();
    final key = _normPath(file.path);
    _fileCache[key] = _CachedNoteEntry(
      note: savedNote,
      modified: stat.modified,
      size: stat.size,
    );
    if (savedNote.id != null) {
      _idToFilePath[savedNote.id!] = file.path;
    }
    _sortedCache = null;
    _lastDirectorySync = DateTime.now();
  }

  void _evictFilePath(String path) {
    final key = _normPath(path);
    final removed = _fileCache.remove(key);
    if (removed?.note.id != null) {
      _idToFilePath.remove(removed!.note.id);
    }
    _sortedCache = null;
  }

  Future<void> _syncCacheWithDisk(Directory dir, {bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastDirectorySync != null &&
        now.difference(_lastDirectorySync!) < _cacheTtl &&
        _fileCache.isNotEmpty) {
      return;
    }

    final seenKeys = <String>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (!NoteMarkdownCodec.isNoteFileName(fileName)) continue;

      final key = _normPath(entity.path);
      seenKeys.add(key);

      final stat = await entity.stat();
      final cached = _fileCache[key];
      if (cached != null &&
          cached.modified.isAtSameMomentAs(stat.modified) &&
          cached.size == stat.size) {
        if (cached.note.id != null) {
          _idToFilePath[cached.note.id!] = entity.path;
        }
        continue;
      }

      try {
        await _readAndCacheFile(entity, stat: stat);
      } catch (_) {}
    }

    final staleKeys =
        _fileCache.keys.where((k) => !seenKeys.contains(k)).toList();
    if (staleKeys.isNotEmpty) {
      for (final stale in staleKeys) {
        final removed = _fileCache.remove(stale);
        if (removed?.note.id != null) {
          final currentMapped = _idToFilePath[removed!.note.id!];
          if (currentMapped != null && _normPath(currentMapped) == stale) {
            _idToFilePath.remove(removed.note.id!);
          }
        }
      }
      _sortedCache = null;
    }

    _lastDirectorySync = DateTime.now();
  }

  Future<File?> _findFileById(Directory dir, int id) async {
    final cachedPath = _idToFilePath[id];
    if (cachedPath != null) {
      final cachedFile = File(cachedPath);
      if (await cachedFile.exists()) {
        return cachedFile;
      }
      _evictFilePath(cachedPath);
    }

    // Legacy fallback: `<id>.md`
    final legacyFile = File(p.join(dir.path, '$id.md'));
    if (await legacyFile.exists()) {
      try {
        final note = await _readAndCacheFile(legacyFile);
        if (note.id == id) {
          return legacyFile;
        }
      } catch (_) {}
    }

    await _syncCacheWithDisk(dir, force: true);
    final resolvedPath = _idToFilePath[id];
    if (resolvedPath != null) {
      final file = File(resolvedPath);
      if (await file.exists()) return file;
    }
    return null;
  }

  Future<void> _writeAndReplaceOldFile({
    required Directory dir,
    required Note noteToSave,
    required File? existingFile,
  }) async {
    final targetFile = await NoteMarkdownCodec.resolveUniqueFileAsync(
      dir,
      noteToSave,
      currentFile: existingFile,
    );

    if (existingFile != null &&
        await existingFile.exists() &&
        existingFile.path != targetFile.path &&
        _normPath(existingFile.path) == _normPath(targetFile.path)) {
      await existingFile.rename(targetFile.path);
    }

    await targetFile.writeAsString(NoteMarkdownCodec.serialize(noteToSave));

    if (existingFile != null &&
        _normPath(existingFile.path) != _normPath(targetFile.path)) {
      _evictFilePath(existingFile.path);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }
    }

    await _cacheSavedNote(targetFile, noteToSave);
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
    if (!note.isEncrypted ||
        NoteEncryptionService.isEncryptedPayload(note.content)) {
      return note.content;
    }
    return _encryption.encrypt(note.content);
  }

  @override
  Future<List<Note>> getAllNotes() async {
    if (!_isAvailable) return [];
    final dir = await _notesDir();
    await _syncCacheWithDisk(dir);

    final cachedSorted = _sortedCache;
    if (cachedSorted != null) {
      return List<Note>.from(cachedSorted);
    }

    final notes = _fileCache.values.map((e) => e.note).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _sortedCache = notes;
    return List<Note>.from(notes);
  }

  @override
  Future<Note?> getNoteById(int id) async {
    if (!_isAvailable) return null;
    final dir = await _notesDir();
    final file = await _findFileById(dir, id);
    if (file == null || !await file.exists()) return null;

    final key = _normPath(file.path);
    final stat = await file.stat();
    final cached = _fileCache[key];
    if (cached != null &&
        cached.modified.isAtSameMomentAs(stat.modified) &&
        cached.size == stat.size) {
      return cached.note;
    }

    return _readAndCacheFile(file, stat: stat);
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
    final file = await NoteMarkdownCodec.resolveUniqueFileAsync(dir, toSave);
    await file.writeAsString(NoteMarkdownCodec.serialize(toSave));
    await _cacheSavedNote(file, toSave);
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
    final existingFile = await _findFileById(dir, id);

    // A locked note re-saved without unlocking carries only the placeholder
    // in its content; persisting it would destroy the stored ciphertext.
    if (note.isEncrypted &&
        note.content == NoteEncryptionService.lockedNotePlaceholder &&
        existingFile != null &&
        await existingFile.exists()) {
      final existingKey = _normPath(existingFile.path);
      final existingNote = _fileCache[existingKey]?.note ??
          await _readAndCacheFile(existingFile);
      final toSave = note.copyWith(
        content: existingNote.content,
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
    final file = await _findFileById(dir, id);
    if (file != null && await file.exists()) {
      _evictFilePath(file.path);
      await file.delete();
      await _commit('Delete note: $id');
    }
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final allNotes = await getAllNotes();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allNotes;
    return allNotes
        .where((note) =>
            note.title.toLowerCase().contains(q) ||
            note.tags.any((tag) => tag.toLowerCase().contains(q)) ||
            (!note.isEncrypted && note.content.toLowerCase().contains(q)))
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
    final taskNoteCount = allNotes
        .where((note) => RegExp(r'- \[ \]').hasMatch(note.content))
        .length;
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
