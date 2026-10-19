import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connected_notebook/features/notes/services/workspace_service.dart';
import 'package:connected_notebook/features/notes/services/git_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory defaultDocsDir;
  late WorkspaceService workspaceService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('gumus_ws_test');
    defaultDocsDir = Directory(p.join(tempDir.path, 'docs'));
    await defaultDocsDir.create(recursive: true);

    workspaceService = WorkspaceService(
      defaultDocsDirResolver: () async => defaultDocsDir,
      watchDebounce: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    workspaceService.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WorkspaceService directory resolution', () {
    test('resolves default path when no custom directory is configured', () async {
      final defaultPath = await workspaceService.getDefaultWorkspacePath();
      expect(defaultPath, equals(p.normalize(p.join(defaultDocsDir.path, 'GumusNot', 'notes'))));

      final activePath = await workspaceService.getActiveWorkspacePath();
      expect(activePath, equals(defaultPath));
    });

    test('sets and gets custom workspace path, automatically creating directory', () async {
      final customFolder = p.join(tempDir.path, 'custom_vault');
      await workspaceService.setCustomWorkspacePath(customFolder);

      final activePath = await workspaceService.getActiveWorkspacePath();
      expect(activePath, equals(p.normalize(customFolder)));
      expect(Directory(customFolder).existsSync(), isTrue);

      final notesDir = await workspaceService.getNotesDirectory();
      expect(notesDir.path, equals(p.normalize(customFolder)));
      expect(notesDir.existsSync(), isTrue);
    });

    test('resetToDefault restores default workspace directory', () async {
      final customFolder = p.join(tempDir.path, 'custom_vault_2');
      await workspaceService.setWorkspacePath(customFolder);
      expect(await workspaceService.getActiveWorkspacePath(), equals(p.normalize(customFolder)));

      await workspaceService.resetToDefault();
      final activePath = await workspaceService.getActiveWorkspacePath();
      final defaultPath = await workspaceService.getDefaultWorkspacePath();
      expect(activePath, equals(defaultPath));
    });
  });

  group('WorkspaceService reactive file watcher', () {
    test('triggers debounced callback upon markdown file addition', () async {
      final watchDir = Directory(p.join(tempDir.path, 'watch_notes'));
      await watchDir.create(recursive: true);
      await workspaceService.setWorkspacePath(watchDir.path);

      int changeCount = 0;
      await workspaceService.startWatching(
        onExternalChange: () async {
          changeCount++;
        },
      );

      expect(workspaceService.isWatching, isTrue);

      // Create a markdown file
      final noteFile = File(p.join(watchDir.path, 'My Test Note.md'));
      await noteFile.writeAsString('# Hello World\nContent');

      // Wait for debounce (50ms debounce + safety margin)
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(changeCount, greaterThanOrEqualTo(1));
    });

    test('ignores non-markdown or temporary files', () async {
      final watchDir = Directory(p.join(tempDir.path, 'watch_ignore'));
      await watchDir.create(recursive: true);
      await workspaceService.setWorkspacePath(watchDir.path);

      int changeCount = 0;
      await workspaceService.startWatching(
        onExternalChange: () async {
          changeCount++;
        },
      );

      // Write a .tmp file and a .txt file
      final tmpFile = File(p.join(watchDir.path, 'draft.tmp'));
      await tmpFile.writeAsString('temp data');

      final txtFile = File(p.join(watchDir.path, 'notes.txt'));
      await txtFile.writeAsString('text data');

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(changeCount, equals(0));
    });
  });

  group('GitSyncService debounced commit queue', () {
    test('batches multiple rapid queueCommit calls into single debounce window', () async {
      final testGitDir = Directory(p.join(tempDir.path, 'git_repo'));
      await testGitDir.create(recursive: true);

      final gitSync = GitSyncService(
        repoPathResolver: () async => testGitDir.path,
        commitDebounceDuration: const Duration(milliseconds: 80),
      );

      // Even without git initialized, queueCommit should record pending commits
      // without throwing exceptions or blocking the thread
      gitSync.queueCommit('Auto-save note 1');
      gitSync.queueCommit('Auto-save note 2');
      gitSync.queueCommit('Auto-save note 3');

      // Flush queue
      await gitSync.flushPendingCommits();

      gitSync.dispose();
    });
  });
}
