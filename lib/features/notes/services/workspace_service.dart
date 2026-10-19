import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connected_notebook/core/storage/note_markdown_codec.dart';

/// Manages the active workspace directory and provides reactive, debounced
/// file system watching (`Directory.watch`) for external additions, updates,
/// and deletions of `.md` note files.
class WorkspaceService {
  static const String prefKeyWorkspacePath = 'workspace_custom_notes_dir';
  static const Duration defaultWatchDebounce = Duration(milliseconds: 400);

  final Future<Directory> Function()? _defaultDocsDirResolver;
  final Duration _watchDebounce;

  StreamSubscription<FileSystemEvent>? _watchSubscription;
  Timer? _debounceTimer;
  Future<void> Function()? _externalChangeCallback;

  String? _cachedWorkspacePath;

  WorkspaceService({
    Future<Directory> Function()? defaultDocsDirResolver,
    Duration watchDebounce = defaultWatchDebounce,
  })  : _defaultDocsDirResolver = defaultDocsDirResolver,
        _watchDebounce = watchDebounce;

  bool get isWatching => _watchSubscription != null;

  /// Returns the default notes directory under `<documents>/GumusNot/notes`.
  Future<String> getDefaultWorkspacePath() async {
    final Directory directory;
    if (_defaultDocsDirResolver != null) {
      directory = await _defaultDocsDirResolver();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return p.normalize('${directory.path}/GumusNot/notes');
  }

  /// Returns the configured workspace path, falling back to the default path.
  Future<String> getActiveWorkspacePath() async {
    if (_cachedWorkspacePath != null) return _cachedWorkspacePath!;

    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(prefKeyWorkspacePath);

    if (customPath != null && customPath.trim().isNotEmpty) {
      final customDir = Directory(customPath.trim());
      if (await customDir.exists()) {
        _cachedWorkspacePath = p.normalize(customDir.path);
        return _cachedWorkspacePath!;
      }
    }

    final defaultPath = await getDefaultWorkspacePath();
    _cachedWorkspacePath = defaultPath;
    return defaultPath;
  }

  /// Resolves the active [Directory], creating it on disk if it does not yet exist.
  Future<Directory> getNotesDirectory() async {
    final path = await getActiveWorkspacePath();
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Sets a custom workspace folder. Automatically restarts file system watcher if active.
  Future<void> setWorkspacePath(String path) async {
    final normalized = p.normalize(path.trim());
    final dir = Directory(normalized);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyWorkspacePath, normalized);
    _cachedWorkspacePath = normalized;

    if (_externalChangeCallback != null) {
      await startWatching(onExternalChange: _externalChangeCallback!);
      await _externalChangeCallback!();
    }
  }

  Future<void> setCustomWorkspacePath(String path) => setWorkspacePath(path);

  /// Resets workspace path to the default location.
  Future<void> resetToDefaultWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKeyWorkspacePath);
    _cachedWorkspacePath = null;

    if (_externalChangeCallback != null) {
      await startWatching(onExternalChange: _externalChangeCallback!);
      await _externalChangeCallback!();
    }
  }

  Future<void> resetToDefault() => resetToDefaultWorkspace();

  /// Starts listening to file system events inside the workspace directory.
  /// Ignores non-markdown files, temp files (`.tmp`), and `.git` internals.
  Future<void> startWatching({
    required Future<void> Function() onExternalChange,
  }) async {
    _externalChangeCallback = onExternalChange;
    await stopWatching();

    if (kIsWeb) return;

    try {
      final dir = await getNotesDirectory();
      _watchSubscription = dir.watch(recursive: false).listen(
        (event) {
          final fileName = p.basename(event.path);
          if (event.path.endsWith('.tmp') ||
              fileName.startsWith('.') ||
              !NoteMarkdownCodec.isNoteFileName(fileName)) {
            return;
          }

          _debounceTimer?.cancel();
          _debounceTimer = Timer(_watchDebounce, () async {
            try {
              await onExternalChange();
            } catch (e) {
              debugPrint('Workspace watcher notification error: $e');
            }
          });
        },
        onError: (err) {
          debugPrint('Workspace watcher stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Could not start workspace Directory.watch: $e');
    }
  }

  /// Stops watching directory events and cancels active timers.
  Future<void> stopWatching() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _watchSubscription?.cancel();
    _watchSubscription = null;
  }

  void dispose() {
    stopWatching();
  }
}
