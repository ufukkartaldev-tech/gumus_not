import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:connected_notebook/features/notes/di/note_dependency_injection.dart';
import 'package:connected_notebook/features/tools/widgets/command_palette.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

void main() {
  group('CommandPalette Widget Tests', () {
    late ThemeProvider themeProvider;

    setUp(() {
      themeProvider = ThemeProvider();
      NoteDependencyInjection.enableTestMode();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ...NoteDependencyInjection.getTestProviders(),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CommandPalette.show(context),
                  child: const Text('Open Palette'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('opens CommandPalette dialog with Raycast header and commands', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open Command Palette
      await tester.tap(find.text('Open Palette'));
      await tester.pumpAndSettle();

      // Verify search field is displayed
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Bir komut yazın veya not arayın...'), findsOneWidget);

      // Verify quick commands are displayed
      expect(find.text('Yeni Not Oluştur'), findsOneWidget);
      expect(find.text('Yeni Görev Ekle'), findsOneWidget);
      expect(find.text('PDF Olarak Dışa Aktar'), findsOneWidget);

      // Verify Linear/Raycast footer shortcuts
      expect(find.text('ESC'), findsWidgets);
      expect(find.text('Gezin'), findsOneWidget);
      expect(find.text('Seç'), findsOneWidget);
    });

    testWidgets('filters commands when searching in CommandPalette', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open Command Palette
      await tester.tap(find.text('Open Palette'));
      await tester.pumpAndSettle();

      // Enter query
      await tester.enterText(find.byType(TextField), 'PDF');
      await tester.pumpAndSettle();

      // Verify matching command is shown and non-matching is hidden
      expect(find.text('PDF Olarak Dışa Aktar'), findsOneWidget);
      expect(find.text('Yeni Görev Ekle'), findsNothing);
    });

    testWidgets('displays note search results in CommandPalette', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Add a note into provider
      final BuildContext context = tester.element(find.byType(ElevatedButton));
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      await noteProvider.addNote(
        Note(
          title: 'Gizli Proje Planı',
          content: 'Detaylar ve hedefler',
          createdAt: 1640995200000,
          updatedAt: 1640995260000,
        ),
      );
      await tester.pumpAndSettle();

      // Open palette
      await tester.tap(find.text('Open Palette'));
      await tester.pumpAndSettle();

      // Search for note
      await tester.enterText(find.byType(TextField), 'Gizli Proje');
      await tester.pumpAndSettle();

      expect(find.text('Gizli Proje Planı'), findsOneWidget);
    });
  });
}
