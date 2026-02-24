import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/main.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize FFI for sqflite
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    final themeProvider = ThemeProvider();
    // Load theme (mocked prefs)
    await themeProvider.loadTheme();

    await tester.pumpWidget(ConnectedNotebookApp(themeProvider: themeProvider));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Bağlantılı Düşünce Not Defteri'), findsOneWidget);
  });
}
