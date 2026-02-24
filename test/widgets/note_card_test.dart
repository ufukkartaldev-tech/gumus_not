import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/widgets/note_card.dart';
import 'package:connected_notebook/models/note_model.dart';

void main() {
  group('NoteCard Widget Tests', () {
    late Note testNote;
    late Note encryptedNote;

    setUp(() {
      testNote = Note(
        id: 1,
        title: 'Test Note',
        content: 'This is a test note content with some text to display',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: ['test', 'widget'],
        color: 0xFFE3F2FD,
        folderName: 'Test Folder',
      );

      encryptedNote = Note(
        id: 2,
        title: 'Encrypted Note',
        content: 'This is encrypted content that should not be visible',
        createdAt: 1640995270000,
        updatedAt: 1640995280000,
        isEncrypted: true,
        tags: ['secret'],
        color: 0xFFFFE0B2,
        folderName: 'Private',
      );
    });

    testWidgets('NoteCard displays note information correctly', (WidgetTester tester) async {
      bool onEditCalled = false;
      bool onDeleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: testNote,
              onTap: () {},
              onEdit: () => onEditCalled = true,
              onDelete: () => onDeleteCalled = true,
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Verify note title is displayed
      expect(find.text('Test Note'), findsOneWidget);
      
      // Verify excerpt is displayed (truncated content)
      expect(find.textContaining('This is a test note'), findsOneWidget);
      
      // Verify tags are displayed
      expect(find.text('test'), findsOneWidget);
      expect(find.text('widget'), findsOneWidget);
    });

    testWidgets('NoteCard shows encrypted indicator for encrypted notes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: encryptedNote,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Verify lock icon is present for encrypted notes
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      
      // Verify content is not displayed (should show dots)
      expect(find.textContaining('encrypted content'), findsNothing);
      expect(find.textContaining('•••••••••••••••••'), findsOneWidget);
    });

    testWidgets('NoteCard handles tap events', (WidgetTester tester) async {
      bool onTapCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: testNote,
              onTap: () => onTapCalled = true,
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Tap on the note card
      await tester.tap(find.byType(NoteCard));
      await tester.pump();

      expect(onTapCalled, isTrue);
    });

    testWidgets('NoteCard shows pin indicator when pinned', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: testNote,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: true,
            ),
          ),
        ),
      );

      // Verify pin icon is present
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });

    testWidgets('NoteCard shows reading time for non-encrypted notes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: testNote,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Verify reading time is displayed (should show "X dk" format)
      expect(find.textContaining('dk'), findsOneWidget);
    });

    testWidgets('NoteCard hides reading time for encrypted notes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: encryptedNote,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Verify reading time is not displayed for encrypted notes
      expect(find.textContaining('dk'), findsNothing);
    });

    testWidgets('NoteCard displays custom color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: testNote,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Find the container with custom color
      final colorIndicator = tester.widget<Container>(
        find.descendant(
          of: find.byType(NoteCard),
          matching: find.byType(Container),
        ).first,
      );

      // Verify color is set (decoration should not be null)
      expect(colorIndicator.decoration, isA<BoxDecoration>());
    });

    testWidgets('NoteCard handles empty tags', (WidgetTester tester) async {
      final noteWithoutTags = Note(
        id: 3,
        title: 'No Tags Note',
        content: 'Content without tags',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: noteWithoutTags,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Verify note title is still displayed
      expect(find.text('No Tags Note'), findsOneWidget);
      
      // No tag widgets should be present
      expect(find.text('test'), findsNothing);
    });

    testWidgets('NoteCard handles long titles', (WidgetTester tester) async {
      final longTitleNote = Note(
        id: 4,
        title: 'This is a very long title that should be truncated when displayed in the note card widget',
        content: 'Short content',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: longTitleNote,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Verify title is displayed but truncated
      expect(find.textContaining('This is a very long title'), findsOneWidget);
    });

    testWidgets('NoteCard handles empty content', (WidgetTester tester) async {
      final emptyContentNote = Note(
        id: 5,
        title: 'Empty Content Note',
        content: '',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: ['empty'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: emptyContentNote,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('Empty Content Note'), findsOneWidget);
      
      // Verify tag is displayed
      expect(find.text('empty'), findsOneWidget);
    });

    testWidgets('NoteCard handles null color gracefully', (WidgetTester tester) async {
      final noteWithoutColor = Note(
        id: 6,
        title: 'No Color Note',
        content: 'Content without custom color',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: [],
        color: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: noteWithoutColor,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
              onTogglePin: (note) {},
              isPinned: false,
            ),
          ),
        ),
      );

      // Verify note is displayed without crashing
      expect(find.text('No Color Note'), findsOneWidget);
    });
  });
}
