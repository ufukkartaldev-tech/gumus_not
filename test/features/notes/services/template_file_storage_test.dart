import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/services/template_file_storage.dart';

void main() {
  group('TemplateFileStorage Serialization Tests', () {
    test('serialize and deserialize preserve all template attributes', () {
      final template = Template(
        id: 42,
        name: 'Haftalık Plan',
        content: '# Pazartesi\n- Görev 1\n- Görev 2',
        category: 'Planlama',
        description: 'Haftayı organize etmek için şablon',
        icon: '📅',
        createdAt: 1700000000000,
      );

      final serialized = TemplateFileStorage.serialize(template);
      expect(serialized, contains('Haftalık Plan'));
      expect(serialized, contains('Planlama'));
      expect(serialized, contains('📅'));
      expect(serialized, contains('# Pazartesi'));

      final deserialized = TemplateFileStorage.deserialize(42, serialized);
      expect(deserialized.id, equals(42));
      expect(deserialized.name, equals('Haftalık Plan'));
      expect(deserialized.category, equals('Planlama'));
      expect(deserialized.description, equals('Haftayı organize etmek için şablon'));
      expect(deserialized.icon, equals('📅'));
      expect(deserialized.content, equals('# Pazartesi\n- Görev 1\n- Görev 2'));
      expect(deserialized.createdAt, equals(1700000000000));
    });

    test('deserialize falls back gracefully when optional fields are missing', () {
      const rawMarkdown = '''---
name: "Yalın Not"
---
Sadece içerik.''';

      final template = TemplateFileStorage.deserialize(100, rawMarkdown);
      expect(template.id, equals(100));
      expect(template.name, equals('Yalın Not'));
      expect(template.category, equals('Genel'));
      expect(template.description, equals(''));
      expect(template.icon, isNull);
      expect(template.content, equals('Sadece içerik.'));
    });
  });
}
