import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:provider/provider.dart';

// Gerçek NoteProvider veritabanı erişimi yapar; bunu atlayan sahte versiyon.
class FakeNoteProvider extends NoteProvider {
  @override
  List<Note> get notes => [];

  @override
  Future<void> loadNotes() async {}
  
  @override
  Future<void> addNote(Note note) async {}
  
  @override
  Future<void> updateNote(Note note) async {}
  
  @override
  Future<void> deleteNote(int noteId) async {}

  @override
  Map<String, int> getTagFrequency() => {};
}

Future<void> setupTestWidget(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: ChangeNotifierProvider<NoteProvider>(
        create: (_) => FakeNoteProvider(),
        child: child,
      ),
    ),
  );
  
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('MarkdownEditor Widget Tests', () {
    late Note testNote;
    late Note encryptedNote;

    setUp(() {
      testNote = Note(
        id: 1,
        title: 'Test Note',
        content: 'This is test content for the markdown editor',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: ['test', 'editor'],
      );

      encryptedNote = Note(
        id: 2,
        title: 'Encrypted Note',
        content: 'This is encrypted content',
        createdAt: 1640995270000,
        updatedAt: 1640995280000,
        isEncrypted: true,
        tags: ['secret'],
      );
    });

    testWidgets('MarkdownEditor displays note content correctly',
        (WidgetTester tester) async {
      await setupTestWidget(tester, 
        MarkdownEditor(note: testNote, onSave: (note) {})
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Test Note'), findsOneWidget);
    });

    testWidgets('MarkdownEditor shows encrypted note protection',
        (WidgetTester tester) async {
      await setupTestWidget(tester, 
        MarkdownEditor(note: encryptedNote, onSave: (note) {})
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Bu Not Şifreli'), findsOneWidget);
    });

    testWidgets('MarkdownEditor handles title editing',
        (WidgetTester tester) async {
      Note? savedNote;
      await setupTestWidget(tester, 
        MarkdownEditor(note: testNote, onSave: (note) => savedNote = note)
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'New Title');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Kaydet'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(savedNote?.title, 'New Title');
    });

    testWidgets('MarkdownEditor toggles preview mode',
        (WidgetTester tester) async {
      await setupTestWidget(tester, 
        MarkdownEditor(note: testNote, onSave: (note) {})
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.remove_red_eye_outlined));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.edit_note), findsOneWidget);
    });

    testWidgets('MarkdownEditor handles cancel operation',
        (WidgetTester tester) async {
      bool onCancelCalled = false;
      await setupTestWidget(tester, 
        MarkdownEditor(
          note: testNote,
          onSave: (note) {},
          onCancel: () => onCancelCalled = true,
        )
      );
      await tester.pump(const Duration(milliseconds: 500));

      final backButton = find.byIcon(Icons.arrow_back_rounded);
      await tester.tap(backButton);
      await tester.pump(const Duration(milliseconds: 500));
      
      expect(onCancelCalled, isTrue);
    });
    
    testWidgets('MarkdownEditor toggles focus mode', (WidgetTester tester) async {
      await setupTestWidget(tester, MarkdownEditor(note: testNote, onSave: (note) {}));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    });
  });
}
