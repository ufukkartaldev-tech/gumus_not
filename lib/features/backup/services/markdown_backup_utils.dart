import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Zips and restores the `<documents>/GumusNot` markdown workspace
/// (notes/ + templates/). Git internals are excluded so restores never
/// resurrect history that belongs to another device.
class MarkdownBackupUtils {
  MarkdownBackupUtils._();

  static Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'GumusNot'));
  }

  /// Returns zip bytes of the whole workspace, or null when the workspace
  /// does not exist yet. The optional [root] override exists for tests.
  static Future<List<int>?> zipWorkspace({Directory? root}) async {
    final dir = root ?? await _root();
    if (!dir.existsSync()) return null;

    final archive = Archive();
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative =
          p.relative(entity.path, from: dir.path).replaceAll('\\', '/');
      if (relative.startsWith('.git')) continue;
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }

    return ZipEncoder().encode(archive);
  }

  /// Extracts a workspace zip into `<documents>/GumusNot`.
  ///
  /// When [replaceExisting] is true the restore is destructive: note and
  /// template markdown files currently on the device are removed first so
  /// the workspace ends up matching the backup exactly. Dotfiles (git
  /// internals, seed and migration markers) are always preserved so
  /// first-run seeding and one-time migrations never re-trigger.
  ///
  /// Returns the number of restored files.
  static Future<int> extractWorkspace(
    Archive archive, {
    Directory? root,
    bool replaceExisting = false,
  }) async {
    final dir = root ?? await _root();
    if (!dir.existsSync()) dir.createSync(recursive: true);

    if (replaceExisting) {
      await _clearMarkdownFiles(dir);
    }

    var count = 0;
    for (final file in archive) {
      final name = file.name.replaceAll('\\', '/');
      if (name.startsWith('/') || name.split('/').contains('..')) continue;
      if (name.split('/').first == '.git') continue;

      final target = File(p.join(dir.path, name));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(file.content as List<int>, flush: true);
      count++;
    }
    return count;
  }

  /// Deletes every markdown file under notes/ and templates/, leaving
  /// directories, dotfiles and anything else untouched.
  static Future<void> _clearMarkdownFiles(Directory root) async {
    for (final sub in ['notes', 'templates']) {
      final dir = Directory(p.join(root.path, sub));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.md')) {
          await entity.delete();
        }
      }
    }
  }
}
