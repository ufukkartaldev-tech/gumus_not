import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/services/search_service_interface.dart';

@GenerateMocks([NoteRepository, SearchService])
import 'note_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late NoteProvider noteProvider;
  late MockNoteRepository mockRepository;
  late MockSearchService mockSearchService;

  setUp(() {
    mockRepository = MockNoteRepository();
    mockSearchService = MockSearchService();
    noteProvider = NoteProvider(
      repository: mockRepository,
      searchService: mockSearchService,
    );
  });

  group('NoteProvider Production Logic Tests', () {
    test('Should load notes from repository correctly', () async {
      // Arrange
      final List<Note> dummyNotes = [
        Note(id: 1, title: 'Note 1', content: 'C1', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Note 2', content: 'C2', createdAt: 1, updatedAt: 1),
      ];
      when(mockRepository.getAllNotes()).thenAnswer((_) async => dummyNotes);

      // Act
      await noteProvider.loadNotes();

      // Assert
      expect(noteProvider.notes.length, 2);
      expect(noteProvider.notes[0].title, 'Note 1');
      verify(mockRepository.getAllNotes()).called(1);
    });

    test('Should add a note and update state', () async {
      // Arrange
      final newNote = Note(title: 'New Note', content: 'New Content', createdAt: 1, updatedAt: 1);
      when(mockRepository.addNote(any)).thenAnswer((_) async => 3);

      // Act
      await noteProvider.addNote(newNote);

      // Assert
      expect(noteProvider.notes.length, 1);
      expect(noteProvider.notes.first.id, 3);
      verify(mockRepository.addNote(any)).called(1);
    });

    test('Should delete note and remove from state', () async {
      // Arrange
      final List<Note> initialNotes = [
        Note(id: 1, title: 'Note 1', content: 'C1', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Note 2', content: 'C2', createdAt: 1, updatedAt: 1),
      ];
      when(mockRepository.getAllNotes()).thenAnswer((_) async => initialNotes);
      await noteProvider.loadNotes();
      
      when(mockRepository.deleteNote(1)).thenAnswer((_) async => 1);

      // Act
      await noteProvider.deleteNote(1);

      // Assert
      expect(noteProvider.notes.length, 1);
      expect(noteProvider.notes.any((n) => n.id == 1), isFalse);
      verify(mockRepository.deleteNote(1)).called(1);
    });

    test('Should filter notes correctly by folder', () async {
      // Arrange
      final List<Note> initialNotes = [
        Note(id: 1, title: 'Note 1', content: 'C1', folderName: 'Work', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Note 2', content: 'C2', folderName: 'Genel', createdAt: 1, updatedAt: 1),
      ];
      when(mockRepository.getAllNotes()).thenAnswer((_) async => initialNotes);
      await noteProvider.loadNotes();

      // Act
      await noteProvider.filterByFolder('Work');

      // Assert
      expect(noteProvider.searchResults.length, 1);
      expect(noteProvider.searchResults.first.folderName, 'Work');
    });

    test('Should filter notes correctly by search query', () async {
      // Arrange
      final List<Note> initialNotes = [
        Note(id: 1, title: 'Meeting Notes', content: 'Discuss project X', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Shopping List', content: 'Milk, Eggs', createdAt: 1, updatedAt: 1),
      ];
      when(mockRepository.getAllNotes()).thenAnswer((_) async => initialNotes);
      await noteProvider.loadNotes();

      when(mockSearchService.searchNotes(any, any))
          .thenAnswer((_) async => [initialNotes[0]]);

      // Act
      await noteProvider.searchNotes('Meeting');

      // Assert
      expect(noteProvider.searchResults.length, 1);
      expect(noteProvider.searchResults.first.title, 'Meeting Notes');
    });
  });
}

