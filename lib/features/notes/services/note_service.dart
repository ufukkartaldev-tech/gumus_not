import '../models/note_model.dart';
import '../repositories/note_repository.dart';
import 'backlink_service.dart';
import '../../../core/security/legacy_encryption_service_adapter.dart';

/// Main orchestration service for note operations.
///
/// Responsibilities:
/// - decide whether note content should be encrypted,
/// - keep backlink extraction in plaintext phase,
/// - delegate persistence to the repository layer,
/// - preserve the existing UI-facing API so screens do not break.
class NoteService {
  NoteService(
    this._repository,
    this._backlinkService, {
    LegacyEncryptionServiceAdapter? encryptionAdapter,
  }) : _encryptionAdapter = encryptionAdapter;

  final NoteRepository _repository;
  final BacklinkService _backlinkService;
  final LegacyEncryptionServiceAdapter? _encryptionAdapter;

  /// Create a new note with optional vault encryption.
  ///
  /// Backlinks are extracted from plaintext content before encryption so the
  /// relational graph remains usable even when the stored note body is
  /// encrypted at rest.
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
    String folderName = 'Genel',
    int? color,
    bool isEncrypted = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Backlink extraction must happen before encryption.
    final plainTextContent = content;
    final persistedContent = await _prepareContentForPersistence(
      content: plainTextContent,
      isEncrypted: isEncrypted,
    );

    final note = Note(
      title: title,
      content: persistedContent,
      tags: tags,
      folderName: folderName,
      color: color,
      isEncrypted: isEncrypted,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _repository.addNote(note);
    final createdNote = note.copyWith(id: id);

    // Preserve backlink graph using plaintext content.
    await _backlinkService.updateBacklinks(id, plainTextContent);

    return createdNote;
  }

