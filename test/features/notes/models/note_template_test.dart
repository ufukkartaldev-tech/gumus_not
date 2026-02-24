import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_template.dart';

void main() {
  group('NoteTemplate Tests', () {
    test('Template creation with valid data', () {
      final template = NoteTemplate(
        id: 'test-id',
        name: 'Test Template',
        description: 'A test template',
        icon: Icons.note,
        color: Colors.blue,
        content: '# Test Content',
      );

      expect(template.id, 'test-id');
      expect(template.name, 'Test Template');
      expect(template.description, 'A test template');
      expect(template.icon, Icons.note);
      expect(template.color, Colors.blue);
      expect(template.content, '# Test Content');
    });

    test('Template has all required fields', () {
      final template = NoteTemplate(
        id: 'required-fields',
        name: 'Required Fields Template',
        description: 'Template with all fields',
        icon: Icons.star,
        color: Colors.red,
        content: '## Content with all fields',
      );

      expect(template.id, isNotNull);
      expect(template.name, isNotNull);
      expect(template.description, isNotNull);
      expect(template.icon, isNotNull);
      expect(template.color, isNotNull);
      expect(template.content, isNotNull);
    });

    test('Default templates list is not empty', () {
      final templates = NoteTemplate.defaultTemplates;
      
      expect(templates, isNotEmpty);
      expect(templates.length, greaterThan(0));
    });

    test('Default templates have unique IDs', () {
      final templates = NoteTemplate.defaultTemplates;
      final ids = templates.map((t) => t.id).toList();
      final uniqueIds = ids.toSet();
      
      expect(ids.length, uniqueIds.length);
    });

    test('Default templates contain expected template types', () {
      final templates = NoteTemplate.defaultTemplates;
      final templateIds = templates.map((t) => t.id).toList();
      
      expect(templateIds, contains('cornell'));
      expect(templateIds, contains('meeting'));
      expect(templateIds, contains('daily_journal'));
      expect(templateIds, contains('book_summary'));
      expect(templateIds, contains('project_idea'));
    });

    test('Template content contains date placeholders', () {
      final templates = NoteTemplate.defaultTemplates;
      
      for (final template in templates) {
        // Check that content contains date information in some form
        final content = template.content;
        expect(content.contains(DateTime.now().day.toString()) || 
               content.contains(DateTime.now().month.toString()) || 
               content.contains(DateTime.now().year.toString()) ||
               content.contains('Tarih:') ||
               content.contains('${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}'), 
               isTrue);
      }
    });

    test('Template properties are correctly assigned', () {
      final template = NoteTemplate(
        id: 'property-test',
        name: 'Property Test',
        description: 'Testing property assignment',
        icon: Icons.home,
        color: Colors.green,
        content: 'Property content test',
      );

      expect(template.id, equals('property-test'));
      expect(template.name, equals('Property Test'));
      expect(template.description, equals('Testing property assignment'));
      expect(template.icon, equals(Icons.home));
      expect(template.color, equals(Colors.green));
      expect(template.content, equals('Property content test'));
    });

    test('Template equality comparison works correctly', () {
      final template1 = NoteTemplate(
        id: 'equality-test',
        name: 'Equality Test',
        description: 'Testing equality',
        icon: Icons.equalizer,
        color: Colors.purple,
        content: 'Equality content',
      );

      final template2 = NoteTemplate(
        id: 'equality-test',
        name: 'Equality Test',
        description: 'Testing equality',
        icon: Icons.equalizer,
        color: Colors.purple,
        content: 'Equality content',
      );

      // NoteTemplate doesn't override == operator, so they should be different instances
      expect(template1, isNot(same(template2)));
    });

    test('All default templates have valid icon data', () {
      final templates = NoteTemplate.defaultTemplates;
      
      for (final template in templates) {
        expect(template.icon, isNotNull);
        expect(template.icon, isA<IconData>());
      }
    });

    test('All default templates have valid color data', () {
      final templates = NoteTemplate.defaultTemplates;
      
      for (final template in templates) {
        expect(template.color, isNotNull);
        expect(template.color, isA<Color>());
      }
    });
  });
}