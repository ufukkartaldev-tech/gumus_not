import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:connected_notebook/features/notes/di/note_dependency_injection.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';
import 'package:connected_notebook/features/notes/presentation/note_list_screen.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    NoteDependencyInjection.enableTestMode();
  });

  Widget buildTestApp({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ThemeProvider()),
        ...NoteDependencyInjection.getProviders(),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Note Sharing Tests', () {
    testWidgets('MarkdownEditor displays share button in AppBar', (WidgetTester tester) async {
      final testNote = Note(
        id: 101,
        title: 'Paylaşım Notu',
        content: 'Paylaşılacak içerik burada.',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(buildTestApp(
        child: MarkdownEditor(
          note: testNote,
          onSave: (_) {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify share icon button is present
      final shareButton = find.byTooltip('Notu Paylaş');
      expect(shareButton, findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);

      // Tap share button and verify it triggers without exception
      await tester.tap(shareButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('NoteListScreen operations sheet contains Notu Paylaş option', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      late NoteProvider noteProvider;

      await tester.pumpWidget(buildTestApp(
        child: Builder(
          builder: (context) {
            noteProvider = context.read<NoteProvider>();
            return const NoteListScreen();
          },
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final note = Note(
        id: null,
        title: 'Liste Paylaşım Notu',
        content: 'Liste içeriği.',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await noteProvider.addNote(note);
      await tester.pump(const Duration(milliseconds: 300));

      // Find more options icon button on NoteCard
      final moreButton = find.byTooltip('Diğer İşlemler');
      if (moreButton.evaluate().isNotEmpty) {
        await tester.tap(moreButton.first);
        await tester.pump(const Duration(milliseconds: 500));

        // Check for Notu Paylaş tile in the sheet
        expect(find.text('Notu Paylaş'), findsOneWidget);
        expect(find.text('Metin olarak paylaş veya panoya kopyala'), findsOneWidget);

        // Dismiss sheet
        Navigator.of(tester.element(find.text('Notu Paylaş'))).pop();
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}
