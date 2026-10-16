import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/backup/services/markdown_backup_utils.dart';

void main() {
  late Directory sourceDir;
  late Directory restoreDir;

  setUp(() async {
    sourceDir = await Directory.systemTemp.createTemp('gumusnot_backup_src');
    restoreDir = await Directory.systemTemp.createTemp('gumusnot_backup_dst');
  });

  tearDown(() async {
    if (sourceDir.existsSync()) await sourceDir.delete(recursive: true);
    if (restoreDir.existsSync()) await restoreDir.delete(recursive: true);
  });

  Future<Archive> zipOfAsync(Directory dir) async {
    final bytes = await MarkdownBackupUtils.zipWorkspace(root: dir);
    return ZipDecoder().decodeBytes(bytes!);
  }

  group('MarkdownBackupUtils', () {
    test('zipWorkspace returns null when workspace does not exist', () async {
      final missing = Directory(
        '${sourceDir.parent.path}/does_not_exist_${DateTime.now().millisecondsSinceEpoch}',
      );
      expect(await MarkdownBackupUtils.zipWorkspace(root: missing), isNull);
    });

    test('zips notes and templates but excludes .git internals', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      Directory('${sourceDir.path}/templates').createSync(recursive: true);
      Directory('${sourceDir.path}/.git').createSync(recursive: true);
      File('${sourceDir.path}/notes/1.md').writeAsStringSync('---\ntitle: a\n---\nbody');
      File('${sourceDir.path}/templates/9.md').writeAsStringSync('---\nname: t\n---\nbody');
      File('${sourceDir.path}/.git/config').writeAsStringSync('should-not-leak');

      final archive = await zipOfAsync(sourceDir);
      final names = archive.map((f) => f.name).toSet();

      expect(names, contains('notes/1.md'));
      expect(names, contains('templates/9.md'));
      expect(names.any((n) => n.startsWith('.git')), isFalse);
    });

    test('non-destructive extract merges backup into existing files', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      File('${sourceDir.path}/notes/1.md').writeAsStringSync('from backup');

      Directory('${restoreDir.path}/notes').createSync(recursive: true);
      File('${restoreDir.path}/notes/2.md').writeAsStringSync('device only');

      final count = await MarkdownBackupUtils.extractWorkspace(
        await zipOfAsync(sourceDir),
        root: restoreDir,
      );

      expect(count, 1);
      expect(File('${restoreDir.path}/notes/1.md').readAsStringSync(), 'from backup');
      expect(File('${restoreDir.path}/notes/2.md').existsSync(), isTrue);
    });

    test('replaceExisting restore removes device files missing from backup', () async {
      Directory('${sourceDir.path}/notes').createSync(recursive: true);
      File('${sourceDir.path}/notes/1.md').writeAsStringSync('from backup');

      Directory('${restoreDir.path}/notes').createSync(recursive: true);
      Directory('${restoreDir.path}/templates').createSync(recursive: true);
      File('${restoreDir.path}/notes/2.md').writeAsStringSync('stale note');
      File('${restoreDir.path}/templates/7.md').writeAsStringSync('stale template');
      File('${restoreDir.path}/templates/.seeded').writeAsStringSync('seeded');
      File('${restoreDir.path}/.migrated_from_sqlite').writeAsStringSync('done');

      final count = await MarkdownBackupUtils.extractWorkspace(
        await zipOfAsync(sourceDir),
        root: restoreDir,
        replaceExisting: true,
      );

      expect(count, 1);
      expect(File('${restoreDir.path}/notes/1.md').readAsStringSync(), 'from backup');
      expect(File('${restoreDir.path}/notes/2.md').existsSync(), isFalse);
      expect(File('${restoreDir.path}/templates/7.md').existsSync(), isFalse);
      // Markers survive so seeding/migration never re-trigger after restore.
      expect(File('${restoreDir.path}/templates/.seeded').existsSync(), isTrue);
      expect(File('${restoreDir.path}/.migrated_from_sqlite').existsSync(), isTrue);
    });

    test('extract rejects path traversal entries', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('../../evil.md', 4, 'evil'.codeUnits))
        ..addFile(ArchiveFile('notes/ok.md', 2, 'ok'.codeUnits));

      final count = await MarkdownBackupUtils.extractWorkspace(
        archive,
        root: restoreDir,
      );

      expect(count, 1);
      expect(File('${restoreDir.path}/notes/ok.md').existsSync(), isTrue);
      expect(
        File('${restoreDir.parent.path}/evil.md').existsSync(),
        isFalse,
      );
    });
  });
}
