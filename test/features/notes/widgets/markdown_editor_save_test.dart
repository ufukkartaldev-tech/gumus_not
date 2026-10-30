import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connected_notebook/core/utils/shortcut_manager.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_editor_provider.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';

import '../providers/note_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNoteRepository mockRepository;
  late MockSearchService mockSearchService;
  late NoteProvider noteProvider;
  late NoteEditorProvider noteEditorProvider;
  late AppShortcutManager shortcutManager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepository = MockNoteRepository();
    mockSearchService = MockSearchService();
    noteProvider = NoteProvider(
      repository: mockRepository,
      searchService: mockSearchService,
    );
    noteEditorProvider = NoteEditorProvider();
    shortcutManager = AppShortcutManager();

    when(mockRepository.getAllNotes()).thenAnswer((_) async => []);
  });

  Widget createTestWidget({
    Key? editorKey,
    Note? note,
    Function(Note)? onSave,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NoteProvider>.value(value: noteProvider),
        ChangeNotifierProvider<NoteEditorProvider>.value(value: noteEditorProvider),
        ChangeNotifierProvider<AppShortcutManager>.value(value: shortcutManager),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            key: editorKey,
            note: note,
            onSave: onSave ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('MarkdownEditor Data Loss Prevention Tests', () {
    testWidgets('flushPendingSave() persists dirty untitled note by auto-deriving title from content', (tester) async {
      final editorKey = GlobalKey<MarkdownEditorState>();

      when(mockRepository.addNote(any)).thenAnswer((_) async => 99);
      when(mockRepository.getNoteById(99)).thenAnswer(
        (_) async => Note(
          id: 99,
          title: 'İlk Cümle Başlık Olur',
          content: '# İlk Cümle Başlık Olur\nİkinci satır içerik.',
          createdAt: 1,
          updatedAt: 2,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          editorKey: editorKey,
          note: null,
          onSave: (note) {},
        ),
      );
      await tester.pumpAndSettle();

      final state = editorKey.currentState;
      expect(state, isNotNull);
      expect(state!.isDirty, isFalse);

      // Enter content without typing a title
      final contentField = find.byType(TextField).last;
      await tester.enterText(contentField, '# İlk Cümle Başlık Olur\nİkinci satır içerik.');
      await tester.pump();

      expect(state.isDirty, isTrue);

      // Flush pending save directly (simulating desktop note switch or window exit)
      final flushedNote = await state.flushPendingSave();

      expect(flushedNote, isNotNull);
      expect(flushedNote!.title, 'İlk Cümle Başlık Olur');
      expect(state.isDirty, isFalse);
      verify(mockRepository.addNote(any)).called(1);
    });

    testWidgets('Emergency draft is written to SharedPreferences when user enters content', (tester) async {
      final editorKey = GlobalKey<MarkdownEditorState>();

      await tester.pumpWidget(
        createTestWidget(
          editorKey: editorKey,
          note: Note(
            id: 42,
            title: 'Taslak Testi',
            content: 'orijinal',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final contentField = find.byType(TextField).last;
      await tester.enterText(contentField, 'orijinal ve eklenen yeni metin');
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString('crash_draft_42');
      expect(draft, isNotNull);
      expect(draft, contains('eklenen yeni metin'));
    });
  });
}
