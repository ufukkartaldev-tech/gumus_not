import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/mock_note_repository.dart';
import 'package:connected_notebook/features/notes/services/advanced_search_service.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

void main() {
  group('NoteProvider Tests', () {
    late MockNoteRepository mockRepository;
    late AdvancedSearchService searchService;
    late NoteProvider noteProvider;
    
    setUp(() {
      mockRepository = MockNoteRepository();
      searchService = AdvancedSearchService();
      noteProvider = NoteProvider(
        repository: mockRepository,
        searchService: searchService,
      );
    });
    
    tearDown(() {
      mockRepository.clear();
    });
    
    test('Initial state is empty', () {
      expect(noteProvider.notes, isEmpty);
      expect(noteProvider.searchResults, isEmpty);
      expect(noteProvider.isLoading, isFalse);
      expect(noteProvider.searchQuery, isEmpty);
    });
    
    test('Load notes from repository', () async {
      // Arrange
      final mockNotes = [
        Note(
          id: 1,
          title: 'Test Note 1',
          content: 'Content 1',
          createdAt: 1000,
          updatedAt: 1000,
        ),
        Note(
          id: 2,
          title: 'Test Note 2',
          content: 'Content 2',
          createdAt: 2000,
          updatedAt: 2000,
        ),
      ];
      mockRepository.addMockNotes(mockNotes);
      
      // Act
      await noteProvider.loadNotes();
      
      // Assert
      expect(noteProvider.notes, hasLength(2));
      expect(noteProvider.searchResults, hasLength(2));
      expect(noteProvider.isLoading, isFalse);
    });
    
    test('Add note updates state', () async {
      // Arrange
      final newNote = Note(
        title: 'New Note',
        content: 'New Content',
        createdAt: 1000,
        updatedAt: 1000,
      );
      
      // Act
      await noteProvider.addNote(newNote);
      
      // Assert
      expect(noteProvider.notes, hasLength(1));
      expect(noteProvider.notes.first.title, 'New Note');
      expect(noteProvider.searchResults, hasLength(1));
    });
    
    test('Update note modifies existing note', () async {
      // Arrange
      final initialNote = Note(
        id: 1,
        title: 'Initial',
        content: 'Content',
        createdAt: 1000,
        updatedAt: 1000,
      );
      mockRepository.addMockNotes([initialNote]);
      await noteProvider.loadNotes();
      
      // Act
      final updatedNote = initialNote.copyWith(title: 'Updated');
      await noteProvider.updateNote(updatedNote);
      
      // Assert
      expect(noteProvider.notes.first.title, 'Updated');
    });
    
    test('Delete note removes from state', () async {
      // Arrange
      final note = Note(
        id: 1,
        title: 'To Delete',
        content: 'Content',
        createdAt: 1000,
        updatedAt: 1000,
      );
      mockRepository.addMockNotes([note]);
      await noteProvider.loadNotes();
      
      // Act
      await noteProvider.deleteNote(1);
      
      // Assert
      expect(noteProvider.notes, isEmpty);
    });
    
    test('Search filters notes correctly', () async {
      // Arrange
      final notes = [
        Note(
          id: 1,
          title: 'Flutter Development',
          content: 'Dart and Flutter',
          createdAt: 1000,
          updatedAt: 1000,
          tags: ['flutter', 'dart'],
        ),
        Note(
          id: 2,
          title: 'React Native',
          content: 'JavaScript framework',
          createdAt: 2000,
          updatedAt: 2000,
          tags: ['react', 'javascript'],
        ),
      ];
      mockRepository.addMockNotes(notes);
      await noteProvider.loadNotes();
      
      // Act
      await noteProvider.searchNotes('flutter');
      
      // Assert
      expect(noteProvider.searchResults, hasLength(1));
      expect(noteProvider.searchResults.first.title, 'Flutter Development');
    });
    
    test('Filter by folder works correctly', () async {
      // Arrange
      final notes = [
        Note(
          id: 1,
          title: 'Note 1',
          content: 'Content',
          createdAt: 1000,
          updatedAt: 1000,
          folderName: 'Work',
        ),
        Note(
          id: 2,
          title: 'Note 2',
          content: 'Content',
          createdAt: 2000,
          updatedAt: 2000,
          folderName: 'Personal',
        ),
      ];
      mockRepository.addMockNotes(notes);
      await noteProvider.loadNotes();
      
      // Act
      await noteProvider.filterByFolder('Work');
      
      // Assert
      expect(noteProvider.searchResults, hasLength(1));
      expect(noteProvider.searchResults.first.folderName, 'Work');
      expect(noteProvider.selectedFolder, 'Work');
    });
    
    test('Filter by tag works correctly', () async {
      // Arrange
      final notes = [
        Note(
          id: 1,
          title: 'Note 1',
          content: 'Content',
          createdAt: 1000,
          updatedAt: 1000,
          tags: ['important', 'work'],
        ),
        Note(
          id: 2,
          title: 'Note 2',
          content: 'Content',
          createdAt: 2000,
          updatedAt: 2000,
          tags: ['personal'],
        ),
      ];
      mockRepository.addMockNotes(notes);
      await noteProvider.loadNotes();
      
      // Act
      await noteProvider.filterByTag('important');
      
      // Assert
      expect(noteProvider.searchResults, hasLength(1));
      expect(noteProvider.searchResults.first.tags, contains('important'));
      expect(noteProvider.selectedTag, 'important');
    });
    
    test('Clear filters resets state', () async {
      // Arrange
      final notes = [
        Note(
          id: 1,
          title: 'Note 1',
          content: 'Content',
          createdAt: 1000,
          updatedAt: 1000,
          folderName: 'Work',
          tags: ['important'],
        ),
      ];
      mockRepository.addMockNotes(notes);
      await noteProvider.loadNotes();
      await noteProvider.filterByFolder('Work');
      await noteProvider.searchNotes('test');
      
      // Act
      await noteProvider.clearFilters();
      
      // Assert
      expect(noteProvider.selectedFolder, isNull);
      expect(noteProvider.selectedTag, isNull);
      expect(noteProvider.searchQuery, isEmpty);
      expect(noteProvider.searchResults, hasLength(1));
    });
    
    test('Get note by ID returns correct note', () async {
      // Arrange
      final notes = [
        Note(
          id: 1,
          title: 'Note 1',
          content: 'Content 1',
          createdAt: 1000,
          updatedAt: 1000,
        ),
        Note(
          id: 2,
          title: 'Note 2',
          content: 'Content 2',
          createdAt: 2000,
          updatedAt: 2000,
        ),
      ];
      mockRepository.addMockNotes(notes);
      await noteProvider.loadNotes();
      
      // Act
      final note = noteProvider.getNoteById(2);
      
      // Assert
      expect(note, isNotNull);
      expect(note!.title, 'Note 2');
    });
    
    test('Tag frequency calculation is correct', () async {
      // Arrange
      final notes = [
        Note(
          id: 1,
          title: 'Note 1',
          content: 'Content',
          createdAt: 1000,
          updatedAt: 1000,
          tags: ['flutter', 'dart'],
        ),
        Note(
          id: 2,
          title: 'Note 2',
          content: 'Content',
          createdAt: 2000,
          updatedAt: 2000,
          tags: ['flutter', 'mobile'],
        ),
        Note(
          id: 3,
          title: 'Note 3',
          content: 'Content',
          createdAt: 3000,
          updatedAt: 3000,
          tags: ['dart'],
        ),
      ];
      mockRepository.addMockNotes(notes);
      await noteProvider.loadNotes();
      
      // Act
      final frequency = noteProvider.tagFrequency;
      
      // Assert
      expect(frequency['flutter'], 2);
      expect(frequency['dart'], 2);
      expect(frequency['mobile'], 1);
    });
    
    test('Folders list includes all unique folders', () async {
      // Arrange
      final notes = [
        Note(
          id: 1,
          title: 'Note 1',
          content: 'Content',
          createdAt: 1000,
          updatedAt: 1000,
          folderName: 'Work',
        ),
        Note(
          id: 2,
          title: 'Note 2',
          content: 'Content',
          createdAt: 2000,
          updatedAt: 2000,
          folderName: 'Personal',
        ),
        Note(
          id: 3,
          title: 'Note 3',
          content: 'Content',
          createdAt: 3000,
          updatedAt: 3000,
          folderName: 'Work',
        ),
      ];
      mockRepository.addMockNotes(notes);
      await noteProvider.loadNotes();
      
      // Act
      final folders = noteProvider.folders;
      
      // Assert
      expect(folders, contains('Genel'));
      expect(folders, contains('Work'));
      expect(folders, contains('Personal'));
      expect(folders, hasLength(3));
    });
  });
}