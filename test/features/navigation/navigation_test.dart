import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:connected_notebook/features/notes/di/note_dependency_injection.dart';
import 'package:connected_notebook/features/notes/presentation/main_screen.dart';
import 'package:connected_notebook/features/settings/presentation/settings_screen.dart';
import 'package:connected_notebook/features/home_widget/presentation/widget_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({required Widget child, Size screenSize = const Size(400, 800)}) {
    final themeProvider = ThemeProvider();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ...NoteDependencyInjection.getProviders(),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: child,
        ),
        routes: {
          '/widgets': (context) => const WidgetScreen(),
        },
      ),
    );
  }

  group('Navigation & Architecture Tests', () {
    testWidgets('Mobile view shows 3 tabs: Notlar, Görevler, Zihin (no Widget, no Merkez)',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(buildTestApp(
        child: const MainScreen(),
        screenSize: const Size(400, 800),
      ));
      await tester.pumpAndSettle();

      // Verify bottom bar tabs
      expect(find.text('Notlar'), findsWidgets);
      expect(find.text('Görevler'), findsOneWidget);
      expect(find.text('Zihin'), findsOneWidget);

      // Verify Widget tab is removed from bottom bar
      expect(find.text('Widget'), findsNothing);
      // Verify Merkez is removed from bottom bar
      expect(find.text('Merkez'), findsNothing);

      // Default opening screen is NoteListScreen
      expect(find.byIcon(Icons.insights_rounded), findsWidgets); // Aktivite & Analiz button in AppBar
    });

    testWidgets('Desktop view hides bottom bar and renders 3-pane sidebar workbench',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(buildTestApp(
        child: const MainScreen(),
        screenSize: const Size(1200, 900),
      ));
      await tester.pumpAndSettle();

      // On desktop, bottom navigation bar container shouldn't exist
      // Sidebar should have GümüşNot, Tüm Notlar, Favoriler & Sabitler, KLASÖRLER, ETİKETLER
      expect(find.text('Tüm Notlar'), findsWidgets);
      expect(find.text('Favoriler & Sabitler'), findsOneWidget);
      expect(find.text('KLASÖRLER'), findsOneWidget);
      expect(find.text('ETİKETLER'), findsOneWidget);
      expect(find.text('Aktivite & Analiz'), findsOneWidget);

      // Empty state or note creation button in desktop panels
      expect(find.text('Yeni Not'), findsWidgets);
    });

    testWidgets('Settings screen contains Ana Ekran Widgetı configuration tile',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      await tester.pumpWidget(buildTestApp(
        child: const SettingsScreen(),
        screenSize: const Size(600, 1200),
      ));
      await tester.pumpAndSettle();

      // Verify Widget settings tile exists
      final widgetFinder = find.text('Ana Ekran Widgetı');
      await tester.scrollUntilVisible(widgetFinder, 300);
      expect(widgetFinder, findsOneWidget);
      expect(find.text('Widget görünümü, hızlı not ve senkronizasyon'), findsOneWidget);
      expect(find.byIcon(Icons.widgets_outlined), findsOneWidget);
    });
  });
}
