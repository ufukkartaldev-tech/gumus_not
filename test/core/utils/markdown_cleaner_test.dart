import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/utils/markdown_cleaner.dart';

void main() {
  group('MarkdownCleaner Tests', () {
    test('cleans headings and preserves title text', () {
      expect(MarkdownCleaner.clean('# Heading 1'), 'Heading 1');
      expect(MarkdownCleaner.clean('## Subheading 2'), 'Subheading 2');
      expect(MarkdownCleaner.clean('### Sub-subheading 3'), 'Sub-subheading 3');
    });

    test('cleans bold, italic and strikethrough markers', () {
      expect(MarkdownCleaner.clean('**Bold text**'), 'Bold text');
      expect(MarkdownCleaner.clean('*Italic text*'), 'Italic text');
      expect(MarkdownCleaner.clean('***Bold and italic***'), 'Bold and italic');
      expect(MarkdownCleaner.clean('~~Strikethrough~~'), 'Strikethrough');
    });

    test('cleans links and wikilinks while keeping label', () {
      expect(MarkdownCleaner.clean('[Google](https://google.com)'), 'Google');
      expect(MarkdownCleaner.clean('[[TargetPage]]'), 'TargetPage');
      expect(MarkdownCleaner.clean('[[TargetPage|Custom Label]]'), 'Custom Label');
    });

    test('cleans code blocks and inline code', () {
      expect(MarkdownCleaner.clean('Here is `code` inline'), 'Here is code inline');
      expect(
        MarkdownCleaner.clean('```dart\nvoid main() {\n  print("hello");\n}\n```'),
        'void main() { print("hello"); }',
      );
    });

    test('cleans lists and task checkboxes', () {
      expect(MarkdownCleaner.clean('- [ ] Task to do'), 'Task to do');
      expect(MarkdownCleaner.clean('- [x] Completed task'), 'Completed task');
      expect(MarkdownCleaner.clean('* Bullet point'), 'Bullet point');
      expect(MarkdownCleaner.clean('1. Numbered item'), 'Numbered item');
    });

    test('extracts hashtags ignoring markdown headings', () {
      const content = '''
# Heading with no tag
Here is #flutter and #productivity notes.
## Another #heading
Check #mobile development.
''';
      final tags = MarkdownCleaner.extractHashtags(content);
      expect(tags, contains('flutter'));
      expect(tags, contains('productivity'));
      expect(tags, contains('mobile'));
      expect(tags, isNot(contains('heading')));
    });
  });
}
