import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:connected_notebook/core/storage/markdown_frontmatter.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

/// Persists [Template] objects as markdown files with YAML frontmatter under
/// `<documents>/GumusNot/templates`, one file per template (`<id>.md`).
class TemplateFileStorage {
  TemplateFileStorage._();

  static const String _seedMarkerName = '.seeded';

  static bool get _isAvailable => !kIsWeb;

  static Future<Directory> _gumusNotRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'GumusNot'));
  }

  static Future<Directory> templatesDir() async {
    final dir = Directory(p.join((await _gumusNotRoot()).path, 'templates'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static String serialize(Template template) {
    return MarkdownFrontmatter.encode({
      'name': template.name,
      'category': template.category,
      'description': template.description,
      'icon': template.icon,
      'createdAt': template.createdAt,
    }, template.content);
  }

  static Template deserialize(int id, String raw) {
    final (meta, body) = MarkdownFrontmatter.decode(raw);
    return Template(
      id: id,
      name: MarkdownFrontmatter.getString(meta, 'name') ?? 'Unnamed',
      content: body,
      category: MarkdownFrontmatter.getString(meta, 'category') ?? 'Genel',
      description: MarkdownFrontmatter.getString(meta, 'description') ?? '',
      icon: MarkdownFrontmatter.getString(meta, 'icon'),
      createdAt: MarkdownFrontmatter.getInt(meta, 'createdAt') ?? 0,
    );
  }

  static Future<List<Template>> readAll() async {
    if (!_isAvailable) return [];
    final dir = await templatesDir();
    final templates = <Template>[];
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (!fileName.endsWith('.md') || fileName.startsWith('.')) continue;
      final id = int.tryParse(
            fileName.substring(0, fileName.length - 3),
          ) ??
          fileName.hashCode.abs();
      templates.add(deserialize(id, entity.readAsStringSync()));
    }
    return templates;
  }

  static Future<Template?> readById(int id) async {
    if (!_isAvailable) return null;
    final dir = await templatesDir();
    final file = File(p.join(dir.path, '$id.md'));
    if (!file.existsSync()) return null;
    return deserialize(id, file.readAsStringSync());
  }

  /// Writes [template], assigning a fresh id when it has none.
  /// Returns the id the template was stored under.
  static Future<int> write(Template template) async {
    if (!_isAvailable) {
      throw UnsupportedError(
        'Templates are stored as markdown files, which requires a platform '
        'filesystem; this operation is not supported on the web.',
      );
    }
    final dir = await templatesDir();

    var id = template.id ?? DateTime.now().millisecondsSinceEpoch;
    if (template.id == null) {
      var file = File(p.join(dir.path, '$id.md'));
      while (file.existsSync()) {
        id++;
        file = File(p.join(dir.path, '$id.md'));
      }
    }

    await File(p.join(dir.path, '$id.md'))
        .writeAsString(serialize(template.copyWith(id: id)));
    return id;
  }

  static Future<void> delete(int id) async {
    if (!_isAvailable) return;
    final dir = await templatesDir();
    final file = File(p.join(dir.path, '$id.md'));
    if (file.existsSync()) await file.delete();
  }

  /// Seeds [defaults] (name/category/description/icon/content maps) the first
  /// time the templates directory is used. A marker file ensures defaults are
  /// only written once, so user-deleted templates stay deleted.
  static Future<void> seedDefaultsIfNeeded(List<Map<String, dynamic>> defaults) async {
    if (!_isAvailable) return;
    final dir = await templatesDir();
    final marker = File(p.join(dir.path, _seedMarkerName));
    if (marker.existsSync()) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < defaults.length; i++) {
      final def = defaults[i];
      final template = Template(
        id: now + i,
        name: def['name'] ?? 'Şablon',
        content: def['content'] ?? '',
        category: def['category'] ?? 'Genel',
        description: def['description'] ?? '',
        icon: def['icon'],
        createdAt: now,
      );
      final file = File(p.join(dir.path, '${template.id}.md'));
      await file.writeAsString(serialize(template));
    }
    await marker.writeAsString('seeded at ${DateTime.now().toIso8601String()}');
  }
}
