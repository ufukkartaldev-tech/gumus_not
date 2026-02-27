import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Abstract interface for database operations
/// Following SOLID principles: Interface Segregation and Dependency Inversion
abstract class IDatabaseService {
  // Core database operations
  Future<Database> get database;
  Future<void> close();

  // Note operations
  Future<int> insertNote(Map<String, dynamic> note);
  Future<List<Map<String, dynamic>>> getAllNotes();
  Future<List<Map<String, dynamic>>?> getNoteById(int id);
  Future<int> updateNote(Map<String, dynamic> note);
  Future<int> deleteNote(int id);
  Future<List<Map<String, dynamic>>> searchNotes(String query);

  // Backlink operations
  Future<void> insertBacklink(Map<String, dynamic> backlink);
  Future<List<Map<String, dynamic>>> getBacklinksForNote(int noteId);
  Future<List<Map<String, dynamic>>> getOutgoingLinksForNote(int noteId);
  Future<void> updateBacklinks(int? noteId, String content, List<Map<String, dynamic>> allNotes);

  // Template operations
  Future<int> insertTemplate(Map<String, dynamic> template);
  Future<List<Map<String, dynamic>>> getAllTemplates();
  Future<int> updateTemplate(Map<String, dynamic> template);
  Future<int> deleteTemplate(int id);

  // Query operations
  Future<List<Map<String, dynamic>>> getRecentNotes({int limit = 5});
  Future<List<Map<String, dynamic>>> getPendingTasks({int limit = 10});
  Future<Map<String, dynamic>> getDatabaseStats();

  // Batch operations
  Future<void> insertNotes(List<Map<String, dynamic>> notes);
  Future<void> deleteNotes(List<int> noteIds);

  // Database management
  Future<void> backup(String path);
  Future<void> restore(String path);
  Future<void> vacuum();
  Future<void> optimize();
}
