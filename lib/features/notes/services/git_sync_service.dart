import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note_history.dart';

class GitSyncService {
  String? _repoPath;
  final Future<String> Function()? _repoPathResolver;
  final Duration commitDebounceDuration;

  Timer? _debounceTimer;
  String? _pendingCommitMessage;
  bool _isRepoInitialized = false;

  /// Serializes all git subprocess invocations so rapid or concurrent note
  /// saves (`insertNotes`, fast auto-saves) never race on `.git/index.lock`.
  Future<void> _operationLock = Future<void>.value();

  GitSyncService({
    Future<String> Function()? repoPathResolver,
    this.commitDebounceDuration = const Duration(seconds: 4),
  }) : _repoPathResolver = repoPathResolver;

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _operationLock;
    final nextLock = Completer<void>();
    _operationLock = nextLock.future;

    previous.whenComplete(() async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        nextLock.complete();
      }
    });

    return completer.future;
  }

  Future<String> getRepoPath() async {
    if (_repoPathResolver != null) {
      final custom = await _repoPathResolver!();
      final dir = Directory(custom);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return custom;
    }

    if (_repoPath != null) return _repoPath!;
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/GumusNot/notes';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _repoPath = path;
    return path;
  }

  Future<void> initRepo() async {
    return _synchronized(() async {
      final path = await getRepoPath();
      final gitDir = Directory('$path/.git');
      if (!await gitDir.exists()) {
        await Process.run('git', ['init'], workingDirectory: path);
        await Process.run('git', ['branch', '-M', 'main'], workingDirectory: path);
      }
      _isRepoInitialized = true;
    });
  }

  /// Queues a debounced asynchronous commit to avoid spawning OS processes
  /// on every rapid keystroke or 1.5s auto-save timer trigger.
  void queueCommit(String message) {
    _pendingCommitMessage = message;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(commitDebounceDuration, () async {
      await flushPendingCommits();
    });
  }

  /// Flushes any pending queued commit immediately.
  Future<bool> flushPendingCommits() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final message = _pendingCommitMessage;
    if (message == null) return false;
    _pendingCommitMessage = null;
    return await commitChanges(message);
  }

  Future<bool> commitChanges(String message) async {
    return _synchronized(() async {
      try {
        final path = await getRepoPath();
        final gitDir = Directory('$path/.git');
        if (!_isRepoInitialized && !await gitDir.exists()) {
          await Process.run('git', ['init'], workingDirectory: path);
          await Process.run('git', ['branch', '-M', 'main'], workingDirectory: path);
          _isRepoInitialized = true;
        }

        await Process.run('git', ['add', '-A'], workingDirectory: path);

        final statusResult = await Process.run(
          'git',
          ['status', '--porcelain'],
          workingDirectory: path,
        );
        if (statusResult.stdout.toString().trim().isEmpty) {
          return false; // Nothing to commit
        }

        final result = await Process.run(
          'git',
          ['commit', '-m', message],
          workingDirectory: path,
        );
        return result.exitCode == 0;
      } catch (e) {
        debugPrint('Git commit error: $e');
        return false;
      }
    });
  }

  Future<List<NoteHistory>> getNoteHistory(String fileName) async {
    return _synchronized(() async {
      try {
        final path = await getRepoPath();
        // Use --follow so history is preserved across note title (file) renames
        final result = await Process.run(
          'git',
          ['log', '--follow', '--pretty=format:%H|%an|%cI|%s', '--', fileName],
          workingDirectory: path,
        );

        if (result.exitCode == 0) {
          final output = result.stdout.toString().trim();
          if (output.isEmpty) return [];

          return output
              .split('\n')
              .map((line) => NoteHistory.fromGitLog(line))
              .toList();
        }
      } catch (e) {
        debugPrint('Git log error: $e');
      }
      return [];
    });
  }

  Future<NoteDiff?> getNoteDiff(String fileName, String commitHash) async {
    return _synchronized(() async {
      try {
        final path = await getRepoPath();
        final result = await Process.run(
          'git',
          ['show', commitHash, '--', fileName],
          workingDirectory: path,
        );

        if (result.exitCode == 0) {
          return NoteDiff(
            commitHash: commitHash,
            diffContent: result.stdout.toString(),
          );
        }
      } catch (e) {
        debugPrint('Git diff error: $e');
      }
      return null;
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}
