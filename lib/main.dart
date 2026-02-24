import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
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
import 'package:connected_notebook/shared/utils/sharing_service.dart';
import 'package:connected_notebook/features/home_widget/services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize databaseFactory for desktop platforms
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
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
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GümüşNot',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => SplashScreen(
                onInitialized: () => Navigator.of(context).pushReplacementNamed('/'),
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
                  pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
                    body: MarkdownEditor(
                      note: note,
                      onSave: (savedNote) {
                        Navigator.of(context).pop();
                        Provider.of<NoteProvider>(context, listen: false).loadNotes();
                      },
                      onCancel: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
