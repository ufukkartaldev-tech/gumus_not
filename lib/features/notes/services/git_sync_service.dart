import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note_history.dart';

class GitSyncService {
  String? _repoPath;

  Future<String> getRepoPath() async {
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
    final path = await getRepoPath();
    final gitDir = Directory('$path/.git');
    if (!await gitDir.exists()) {
      await Process.run('git', ['init'], workingDirectory: path);
      // Optional: Set default branch to main
      await Process.run('git', ['branch', '-M', 'main'], workingDirectory: path);
    }
  }

  Future<bool> commitChanges(String message) async {
    try {
      final path = await getRepoPath();
      await Process.run('git', ['add', '.'], workingDirectory: path);
      
      final statusResult = await Process.run('git', ['status', '--porcelain'], workingDirectory: path);
      if (statusResult.stdout.toString().trim().isEmpty) {
        return false; // Nothing to commit
      }

      final result = await Process.run('git', ['commit', '-m', message], workingDirectory: path);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Git commit error: $e');
      return false;
    }
  }

  Future<List<NoteHistory>> getNoteHistory(String fileName) async {
    try {
      final path = await getRepoPath();
      // format: commitHash|author|date|message
      final result = await Process.run(
        'git',
        ['log', '--pretty=format:%H|%an|%cI|%s', '--', fileName],
        workingDirectory: path,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isEmpty) return [];

        return output.split('\n').map((line) => NoteHistory.fromGitLog(line)).toList();
      }
    } catch (e) {
      debugPrint('Git log error: $e');
    }
    return [];
  }

  Future<NoteDiff?> getNoteDiff(String fileName, String commitHash) async {
    try {
      final path = await getRepoPath();
      // Get the diff for this file in the specific commit
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
  }
}