  /// Update an existing note with optional re-encryption.
  ///
  /// The incoming [note] is treated as the UI/domain representation. If the
  /// note is marked encrypted, plaintext content is encrypted only at the final
  /// persistence stage and backlinks are still derived from plaintext.
  Future<Note> updateNote(Note note) async {
    final plainTextContent = note.content;
    final persistedContent = await _prepareContentForPersistence(
      content: plainTextContent,
      isEncrypted: note.isEncrypted,
    );

    final updatedNote = note.copyWith(
      content: persistedContent,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _repository.updateNote(updatedNote);

    // Backlinks are recalculated from plaintext content before-at-rest encryption.
    await _backlinkService.updateBacklinks(note.id, plainTextContent);

    return updatedNote;
  }

  /// Delete a note.
  Future<void> deleteNote(int noteId) async {
    await _repository.deleteNote(noteId);
  }

  /// Get a note by ID.
  Future<Note?> getNoteById(int id) async {
    return _repository.getNoteById(id);
  }

  /// Get all notes as stored.
  ///
  /// This method intentionally does not decrypt content eagerly. Doing so would
  /// widen plaintext lifetime in memory and make list loading more expensive.
  Future<List<Note>> getAllNotes() async {
    return _repository.getAllNotes();
  }

  Future<List<Note>> getNotesByFolder(String folderName) async {
    final allNotes = await _repository.getAllNotes();
    return allNotes.where((note) => note.folderName == folderName).toList();
  }

  Future<List<Note>> getNotesByTag(String tag) async {
    return _repository.getNotesByTag(tag);
  }

  Future<List<String>> getAllFolders() async {
    return _repository.getFolders();
  }

  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    return _repository.getRecentNotes(limit: limit);
  }

  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    return _repository.getPendingTasks(limit: limit);
  }

  Future<Map<String, int>> getTagFrequency() async {
    final allNotes = await _repository.getAllNotes();
    final tagFrequency = <String, int>{};

    for (final note in allNotes) {
      for (final tag in note.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }

    return tagFrequency;
  }

  Future<Map<String, int>> getFolderStats() async {
    final allNotes = await _repository.getAllNotes();
    final folderStats = <String, int>{};

    for (final note in allNotes) {
      folderStats[note.folderName] = (folderStats[note.folderName] ?? 0) + 1;
    }

    return folderStats;
  }

  Future<List<Note>> getLinkedNotes(int noteId) async {
    return _backlinkService.getLinkedNotes(noteId);
  }

  Future<List<Note>> getReferringNotes(int noteId) async {
    return _backlinkService.getReferringNotes(noteId);
  }

  Future<Map<String, dynamic>> getLinkStats(int noteId) async {
    return _backlinkService.getLinkStats(noteId);
  }

  Future<List<Note>> getOrphanedNotes() async {
    return _backlinkService.getOrphanedNotes();
  }

  Future<List<Note>> getHubNotes({int minimumLinks = 3}) async {
    return _backlinkService.getHubNotes(minimumLinks: minimumLinks);
  }

  Future<List<Note>> suggestRelatedNotes(int noteId, {int limit = 5}) async {
    return _backlinkService.suggestRelatedNotes(noteId, limit: limit);
  }

  Future<void> createMultipleNotes(List<Note> notes) async {
    for (final note in notes) {
      await createNote(
        title: note.title,
        content: note.content,
        tags: note.tags,
        folderName: note.folderName,
        color: note.color,
        isEncrypted: note.isEncrypted,
      );
    }
  }

  Future<void> deleteMultipleNotes(List<int> noteIds) async {
    for (final id in noteIds) {
      await deleteNote(id);
    }
  }

  Future<List<Map<String, dynamic>>> exportNotes() async {
    final notes = await _repository.getAllNotes();
    return notes.map((note) => note.toJson()).toList();
  }

  Future<void> importNotes(List<Map<String, dynamic>> notesData) async {
    for (final noteData in notesData) {
      await _repository.addNote(Note.fromJson(noteData));
    }
  }

  Future<List<Note>> searchNotes(String query) async {
    return _repository.searchNotes(query);
  }

  Future<Map<String, dynamic>> getDatabaseStats() async {
    final stats = await _repository.getDatabaseStats();
    final tagFrequency = await getTagFrequency();
    final folderStats = await getFolderStats();

    return {
      ...stats,
      'tagFrequency': tagFrequency,
      'folderStats': folderStats,
      'totalTags': tagFrequency.length,
      'totalFolders': folderStats.length,
    };
  }

  bool validateNote(Note note) {
    if (note.title.trim().isEmpty) return false;
    if (note.content.trim().isEmpty) return false;
    if (note.title.length > 200) return false;
    if (note.content.length > 1000000) return false;
    return true;
  }

  Future<List<String>> suggestTags(String content) async {
    final allNotes = await _repository.getAllNotes();
    final contentLower = content.toLowerCase();
    final suggestions = <String>{};
    final allTags = <String>{};

    for (final note in allNotes) {
      allTags.addAll(note.tags);
    }

    for (final tag in allTags) {
      if (contentLower.contains(tag.toLowerCase())) {
        suggestions.add(tag);
      }
    }

    return suggestions.toList();
  }

  /// Resolve the readable content for a note when the vault is unlocked.
  ///
  /// This helper is intended for note detail screens and other explicit read
  /// flows. List loading intentionally stays ciphertext-safe.
  Future<String> resolveReadableContent(Note note) async {
    if (!note.isEncrypted) {
      return note.content;
    }

    final adapter = _encryptionAdapter;
    if (adapter == null || !adapter.isUnlocked()) {
      throw StateError('Vault is locked. Encrypted note content cannot be resolved.');
    }

    return adapter.decrypt(note.content);
  }

  Future<String> _prepareContentForPersistence({
    required String content,
    required bool isEncrypted,
  }) async {
    if (!isEncrypted) {
      return content;
    }

    final adapter = _encryptionAdapter;
    if (adapter == null) {
      throw StateError('Encryption adapter is not configured.');
    }

    if (!adapter.isUnlocked()) {
      throw StateError('Vault must be unlocked before saving encrypted notes.');
    }

    return adapter.encrypt(content);
  }
}
