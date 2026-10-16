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
  /// does not exist yet.
  static Future<List<int>?> zipWorkspace() async {
    final root = await _root();
    if (!root.existsSync()) return null;

    final archive = Archive();
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative =
          p.relative(entity.path, from: root.path).replaceAll('\\', '/');
      if (relative.startsWith('.git')) continue;
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }

    return ZipEncoder().encode(archive);
  }

  /// Extracts a workspace zip back into `<documents>/GumusNot`.
  /// Returns the number of restored files.
  static Future<int> extractWorkspace(Archive archive) async {
    final root = await _root();
    if (!root.existsSync()) root.createSync(recursive: true);

    var count = 0;
    for (final file in archive) {
      final name = file.name.replaceAll('\\', '/');
      if (name.startsWith('/') || name.split('/').contains('..')) continue;
      if (name.split('/').first == '.git') continue;

      final target = File(p.join(root.path, name));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(file.content as List<int>, flush: true);
      count++;
    }
    return count;
  }
}
