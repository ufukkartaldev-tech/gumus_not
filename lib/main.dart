import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connected_notebook/features/notes/di/note_dependency_injection.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:connected_notebook/core/utils/shortcut_manager.dart';
import 'package:connected_notebook/features/tools/widgets/command_palette.dart';
import 'package:connected_notebook/features/notes/presentation/note_list_screen.dart';
import 'package:connected_notebook/features/graph/presentation/graph_view_screen.dart';
import 'package:connected_notebook/features/settings/presentation/settings_screen.dart';
import 'package:connected_notebook/features/splash/presentation/splash_screen.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/presentation/main_screen.dart';
import 'package:connected_notebook/features/home_widget/presentation/widget_screen.dart';
import 'package:connected_notebook/features/notes/widgets/markdown_editor.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

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

  if (!kIsWeb) {
    // Initialize databaseFactory for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize theme provider BEFORE app starts to prevent white flash
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  
  final shortcutManager = AppShortcutManager();

  runApp(ConnectedNotebookApp(themeProvider: themeProvider, shortcutManager: shortcutManager));
}

class ConnectedNotebookApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final AppShortcutManager shortcutManager;

  const ConnectedNotebookApp({super.key, required this.themeProvider, required this.shortcutManager});

  LogicalKeySet _parseShortcut(String shortcutStr) {
    final parts = shortcutStr.split('+');
    bool isMeta = false;
    bool isShift = false;
    bool isAlt = false;
    bool isCtrl = false;
    LogicalKeyboardKey? mainKey;

    for (final part in parts) {
      if (part == 'meta' || part == 'cmd') isMeta = true;
      else if (part == 'ctrl') isCtrl = true;
      else if (part == 'shift') isShift = true;
      else if (part == 'alt') isAlt = true;
      else {
        // Basic mapping for alphabet keys
        if (part.length == 1) {
          final code = part.toLowerCase().codeUnitAt(0);
          mainKey = LogicalKeyboardKey(code);
        }
      }
    }

    if (mainKey == null) return LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK); // fallback

    List<LogicalKeyboardKey> keys = [];
    if (isMeta || isCtrl) {
      // In flutter, meta and ctrl are platform specific. We can just use control on windows/linux and meta on mac
      keys.add(defaultTargetPlatform == TargetPlatform.macOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control);
    }
    if (isShift) keys.add(LogicalKeyboardKey.shift);
    if (isAlt) keys.add(LogicalKeyboardKey.alt);
    keys.add(mainKey);
    
    if (keys.length == 1) return LogicalKeySet(keys[0]);
    if (keys.length == 2) return LogicalKeySet(keys[0], keys[1]);
    if (keys.length == 3) return LogicalKeySet(keys[0], keys[1], keys[2]);
    if (keys.length == 4) return LogicalKeySet(keys[0], keys[1], keys[2], keys[3]);
    
    return LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: shortcutManager),
        ...NoteDependencyInjection.getProviders(),
      ],
      child: Consumer2<ThemeProvider, AppShortcutManager>(
        builder: (context, themeProvider, shortcutManager, child) {
          
          final Map<ShortcutActivator, Intent> shortcuts = {
            _parseShortcut(shortcutManager.customShortcuts['command_palette'] ?? 'ctrl+k'): const CommandPaletteIntent(),
            _parseShortcut(shortcutManager.customShortcuts['new_note'] ?? 'ctrl+n'): const NewNoteIntent(),
          };

          return Shortcuts(
            shortcuts: shortcuts,
            child: Actions(
              actions: {
                CommandPaletteIntent: CallbackAction<CommandPaletteIntent>(
                  onInvoke: (intent) {
                    final context = navigatorKey.currentContext;
                    if (context != null) {
                      CommandPalette.show(context);
                    }
                    return null;
                  },
                ),
                NewNoteIntent: CallbackAction<NewNoteIntent>(
                  onInvoke: (intent) {
                    final context = navigatorKey.currentContext;
                    if (context != null) {
                      Navigator.of(context).pushNamed('/note-editor');
                    }
                    return null;
                  },
                ),
              },
              child: MaterialApp(
                title: 'GümüşNot',
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                theme: themeProvider.lightTheme,
                darkTheme: themeProvider.darkTheme,
                themeMode: themeProvider.themeMode,
                initialRoute: kIsWeb ? '/' : '/splash',
                routes: {
                  '/splash': (context) => SplashScreen(
                    onInitialized: () =>
                        Navigator.of(context).pushReplacementNamed('/'),
                  ),
                  '/': (context) => const MainScreen(),
                  '/notes': (context) => const NoteListScreen(),
                  '/graph': (context) => const GraphViewScreen(),
                  '/settings': (context) => const SettingsScreen(),
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
                                // context.noteProvider.loadNotes(); - using provider context safely:
                                Provider.of<NoteProvider>(context, listen: false).loadNotes();
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
              ),
            ),
          );
        },
      ),
    );
  }
}

