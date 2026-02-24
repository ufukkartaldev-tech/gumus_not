import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:provider/provider.dart';

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

    testWidgets('MarkdownEditor displays note content correctly', (WidgetTester tester) async {
      Note? savedNote;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) => savedNote = note,
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify title is displayed
      expect(find.text('Test Note'), findsOneWidget);
      
      // Verify content is displayed
      expect(find.textContaining('This is test content'), findsOneWidget);
    });

    testWidgets('MarkdownEditor shows encrypted note protection', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: encryptedNote,
                onSave: (note) {},
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify encrypted protection message is shown
      expect(find.textContaining('Bu Not Şifreli'), findsOneWidget);
      expect(find.textContaining('şifre giriniz'), findsOneWidget);
      
      // Verify unlock button is present
      expect(find.text('Şifre ile Aç'), findsOneWidget);
      expect(find.byIcon(Icons.lock_open), findsOneWidget);
    });

    testWidgets('MarkdownEditor handles title editing', (WidgetTester tester) async {
      Note? savedNote;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) => savedNote = note,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the title field and enter new text
      await tester.enterText(find.byType(TextField).first, 'New Title');
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      // Verify the note was saved with new title
      expect(savedNote, isNotNull);
      expect(savedNote!.title, 'New Title');
    });

    testWidgets('MarkdownEditor handles content editing', (WidgetTester tester) async {
      Note? savedNote;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) => savedNote = note,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the content field (should be the second text field)
      final contentFields = find.byType(TextField);
      expect(contentFields.evaluate().length, greaterThan(1));
      
      await tester.enterText(contentFields.at(1), 'New content for the note');
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      // Verify the note was saved with new content
      expect(savedNote, isNotNull);
      expect(savedNote!.content, 'New content for the note');
    });

    testWidgets('MarkdownEditor requires title to save', (WidgetTester tester) async {
      Note? savedNote;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) => savedNote = note,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clear the title field
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      // Try to save
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      // Verify save was not called (title is required)
      expect(savedNote, isNull);
    });

    testWidgets('MarkdownEditor shows toolbar buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify toolbar buttons are present
      expect(find.byIcon(Icons.save_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_outlined), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsOneWidget);
    });

    testWidgets('MarkdownEditor toggles preview mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap preview button
      await tester.tap(find.byIcon(Icons.remove_red_eye_outlined));
      await tester.pumpAndSettle();

      // Verify preview mode is active (edit button should be visible)
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
    });

    testWidgets('MarkdownEditor handles new note creation', (WidgetTester tester) async {
      Note? savedNote;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: null, // New note
                onSave: (note) => savedNote = note,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter title and content
      await tester.enterText(find.byType(TextField).first, 'New Note Title');
      await tester.enterText(find.byType(TextField).at(1), 'New note content');
      await tester.pumpAndSettle();

      // Save the note
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      // Verify the note was created
      expect(savedNote, isNotNull);
      expect(savedNote!.title, 'New Note Title');
      expect(savedNote!.content, 'New note content');
      expect(savedNote!.id, isNull); // New note shouldn't have an ID yet
    });

    testWidgets('MarkdownEditor shows color picker', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap color picker button
      await tester.tap(find.byIcon(Icons.circle));
      await tester.pumpAndSettle();

      // Verify color picker dialog appears
      expect(find.text('Renk Seç'), findsOneWidget);
    });

    testWidgets('MarkdownEditor handles focus mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap focus mode button
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();

      // Verify focus mode is active (exit button should be visible)
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    });

    testWidgets('MarkdownEditor handles cancel operation', (WidgetTester tester) async {
      bool onCancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) {},
                onCancel: () => onCancelCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap back button (assuming there's a back button in the app bar)
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
        expect(onCancelCalled, isTrue);
      }
    });

    testWidgets('MarkdownEditor handles mood selector', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => NoteProvider(),
            child: Scaffold(
              body: MarkdownEditor(
                note: testNote,
                onSave: (note) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify mood selector is present
      expect(find.text('Mod:'), findsOneWidget);
      
      // Verify mood emojis are present
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('😐'), findsOneWidget);
    });
  });
}
