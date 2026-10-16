import 'dart:convert';

import 'package:yaml/yaml.dart';

/// Helpers for documents persisted as YAML frontmatter + markdown body.
///
/// Every note/template is a plain `.md` file so users can read and edit
/// their data outside the app:
///
/// ```
/// ---
/// title: "Toplantı"
/// createdAt: 1760000000000
/// tags:
///   - iş
/// ---
/// # Body starts here
/// ```
class MarkdownFrontmatter {
  static const String _delimiter = '---';

  /// Encodes [meta] plus [body] into a frontmatter document.
  ///
  /// Values must be `String`, `int`, `bool`, or `List`; `null` values and
  /// empty lists are omitted. Strings are emitted as JSON strings, which are
  /// valid YAML double-quoted scalars and survive colons/quotes in titles.
  static String encode(Map<String, Object?> meta, String body) {
    final buffer = StringBuffer('$_delimiter\n');
    for (final entry in meta.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is List) {
        if (value.isEmpty) continue;
        buffer.write('${entry.key}:\n');
        for (final item in value) {
          buffer.write('  - ${_scalar(item)}\n');
        }
      } else {
        buffer.write('${entry.key}: ${_scalar(value)}\n');
      }
    }
    buffer.write('$_delimiter\n$body');
    return buffer.toString();
  }

  static String _scalar(Object value) {
    if (value is String) return jsonEncode(value);
    return value.toString();
  }

  /// Decodes a document into its metadata map and markdown body.
  ///
  /// Documents without valid frontmatter return an empty map and the full
  /// text as body, so a hand-edited file never becomes unreadable.
  static (Map<String, Object?>, String) decode(String raw) {
    final lines = raw.split('\n');
    if (lines.isEmpty || lines.first.trim() != _delimiter) {
      return (<String, Object?>{}, raw);
    }

    final metaLines = <String>[];
    var bodyStart = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == _delimiter) {
        bodyStart = i + 1;
        break;
      }
      metaLines.add(lines[i]);
    }
    if (bodyStart == -1) {
      return (<String, Object?>{}, raw);
    }

    var meta = <String, Object?>{};
    try {
      final parsed = loadYaml(metaLines.join('\n'));
      if (parsed is YamlMap) {
        meta = parsed.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Malformed frontmatter: keep the body, ignore metadata.
    }

    final body = lines.sublist(bodyStart).join('\n').trimLeft();
    return (meta, body);
  }

  static int? getInt(Map<String, Object?> meta, String key) {
    final value = meta[key];
    return value is int ? value : null;
  }

  static String? getString(Map<String, Object?> meta, String key) {
    final value = meta[key];
    if (value == null) return null;
    return value.toString();
  }

  static bool getBool(Map<String, Object?> meta, String key, {bool defaultValue = false}) {
    final value = meta[key];
    return value is bool ? value : defaultValue;
  }

  static List<String> getStringList(Map<String, Object?> meta, String key) {
    final value = meta[key];
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }
}
