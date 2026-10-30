import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connected_notebook/core/storage/note_markdown_codec.dart';

class _FileStatSnapshot {
  const _FileStatSnapshot({
    required this.modified,
    required this.size,
  });

  final DateTime modified;
  final int size;
}

class _WorkspaceLifecycleObserver with WidgetsBindingObserver {
  _WorkspaceLifecycleObserver(this._onResumed);

  final Future<void> Function() _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResumed());
    }
  }
}

/// Manages the active workspace directory and provides reactive, debounced
/// file system watching (`Directory.watch`), internal-write loop suppression
/// (`markInternalWrite`), and mobile `AppLifecycleState.resumed` stat checks
/// for external additions, updates, and deletions of `.md` note files.
class WorkspaceService {
  static const String prefKeyWorkspacePath = 'workspace_custom_notes_dir';
  static const Duration defaultWatchDebounce = Duration(milliseconds: 400);
  static const Duration defaultInternalWriteSuppression =
      Duration(milliseconds: 1500);

  final Future<Directory> Function()? _defaultDocsDirResolver;
  final Duration _watchDebounce;
  final Duration _internalWriteSuppression;

  StreamSubscription<FileSystemEvent>? _watchSubscription;
  Timer? _debounceTimer;
  Future<void> Function()? _externalChangeCallback;
  _WorkspaceLifecycleObserver? _lifecycleObserver;

  DateTime? _suppressEventsUntil;
  Map<String, _FileStatSnapshot> _lastKnownSnapshot = {};
  String? _cachedWorkspacePath;

  WorkspaceService({
    Future<Directory> Function()? defaultDocsDirResolver,
    Duration watchDebounce = defaultWatchDebounce,
    Duration internalWriteSuppression = defaultInternalWriteSuppression,
  })  : _defaultDocsDirResolver = defaultDocsDirResolver,
        _watchDebounce = watchDebounce,
        _internalWriteSuppression = internalWriteSuppression;

  bool get isWatching => _watchSubscription != null;

  /// Marks an application-initiated disk write so file-watcher events caused by
  /// GümüşNot itself within the next [_internalWriteSuppression] (default 1500ms)
  /// are ignored (SRS Section 4.2).
  void markInternalWrite() {
    _suppressEventsUntil = DateTime.now().add(_internalWriteSuppression);
  }

  /// Whether file-system events are currently suppressed due to a recent internal write.
  bool get isSuppressingInternalWrites {
    final until = _suppressEventsUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Formats a conflict copy title according to SRS Section 4.2:
  /// `<Başlık> (Çakışma Kopyası - YYYY-MM-DD-HHmm)`.
  static String formatConflictTitle(String baseTitle, [DateTime? timestamp]) {
    final dt = timestamp ?? DateTime.now();
    final trimmed = baseTitle.trim().isEmpty ? 'Adsız Not' : baseTitle.trim();
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$trimmed (Çakışma Kopyası - $yyyy-$mm-$dd-$hh$min)';
  }

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

  Future<Map<String, _FileStatSnapshot>> _captureDirectorySnapshot(
    Directory dir,
  ) async {
    final snapshot = <String, _FileStatSnapshot>{};
    if (!await dir.exists()) return snapshot;

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (fileName.startsWith('.') ||
          entity.path.endsWith('.tmp') ||
          !NoteMarkdownCodec.isNoteFileName(fileName)) {
        continue;
      }
      try {
        final stat = await entity.stat();
        snapshot[p.normalize(entity.path).toLowerCase()] = _FileStatSnapshot(
          modified: stat.modified,
          size: stat.size,
        );
      } catch (_) {}
    }
    return snapshot;
  }

  bool _hasSnapshotDiff(
    Map<String, _FileStatSnapshot> previous,
    Map<String, _FileStatSnapshot> current,
  ) {
    if (previous.length != current.length) return true;
    for (final entry in current.entries) {
      final prev = previous[entry.key];
      if (prev == null) return true;
      if (!prev.modified.isAtSameMomentAs(entry.value.modified) ||
          prev.size != entry.value.size) {
        return true;
      }
    }
    return false;
  }

  /// Lightweight `FileStat.modified` scan triggered when the app returns to
  /// foreground (`AppLifecycleState.resumed`) on mobile platforms where OS
  /// background suspension may pause `Directory.watch()` (SRS Section 4.2).
  Future<bool> checkExternalChangesOnResume() async {
    if (kIsWeb || isSuppressingInternalWrites) return false;
    final callback = _externalChangeCallback;
    if (callback == null) return false;

    try {
      final dir = await getNotesDirectory();
      final currentSnapshot = await _captureDirectorySnapshot(dir);
      final changed = _hasSnapshotDiff(_lastKnownSnapshot, currentSnapshot);
      _lastKnownSnapshot = currentSnapshot;

      if (changed) {
        await callback();
        return true;
      }
    } catch (e) {
      debugPrint('Workspace resume stat scan error: $e');
    }
    return false;
  }

  /// Starts listening to file system events inside the workspace directory.
  /// Ignores non-markdown files, temp files (`.tmp`), `.git` internals, and
  /// self-triggered writes within the `markInternalWrite()` suppression window.
  Future<void> startWatching({
    required Future<void> Function() onExternalChange,
  }) async {
    _externalChangeCallback = onExternalChange;
    await stopWatching();

    if (kIsWeb) return;

    try {
      final dir = await getNotesDirectory();
      _lastKnownSnapshot = await _captureDirectorySnapshot(dir);

      final observer = _WorkspaceLifecycleObserver(() async {
        await checkExternalChangesOnResume();
      });
      try {
        WidgetsBinding.instance.addObserver(observer);
        _lifecycleObserver = observer;
      } catch (_) {
        // Safe fallback when running in a pure Dart CLI environment without WidgetsBinding.
      }

      _watchSubscription = dir.watch(recursive: false).listen(
        (event) {
          if (isSuppressingInternalWrites) {
            return;
          }

          final fileName = p.basename(event.path);
          if (event.path.endsWith('.tmp') ||
              fileName.startsWith('.') ||
              !NoteMarkdownCodec.isNoteFileName(fileName)) {
            return;
          }

          _debounceTimer?.cancel();
          _debounceTimer = Timer(_watchDebounce, () async {
            if (isSuppressingInternalWrites) return;
            try {
              _lastKnownSnapshot = await _captureDirectorySnapshot(dir);
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

  /// Stops watching directory events, detaches lifecycle observer, and cancels timers.
  Future<void> stopWatching() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_lifecycleObserver != null) {
      try {
        WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      } catch (_) {}
      _lifecycleObserver = null;
    }
    await _watchSubscription?.cancel();
    _watchSubscription = null;
  }

  void dispose() {
    stopWatching();
  }
}
