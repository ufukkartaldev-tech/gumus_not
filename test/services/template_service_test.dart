import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/models/note_model.dart';

void main() {
  group('Template Model Tests', () {
    test('Template has valid structure', () {
      final template = Template(
        id: 1,
        name: 'Test Template',
        content: 'Test Content',
        category: 'Test Category',
        description: 'Test Description',
        icon: 'test_icon',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      expect(template.id, 1);
      expect(template.name, 'Test Template');
      expect(template.content, 'Test Content');
      expect(template.category, 'Test Category');
      expect(template.description, 'Test Description');
      expect(template.icon, 'test_icon');
    });

    test('Template fromMap creates instance correctly', () {
      final map = {
        'id': 1,
        'name': 'Test Template',
        'content': 'Test Content',
        'category': 'Test Category',
        'description': 'Test Description',
        'icon': 'test_icon',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      final template = Template.fromMap(map);

      expect(template.id, 1);
      expect(template.name, 'Test Template');
      expect(template.content, 'Test Content');
      expect(template.category, 'Test Category');
      expect(template.description, 'Test Description');
      expect(template.icon, 'test_icon');
    });

    test('Template toMap creates correct map', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final template = Template(
        id: 1,
        name: 'Test Template',
        content: 'Test Content',
        category: 'Test Category',
        description: 'Test Description',
        icon: 'test_icon',
        createdAt: now,
      );

      final map = template.toMap();

      expect(map['id'], 1);
      expect(map['name'], 'Test Template');
      expect(map['content'], 'Test Content');
      expect(map['category'], 'Test Category');
      expect(map['description'], 'Test Description');
      expect(map['icon'], 'test_icon');
      expect(map['created_at'], now);
    });

    test('Template copyWith creates updated instance', () {
      final original = Template(
        id: 1,
        name: 'Original',
        content: 'Original Content',
        category: 'Original Category',
        description: 'Original Description',
        icon: 'original_icon',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final updated = original.copyWith(name: 'Updated');

      expect(updated.id, 1);
      expect(updated.name, 'Updated');
      expect(updated.content, 'Original Content');
      expect(updated.category, 'Original Category');
      expect(updated.description, 'Original Description');
      expect(updated.icon, 'original_icon');
    });
  });
}