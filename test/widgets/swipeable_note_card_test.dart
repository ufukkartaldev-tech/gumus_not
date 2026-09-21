import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/widgets/swipeable_note_card.dart';

void main() {
  group('SwipeableNoteCard Widget Tests', () {
    late Note testNote;

    setUp(() {
      testNote = Note(
        id: 1,
        title: 'Swipeable Note',
        content: 'This note can be swiped.',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: ['swipe'],
      );
    });

    testWidgets('renders child widget inside SwipeableNoteCard', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeableNoteCard(
              note: testNote,
              onTogglePin: () {},
              onDelete: () {},
              onArchive: () {},
              child: const Text('Inner Note Content'),
            ),
          ),
        ),
      );

      expect(find.text('Inner Note Content'), findsOneWidget);
    });

    testWidgets('swiping right triggers onTogglePin callback', (WidgetTester tester) async {
      bool pinToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 100,
              child: SwipeableNoteCard(
                note: testNote,
                isPinned: false,
                onTogglePin: () => pinToggled = true,
                onDelete: () {},
                onArchive: () {},
                child: const Text('Drag Me Right'),
              ),
            ),
          ),
        ),
      );

      // Drag right (startToEnd)
      await tester.drag(find.text('Drag Me Right'), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(pinToggled, isTrue);
    });

    testWidgets('swiping left reveals delete / archive actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 100,
              child: SwipeableNoteCard(
                note: testNote,
                isPinned: false,
                onTogglePin: () {},
                onDelete: () {},
                onArchive: () {},
                child: const Text('Drag Me Left'),
              ),
            ),
          ),
        ),
      );

      // Drag left (endToStart)
      await tester.drag(find.text('Drag Me Left'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Bottom sheet with 'Notu Arşivle' and 'Notu Sil' should appear
      expect(find.text('Notu Arşivle'), findsOneWidget);
      expect(find.text('Notu Sil'), findsOneWidget);
    });
  });
}
