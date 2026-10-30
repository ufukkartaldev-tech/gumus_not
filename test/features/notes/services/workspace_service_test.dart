import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connected_notebook/core/storage/note_markdown_codec.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/markdown_note_repository.dart';
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

    test('SRS 4.2: markInternalWrite suppresses watcher loop for internal writes', () async {
      final watchDir = Directory(p.join(tempDir.path, 'watch_internal'));
      await watchDir.create(recursive: true);

      final isolatedWs = WorkspaceService(
        defaultDocsDirResolver: () async => defaultDocsDir,
        watchDebounce: const Duration(milliseconds: 40),
        internalWriteSuppression: const Duration(milliseconds: 250),
      );
      addTearDown(isolatedWs.dispose);
      await isolatedWs.setWorkspacePath(watchDir.path);

      int externalEvents = 0;
      await isolatedWs.startWatching(
        onExternalChange: () async {
          externalEvents++;
        },
      );

      // Mark internal write right before writing a .md file
      isolatedWs.markInternalWrite();
      expect(isolatedWs.isSuppressingInternalWrites, isTrue);

      final internalFile = File(p.join(watchDir.path, 'Internal Save.md'));
      await internalFile.writeAsString('# İç Kayıt');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(externalEvents, equals(0));

      // Wait for suppression window to expire, then simulate external Obsidian edit
      await Future<void>.delayed(const Duration(milliseconds: 160));
      expect(isolatedWs.isSuppressingInternalWrites, isFalse);

      await internalFile.writeAsString('# Dış Düzenleme (Obsidian)');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(externalEvents, greaterThanOrEqualTo(1));
    });

    test('SRS 4.2: checkExternalChangesOnResume detects offline file edits via FileStat', () async {
      final resumeDir = Directory(p.join(tempDir.path, 'watch_resume'));
      await resumeDir.create(recursive: true);
      await workspaceService.setWorkspacePath(resumeDir.path);

      int resumeCallbacks = 0;
      await workspaceService.startWatching(
        onExternalChange: () async {
          resumeCallbacks++;
        },
      );
      // Simulate OS pausing Directory.watch in background while keeping callback
      final file = File(p.join(resumeDir.path, 'Mobil Not.md'));

      // Nothing changed yet -> returns false without firing callback
      expect(await workspaceService.checkExternalChangesOnResume(), isFalse);
      expect(resumeCallbacks, equals(0));

      // External sync drops a file while app was suspended
      await workspaceService.stopWatching();
      // Re-arm callback and baseline, then stop OS stream to isolate stat check
      await workspaceService.startWatching(
        onExternalChange: () async {
          resumeCallbacks++;
        },
      );
      workspaceService.markInternalWrite(); // suppress live OS watcher during setup
      await file.writeAsString('# Arka Planda Senkronize Edildi');
      await Future<void>.delayed(const Duration(milliseconds: 1600));

      final detected = await workspaceService.checkExternalChangesOnResume();
      expect(detected, isTrue);
      expect(resumeCallbacks, equals(1));

      // Immediate second resume scan without new changes returns false
      expect(await workspaceService.checkExternalChangesOnResume(), isFalse);
    });

    test('SRS 4.2: saveConflictCopy writes <Başlık> (Çakışma Kopyası - YYYY-MM-DD-HHmm).md and preserves alias links on rename', () async {
      final repoDir = Directory(p.join(tempDir.path, 'conflict_repo'));
      await repoDir.create(recursive: true);

      final repo = MarkdownNoteRepository(
        enableGit: false,
        notesDirResolver: () async => repoDir,
        onInternalWrite: workspaceService.markInternalWrite,
      );

      final baseId = await repo.addNote(
        Note(
          title: 'Proje Planı',
          content: 'Sürüm 1',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
      final referrerId = await repo.addNote(
        Note(
          title: 'Özet',
          content: 'Detaylar: [[Proje Planı|Ana Plan]] ve [[Proje Planı]].',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );

      // Save external conflict copy at fixed timestamp 2026-10-30 14:05
      final conflictTs = DateTime(2026, 10, 30, 14, 5);
      final conflictCopy = await repo.saveConflictCopy(
        Note(
          id: baseId,
          title: 'Proje Planı',
          content: 'Harici Syncthing İçeriği',
          createdAt: 1000,
          updatedAt: 2000,
        ),
        timestamp: conflictTs,
      );

      expect(
        conflictCopy.title,
        equals('Proje Planı (Çakışma Kopyası - 2026-10-30-1405)'),
      );
      final expectedConflictFile = File(
        p.join(
          repoDir.path,
          'Proje Planı (Çakışma Kopyası - 2026-10-30-1405).md',
        ),
      );
      expect(await expectedConflictFile.exists(), isTrue);
      final deserializedConflict =
          await NoteMarkdownCodec.deserializeFromFileAsync(expectedConflictFile);
      expect(deserializedConflict.content, equals('Harici Syncthing İçeriği'));

      // Original note remains untouched AND renaming it verifies new file & updates alias links
      await repo.updateNote(
        Note(
          id: baseId,
          title: 'Yol Haritası',
          content: 'Editördeki Kirli Tampon Kaydı',
          createdAt: 1000,
          updatedAt: 3000,
        ),
      );

      expect(await File(p.join(repoDir.path, 'Yol Haritası.md')).exists(), isTrue);
      expect(await File(p.join(repoDir.path, 'Proje Planı.md')).exists(), isFalse);

      final updatedReferrer = await repo.getNoteById(referrerId);
      expect(
        updatedReferrer?.content,
        equals('Detaylar: [[Yol Haritası|Ana Plan]] ve [[Yol Haritası]].'),
      );
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
