import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connected_notebook/features/notes/di/note_dependency_injection.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:connected_notebook/features/notes/presentation/note_list_screen.dart';
import 'package:connected_notebook/features/graph/presentation/graph_view_screen.dart';
import 'package:connected_notebook/features/settings/presentation/settings_screen.dart';
import 'package:connected_notebook/features/splash/presentation/splash_screen.dart';
import 'package:connected_notebook/features/tasks/presentation/task_hub_screen.dart';
import 'package:connected_notebook/features/notes/presentation/main_screen.dart';
import 'package:connected_notebook/features/notes/presentation/dashboard_screen.dart';
import 'package:connected_notebook/features/home_widget/presentation/widget_screen.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

  if (!kIsWeb) {
    // Initialize databaseFactory for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize theme provider BEFORE app starts to prevent white flash
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(ConnectedNotebookApp(themeProvider: themeProvider));
}

class ConnectedNotebookApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const ConnectedNotebookApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme provider
        ChangeNotifierProvider.value(value: themeProvider),

        // Note feature providers (using dependency injection)
        ...NoteDependencyInjection.getProviders(),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GümüşNot',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              ErrorWidget.builder = (FlutterErrorDetails details) {
                return Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Uygulama başlatılırken hata oluştu',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              details.exceptionAsString(),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              };

              return child ?? const SizedBox.shrink();
            },
            initialRoute: kIsWeb ? '/' : '/splash',
            routes: {
              '/splash': (context) => SplashScreen(
                onInitialized: () =>
                    Navigator.of(context).pushReplacementNamed('/'),
              ),
              '/': (context) => const MainScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/notes': (context) => const NoteListScreen(),
              '/graph': (context) => const GraphViewScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/task-hub': (context) => const TaskHubScreen(),
              '/widgets': (context) => const WidgetScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/note-editor') {
                final note = settings.arguments as Note?;
                return PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      Scaffold(
                        body: MarkdownEditor(
                          note: note,
                          onSave: (savedNote) {
                            Navigator.of(context).pop();
                            context.noteProvider.loadNotes();
                          },
                          onCancel: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
