import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/note_model.dart';
import 'note_repository.dart';
import '../services/git_sync_service.dart';

class MarkdownNoteRepository implements NoteRepository {
  final GitSyncService _gitSyncService;
  
  MarkdownNoteRepository(this._gitSyncService) {
    _gitSyncService.initRepo();
  }

  Future<File> _getFile(int id) async {
    final path = await _gitSyncService.getRepoPath();
    return File('$path/$id.md');
  }

  Note _parseNoteFromFile(File file) {
    final content = file.readAsStringSync();
    final filename = file.uri.pathSegments.last;
    final id = int.tryParse(filename.replaceAll('.md', '')) ?? 0;

    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        final yamlStr = content.substring(3, endIndex).trim();
        final bodyContent = content.substring(endIndex + 3).trim();
        
        try {
          final yaml = loadYaml(yamlStr);
          return Note(
            id: id,
            title: yaml['title'] ?? 'Untitled',
            content: bodyContent,
            createdAt: yaml['createdAt'] ?? 0,
            updatedAt: yaml['updatedAt'] ?? 0,
            isEncrypted: yaml['isEncrypted'] ?? false,
            tags: (yaml['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
            color: yaml['color'],
            folderName: yaml['folderName'] ?? 'Genel',
          );
        } catch (e) {
          // Fallback if YAML parsing fails
        }
      }
    }

    return Note(
      id: id,
      title: 'Untitled',
      content: content,
      createdAt: file.lastModifiedSync().millisecondsSinceEpoch,
      updatedAt: file.lastModifiedSync().millisecondsSinceEpoch,
    );
  }

  String _serializeNote(Note note) {
    final tagsYaml = note.tags.map((t) => '  - $t').join('\n');
    final tagsPart = note.tags.isNotEmpty ? '\ntags:\n$tagsYaml' : '';
    final colorPart = note.color != null ? '\ncolor: ${note.color}' : '';
    
    return '''---
title: ${note.title}
createdAt: ${note.createdAt}
updatedAt: ${note.updatedAt}
isEncrypted: ${note.isEncrypted}
folderName: ${note.folderName}$colorPart$tagsPart
---
${note.content}''';
  }

  @override
  Future<List<Note>> getAllNotes() async {
    final path = await _gitSyncService.getRepoPath();
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final notes = <Note>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.md')) {
        notes.add(_parseNoteFromFile(entity));
      }
    }
    
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<Note?> getNoteById(int id) async {
    final file = await _getFile(id);
    if (await file.exists()) {
      return _parseNoteFromFile(file);
    }
    return null;
  }

  @override
  Future<int> addNote(Note note) async {
    final newId = note.id ?? DateTime.now().millisecondsSinceEpoch;
    final noteToSave = note.copyWith(id: newId);
    final file = await _getFile(newId);
    
    await file.writeAsString(_serializeNote(noteToSave));
    await _gitSyncService.commitChanges('Add note: ${noteToSave.title}');
    return newId;
  }

  @override
  Future<void> updateNote(Note note) async {
    if (note.id == null) return;
    final noteToSave = note.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    final file = await _getFile(noteToSave.id!);
    
    await file.writeAsString(_serializeNote(noteToSave));
    await _gitSyncService.commitChanges('Update note: ${noteToSave.title}');
  }

  @override
  Future<void> deleteNote(int id) async {
    final file = await _getFile(id);
    if (await file.exists()) {
      await file.delete();
      await _gitSyncService.commitChanges('Delete note: $id');
    }
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final all = await getAllNotes();
    final q = query.toLowerCase();
    return all.where((n) => 
      n.title.toLowerCase().contains(q) || 
      n.content.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    final all = await getAllNotes();
    return all.take(limit).toList();
  }

  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    final all = await getAllNotes();
    return all.where((n) => n.content.contains('- [ ]')).take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final all = await getAllNotes();
    return {
      'totalNotes': all.length,
      'totalTasks': (await getPendingTasks(limit: 1000)).length,
    };
  }

  @override
  Future<List<Backlink>> getBacklinksForNote(int noteId) async {
    return []; // Requires scanning all notes for [[$noteId]] or title
  }

  @override
  Future<List<Backlink>> getOutgoingLinksForNote(int noteId) async {
    return []; 
  }

  @override
  Future<void> updateBacklinks(Note note, List<Note> allNotes) async {}

  @override
  Future<List<String>> getFolders() async {
    final all = await getAllNotes();
    final folders = all.map((n) => n.folderName).toSet().toList();
    if (!folders.contains('Genel')) folders.add('Genel');
    return folders..sort();
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    final all = await getAllNotes();
    return all.where((n) => n.folderName == folderName).length;
  }

  @override
  Future<List<Note>> getNotesByTag(String tag) async {
    final all = await getAllNotes();
    return all.where((n) => n.tags.contains(tag)).toList();
  }

  @override
  Future<Map<String, int>> getTagFrequency() async {
    final all = await getAllNotes();
    final freq = <String, int>{};
    for (var n in all) {
      for (var t in n.tags) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    return freq;
  }
}
