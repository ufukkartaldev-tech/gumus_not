import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/note_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/note_list_screen.dart';
import 'screens/graph_view_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/task_hub_screen.dart';
import 'screens/main_screen.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/markdown_editor.dart';
import 'models/note_model.dart';

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
